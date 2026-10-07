-- Run from -c so the main event loop performs actual terminal-mode changes.
local root, fixture = vim.env.NVIM_TEST_ROOT, vim.env.NVIM_TEST_FIXTURE
vim.opt.rtp:prepend(root)
dofile(root .. "/lua/config/keymaps.lua")
local logfile = vim.fn.tempname()
vim.fn.writefile({}, logfile)
vim.fn.termopen({ fixture .. "/codex", logfile })
local checks, expected = 0, ""
local function check(value, message)
  assert(value, message)
  checks = checks + 1
end
local function received() return table.concat(vim.fn.readfile(logfile)) end
local function hex(bytes)
  return (bytes:gsub(".", function(c) return ("%02x"):format(c:byte()) end))
end
local function input(keys, bytes)
  vim.api.nvim_input(keys)
  expected = expected .. hex(bytes or "")
end
local function mode(wanted)
  local actual = vim.api.nvim_get_mode().mode
  check(wanted == "n" and actual:sub(1, 1) == "n" or actual == wanted, "mode " .. wanted .. ", actual " .. actual)
end
local function bytes() check(received() == expected, "PTY bytes expected=" .. expected .. " actual=" .. received()) end
local steps = {
  function()
    check(table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false)):find("READY", 1, true), "PTY ready")
    vim.cmd("stopinsert")
  end,
  function() mode("n"); input(".", "\x1bOR") end,
  function() mode("t"); input("nNqQUERY", "nNqQUERY") end,
  function() mode("t"); bytes(); input("<CR>") end,
  function() mode("n"); bytes(); input("n", "\r") end,
  function() mode("n"); bytes(); input("N", "\x10") end,
  function() mode("n"); bytes(); input("i") end,
  function() mode("t"); input("nN", "nN") end,
  function()
    mode("t"); bytes()
    -- Pasted newlines are text, rather than the search-accept Enter mapping.
    vim.api.nvim_paste("PASTE\nnN", true, -1)
    expected = expected .. hex("PASTE\nnN")
  end,
  function() mode("t"); bytes(); check(vim.b.codex_search_phase == "query", "paste does not accept query"); input("<Esc>", "\x1b") end,
  function() mode("n"); bytes(); check(vim.b.codex_search_pid == nil, "Esc clears search"); input("/", "\x1bOR") end,
  function() mode("t"); input("next", "next"); input("<CR>") end,
  function() mode("n"); bytes(); input("q", "\x1b") end,
  function() mode("n"); bytes(); check(vim.b.codex_search_pid == nil, "q clears search"); input("a") end,
  function() mode("t"); input("nN<CR>", "nN\r") end,
  function() mode("t"); bytes(); check(vim.b.codex_search_pid == nil, "composer Enter preserves mode"); input("<C-n>") end,
  function() mode("n"); input("/", "\x1bOR") end,
  function() mode("t"); input("manual", "manual"); input("<C-n>") end,
  function() mode("n"); input("nN", "\r\x10") end,
  function() mode("n"); bytes(); input("i") end,
  function()
    mode("t")
    -- nvim_input(C-c) has API interrupt semantics; feed typed keys instead.
    vim.api.nvim_feedkeys("\x03", "t", false)
    expected = expected .. "03"
  end,
  function()
    mode("n"); bytes(); check(vim.b.codex_search_pid == nil, "CtrlC clears search")
    -- Native/manual F3 never establishes adapter state; n/N use Vim defaults.
    local original = vim.api.nvim_feedkeys
    local fallbacks = {}
    vim.api.nvim_feedkeys = function(keys) fallbacks[#fallbacks + 1] = keys end
    for _, lhs in ipairs({ "n", "N" }) do vim.fn.maparg(lhs, "n", false, true).callback() end
    vim.api.nvim_feedkeys = original
    check(#fallbacks == 2, "composer normal n/N preserve defaults")
    -- A replaced child PID must invalidate state even if the shell job survives.
    vim.b.codex_search_pid = -123
    vim.fn.maparg("n", "n", false, true).callback()
    check(vim.b.codex_search_pid == nil, "stale process identity cleared")
  end,
}
local index = 0
local function next_step()
  index = index + 1
  if index > #steps then
    print(("PASS: %d checks (real search mode, next/previous, close and composer regression)"):format(checks))
    vim.cmd("qa!")
    return
  end
  vim.defer_fn(function()
    local ok, err = pcall(steps[index])
    if not ok then io.stderr:write("step " .. index .. ": " .. tostring(err) .. "\n"); vim.cmd("cquit") else next_step() end
  end, 100)
end
next_step()
vim.defer_fn(function() io.stderr:write("terminal mode test timed out\n"); vim.cmd("cquit") end, 8000)
