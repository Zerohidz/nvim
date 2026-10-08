-- Native Codex/opencode fullscreen navigation. Detection is dynamic: a terminal
-- may switch between its shell, a wrapper and a tmux client without reopening it.
local M = {}
local function basename(path)
  return (path or ""):match("([^/]+)$") or ""
end
local function argv(command)
  local result = {}
  for word in command:gmatch("%S+") do
    result[#result + 1] = word
  end
  return result
end

local noninteractive = {
  exec = true, e = true, review = true,
  ["app-server"] = true, mcp = true, ["mcp-server"] = true,
  login = true, logout = true, completion = true, debug = true,
  sandbox = true, apply = true, a = true, cloud = true, features = true,
  agents = true, plugin = true, app = true, update = true, doctor = true,
  queue = true, archive = true, delete = true, unarchive = true, help = true,
  ["migrate-rollouts"] = true, ["remote-control"] = true,
  ["exec-server"] = true, ["app-server-bridge"] = true,
}
local value_options = {
  ["-c"] = true, ["--config"] = true, ["-m"] = true, ["--model"] = true,
  ["-p"] = true, ["--profile"] = true, ["-C"] = true, ["--cd"] = true,
  ["-s"] = true, ["--sandbox"] = true, ["-a"] = true, ["--ask-for-approval"] = true,
  ["-i"] = true, ["--image"] = true, ["--add-dir"] = true,
  ["--enable"] = true, ["--disable"] = true, ["--local-provider"] = true,
  ["--remote"] = true, ["--remote-auth-token-env"] = true,
}
function M.is_codex_command(command)
  local words = argv(command)
  local first = basename(words[1])
  local start = 2
  if first == "node" or first == "nodejs" then
    local script = basename(words[2])
    if script ~= "codex" and script ~= "codex.js" then
      return false
    end
    start = 3
  elseif first ~= "codex" then
    return false
  end
  local i = start
  while i <= #words do
    local word = words[i]
    if word == "--" then
      return true
    elseif word == "--help" or word == "-h" or word == "--version" or word == "-V" then
      return false
    elseif value_options[word] then
      i = i + 2
    elseif word:sub(1, 1) == "-" then
      i = i + 1
    else
      return not noninteractive[word]
    end
  end
  return true
end

-- opencode: no subcommand (optional directory positional) starts the fullscreen
-- TUI. `mini` is an inline interface with different keys, so it is excluded.
local opencode_noninteractive = {
  upgrade = true, update = true, uninstall = true, acp = true, api = true,
  debug = true, auth = true, mcp = true, plugin = true, models = true,
  stats = true, mini = true, run = true, session = true, service = true,
  reload = true, pair = true, serve = true, web = true, export = true,
  import = true, github = true, agent = true,
}
local opencode_value_options = {
  ["--server"] = true, ["--session"] = true, ["-s"] = true, ["--prompt"] = true,
  ["--log-level"] = true,
}
function M.is_opencode_command(command)
  local words = argv(command)
  local first = basename(words[1])
  local start = 2
  if first == "node" or first == "nodejs" or first == "bun" then
    local script = basename(words[2])
    if script ~= "opencode" and script ~= "opencode.js" then
      return false
    end
    start = 3
  elseif first ~= "opencode" then
    return false
  end
  local i = start
  while i <= #words do
    local word = words[i]
    if word == "--" then
      return true
    elseif word == "--help" or word == "-h" or word == "--version" or word == "-v"
      or word == "--completions" or word == "--wizard" then
      return false
    elseif opencode_value_options[word] then
      i = i + 2
    elseif word:sub(1, 1) == "-" then
      i = i + 1
    else
      return not opencode_noninteractive[word]
    end
  end
  return true
end

-- "codex", "opencode" or nil for one ps args line.
function M.agent_kind(command)
  if M.is_codex_command(command) then
    return "codex"
  elseif M.is_opencode_command(command) then
    return "opencode"
  end
end

function M.parse_processes(output)
  local processes = {}
  for line in output:gmatch("[^\n]+") do
    local pid, ppid, pgid, tty, stat, command = line:match("^%s*(%d+)%s+(%d+)%s+(%d+)%s+(%S+)%s+(%S+)%s+(.*)$")
    if pid then
      processes[tonumber(pid)] = {
        pid = tonumber(pid), ppid = tonumber(ppid), pgid = tonumber(pgid),
        tty = tty, stat = stat, command = command,
      }
    end
  end
  return processes
end
local function system(command)
  local ok, output = pcall(vim.fn.system, command)
  if ok and vim.v.shell_error == 0 then
    return output
  end
end
local function tmux_pane(process, run)
  local words = argv(process.command)
  if basename(words[1]) ~= "tmux" then
    return nil
  end
  local command = { "tmux" }
  -- A terminal can attach to a non-default server. Keep its socket explicit.
  for i = 2, #words do
    if words[i] == "-L" or words[i] == "-S" then
      command[#command + 1] = words[i]
      command[#command + 1] = words[i + 1]
    end
  end
  local clients_cmd = vim.list_extend(vim.deepcopy(command), { "list-clients", "-F", "#{client_pid}\t#{client_tty}" })
  local clients = run(clients_cmd)
  if not clients then
    return nil
  end
  for line in clients:gmatch("[^\n]+") do
    local pid, tty = line:match("^(%d+)\t(.+)$")
    if tonumber(pid) == process.pid then
      local pane = run(vim.list_extend(command, { "display-message", "-c", tty, "-p", "#{pane_pid}" }))
      return pane and tonumber(pane:match("^%s*(%d+)%s*$"))
    end
  end
end

function M.detect(root_pid, processes, run, match)
  run = run or system
  match = match or M.is_codex_command
  local seen = {}
  local function visit(pid, terminal_tty)
    if seen[pid] then
      return false
    end
    seen[pid] = true
    local process = processes[pid]
    if not process or (terminal_tty and process.tty ~= terminal_tty) then
      return false
    end
    terminal_tty = terminal_tty or process.tty
    -- An inner editor owns its terminal keystrokes; never route outer-editor
    -- navigation through it into one of its own terminal jobs.
    if process then
      local executable = basename(argv(process.command)[1])
      if executable == "nvim" or executable == "vim" or executable == "neovide" then
        return false
      end
    end
    -- '+' is the portable BSD/Linux ps foreground process group marker.
    if process and process.stat:find("+", 1, true) and not process.stat:find("[TXZ]") then
      if match(process.command) then
        return pid
      end
      local pane_pid = tmux_pane(process, run)
      local found = pane_pid and visit(pane_pid)
      if found then
        return found
      end
    end
    for child_pid, child in pairs(processes) do
      local found = child.ppid == pid and visit(child_pid, terminal_tty)
      if found then
        return found
      end
    end
    return false
  end
  return visit(root_pid)
end
-- One ps snapshot per key press: returns kind ("codex"/"opencode") and pid of
-- the foreground agent in the current terminal buffer, or nil.
function M.agent()
  local chan = vim.b.terminal_job_id
  if not chan then
    return nil
  end
  local ok, pid = pcall(vim.fn.jobpid, chan)
  if not ok or not pid or pid <= 0 then
    return nil
  end
  local output = system({ "ps", "-Aww", "-o", "pid=,ppid=,pgid=,tty=,stat=,args=" })
  if not output then
    return nil
  end
  local processes = M.parse_processes(output)
  local found = M.detect(pid, processes, nil, function(command)
    return M.agent_kind(command) ~= nil
  end)
  if found then
    return M.agent_kind(processes[found].command), found
  end
end
function M.codex_pid()
  local kind, pid = M.agent()
  return kind == "codex" and pid or nil
end
function M.is_codex_running()
  return not not M.codex_pid()
end
function M.is_opencode_running()
  return M.agent() == "opencode"
end
return M
