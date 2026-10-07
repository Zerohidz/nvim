local root = assert(vim.env.NVIM_TEST_ROOT)
local fixture = assert(vim.env.NVIM_TEST_FIXTURE)
vim.opt.rtp:prepend(root)
local agent = require("config.terminal_agent")
local checks = 0
local function check(value, label)
  assert(value, label)
  checks = checks + 1
end
local function hex(bytes)
  return (bytes:gsub(".", function(c) return ("%02x"):format(c:byte()) end))
end
for _, command in ipairs({
  "/opt/homebrew/bin/codex", "codex --model gpt-5.4", "codex resume", "codex fork",
  "node /usr/lib/node_modules/@openai/codex/bin/codex.js --no-alt-screen",
  "codex --config key=exec --model review",
}) do
  check(agent.is_codex_command(command), "interactive: " .. command)
end
for _, command in ipairs({
  "echo codex", "rg codex", "sh -c codex", "python codex.py", "codex-other", "codex exec hello",
  "codex -m gpt-5.4 review", "codex e hello", "codex app-server", "codex mcp-server",
  "codex doctor", "codex update", "codex agents", "codex app", "codex help", "codex archive",
  "codex delete", "codex queue", "codex exec-server", "codex plugin", "codex remote-control",
  "node unrelated.js codex", "node server.js --codex", "codex --help", "codex completion",
}) do
  check(not agent.is_codex_command(command), "noninteractive: " .. command)
end
local snapshot = agent.parse_processes([[
10 1 10 pts/1 Ss+ bash
11 10 11 pts/1 S node /usr/bin/wrapper.js
12 11 12 pts/1 S+ /usr/local/bin/codex
13 10 13 pts/1 S /usr/local/bin/codex
14 1 14 pts/2 S+ /usr/local/bin/codex
]])
check(agent.detect(10, snapshot), "recursive wrapper")
snapshot[12].tty = "pts/other"
check(not agent.detect(10, snapshot), "Codex in a different PTY ignored")
snapshot[12].tty = "pts/1"
snapshot[11].command = "nvim"
check(not agent.detect(10, snapshot), "inner editor owns its terminal subtree")
snapshot[11].command = "node /usr/bin/wrapper.js"
snapshot[12].stat = "T+"
check(not agent.detect(10, snapshot), "suspended Codex ignored")
snapshot[12] = nil
check(not agent.detect(10, snapshot), "background/unrelated Codex ignored")
local tmux_snapshot = agent.parse_processes([[
20 1 20 pts/3 Ss bash
21 20 21 pts/3 S+ tmux -L private attach
30 1 30 pts/4 Ss bash
31 30 31 pts/4 S+ codex
40 1 40 pts/5 Ss bash
41 40 41 pts/5 S+ codex
]])
local queries = {}
check(agent.detect(20, tmux_snapshot, function(command)
  queries[#queries + 1] = command
  if command[4] == "list-clients" then
    return "99\t/dev/pts/other\n21\t/dev/pts/3\n"
  end
  check(command[6] == "/dev/pts/3", "query exact matching client")
  return "30\n"
end), "tmux active pane")
check(queries[1][2] == "-L" and queries[1][3] == "private", "tmux custom socket")
check(not agent.detect(20, tmux_snapshot, function() return "99\t/dev/pts/other\n" end), "never borrow another client")

-- Load the actual config with plugins disabled; the real TermOpen callback
-- installs buffer mappings, and the byte sink observes actual job input.
dofile(root .. "/lua/config/keymaps.lua")
local function open_sink(name, command)
  vim.cmd("enew")
  local logfile = vim.fn.tempname()
  vim.fn.writefile({}, logfile)
  local executable = fixture .. "/" .. name
  local sink_command = { executable, logfile }
  if name == "claude" then
    -- Existing Claude detection intentionally checks the terminal shell child.
    sink_command = { "/bin/sh", "-c", '"$1" "$2"; :', "sink", executable, logfile }
  end
  local job = vim.fn.termopen(command or sink_command)
  check(vim.wait(1000, function()
    return table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false)):find("READY", 1, true) ~= nil
  end), "PTY ready: " .. name)
  vim.cmd("stopinsert")
  return job, logfile
end
local function mapping(lhs)
  local map = vim.fn.maparg(lhs, "n", false, true)
  check(type(map.callback) == "function" and map.buffer == 1, "buffer mapping " .. lhs)
  return map.callback
end
local function read(log)
  return table.concat(vim.fn.readfile(log))
end
local job, log = open_sink("codex")
check(agent.is_codex_running(), "actual foreground Codex PTY detection")
local bytes = ""
for _, pair in ipairs({ { "<C-u>", "\x1b[5~" }, { "<C-d>", "\x1b[6~" }, { "gg", "\x1b[1;5H" }, { "G", "\x1b[1;5F" } }) do
  local old_cursor = vim.api.nvim_win_get_cursor(0)
  mapping(pair[1])()
  bytes = bytes .. pair[2]
  check(vim.wait(1000, function() return read(log) == hex(bytes) end), "native bytes " .. pair[1])
  check(vim.deep_equal(old_cursor, vim.api.nvim_win_get_cursor(0)), "no scrollback fallback " .. pair[1])
end
local original_cmd = vim.cmd
local startinsert_count = 0
-- Headless mode does not perform mode transitions inside synchronous Lua;
-- intercept only startinsert and assert the actual request while sending bytes.
vim.cmd = setmetatable({}, { __call = function(_, command)
  if command == "startinsert" then startinsert_count = startinsert_count + 1 else original_cmd(command) end
end })
for _, lhs in ipairs({ ".", "/" }) do
  mapping(lhs)()
  bytes = bytes .. "\x1bOR"
  check(vim.wait(1000, function() return read(log) == hex(bytes) end), "F3 search " .. lhs)
end
mapping("i")()
mapping("a")()
check(startinsert_count == 4, "search and i/a request terminal input mode")
check(read(log) == hex(bytes), "Codex i/a never emit Claude cursor-edit bytes")
vim.cmd = original_cmd
vim.fn.jobstop(job)

job, log = open_sink("claude")
mapping("<C-u>")()
check(vim.wait(1000, function() return read(log) == hex("\x1b[5~") end), "Claude PageUp preserved")
mapping("G")()
check(vim.wait(1000, function() return read(log) == hex("\x1b[5~\x1b[1;5F\x06") end), "Claude bottom redraw preserved")
mapping("/")()
check(vim.wait(1000, function() return read(log) == hex("\x1b[5~\x1b[1;5F\x06\x0f/") end), "Claude transcript search preserved")
vim.fn.jobstop(job)

job, log = open_sink("shell")
check(not agent.is_codex_running(), "plain shell not Codex")
local original_feed = vim.api.nvim_feedkeys
local fallbacks = {}
vim.api.nvim_feedkeys = function(keys) fallbacks[#fallbacks + 1] = keys end
for _, lhs in ipairs({ "<C-u>", "<C-d>", "gg", "G", ".", "/" }) do mapping(lhs)() end
vim.api.nvim_feedkeys = original_feed
check(#fallbacks == 6 and read(log) == "", "plain shell uses Neovim defaults only")
vim.fn.jobstop(job)
-- Neovim terminal -> tmux client -> active pane: the server is outside the
-- terminal job's process tree, so this validates actual client/pane lookup.
if vim.fn.executable("tmux") == 1 then
  local socket = "nvim-nav-test-" .. vim.fn.getpid()
  local pane_log = vim.fn.tempname()
  vim.fn.writefile({}, pane_log)
  local tmux = { "tmux", "-L", socket, "-f", "/dev/null" }
  local function tmux_run(extra)
    local result = vim.fn.system(vim.list_extend(vim.deepcopy(tmux), extra))
    assert(vim.v.shell_error == 0, result)
    return result
  end
  local pane_command = vim.fn.shellescape(fixture .. "/codex") .. " " .. vim.fn.shellescape(pane_log)
  tmux_run({ "new-session", "-d", "-s", "nav-test", pane_command })
  local ok, err = pcall(function()
    local tmux_job = open_sink("shell", vim.list_extend(vim.deepcopy(tmux), { "attach-session", "-t", "nav-test" }))
    check(agent.is_codex_running(), "actual nested tmux Codex detection")
    mapping("<C-u>")()
    check(vim.wait(1000, function() return read(pane_log) == hex("\x1b[5~") end), "native bytes through tmux")
    -- Switch the attached client's active window to a plain sink while Codex
    -- stays alive in its other window; detection must follow the active pane.
    local shell_log = vim.fn.tempname()
    tmux_run({ "new-window", "-t", "nav-test", vim.fn.shellescape(fixture .. "/shell") .. " " .. vim.fn.shellescape(shell_log) })
    check(vim.wait(1000, function() return not agent.is_codex_running() end), "inactive Codex pane ignored")
    vim.fn.jobstop(tmux_job)
  end)
  tmux_run({ "kill-server" })
  assert(ok, err)
end
print(("PASS: %d checks (process fixtures + live PTY mappings)"):format(checks))
vim.cmd("qa!")
