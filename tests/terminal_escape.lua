-- Full config, real ToggleTerm shell, real mapped input and event-loop mode transitions.
-- nvim --headless -c "lua dofile(vim.fn.stdpath('config') .. '/tests/terminal_escape.lua')"
local checks, index = 0, 0
local function check(ok, label)
  assert(ok, label)
  checks = checks + 1
end
local function normal()
  check(vim.api.nvim_get_mode().mode:sub(1, 1) == 'n', 'terminal normal mode: '..vim.api.nvim_get_mode().mode..' cmd='..vim.fn.getcmdline())
end
local function input(keys) vim.api.nvim_input(keys) end
local steps = {
  function()
    -- Establish plugin/keymap load before creating terminal buffers.
    vim.api.nvim_exec_autocmds('User', { pattern = 'VeryLazy' })
    if vim.env.NVIM_ESCAPE_BASELINE then dofile(vim.env.NVIM_ESCAPE_BASELINE) end
    vim.cmd('2ToggleTerm')
    vim.api.nvim_chan_send(vim.b.terminal_job_id, "echo ESC_SEARCH_MARKER ESC_SEARCH_MARKER\n")
  end,
  function()
    check(vim.bo.buftype == 'terminal', 'real ToggleTerm buffer')
    check(table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), '\n'):find('ESC_SEARCH_MARKER', 1, true), 'echo output ready')
    vim.cmd('startinsert')
  end,
  function()
    check(vim.api.nvim_get_mode().mode == 't', 'terminal input mode')
    input('<C-n>')
  end,
  function() normal(); input('/') end,
  function() input('ESC_SEARCH_MARKER<CR>') end,
  function()
    normal()
    check(vim.v.hlsearch == 1, 'search highlights active before Escape')
    input('<Esc>')
  end,
  function()
    normal()
    check(vim.v.hlsearch == 0, 'Escape clears terminal search highlights')
    check(vim.fn.getreg('/') == '\\VESC_SEARCH_MARKER', 'Escape preserves search pattern')
    check(vim.o.hlsearch, 'Escape preserves hlsearch option')
    input('n')
  end,
  function()
    normal()
    check(vim.v.hlsearch == 1, 'next match restores highlighting')
    input('<Esc>')
  end,
  function()
    normal()
    check(vim.v.hlsearch == 0, 'repeated search clears with Escape')
    -- A newly created second buffer must get the same behavior.
    vim.cmd('3ToggleTerm')
    vim.api.nvim_chan_send(vim.b.terminal_job_id, "echo ESC_SEARCH_MARKER\n")
  end,
  function() vim.cmd('stopinsert') end,
  function() normal(); input('/') end,
  function() input('ESC_SEARCH_MARKER<CR>') end,
  function() check(vim.v.hlsearch == 1, 'second terminal highlight active'); input('<Esc>') end,
  function() normal(); check(vim.v.hlsearch == 0, 'second terminal Escape clears highlights') end,
}
local function next_step()
  index = index + 1
  if index > #steps then
    io.stderr:write(('PASS: %d checks (real ToggleTerm echo, Ctrl+n, search, Esc, n, second terminal)\n'):format(checks))
    vim.cmd('qa!')
    return
  end
  vim.defer_fn(function()
    local ok, err = pcall(steps[index])
    if not ok then io.stderr:write('step '..index..': '..tostring(err)..'\n'); vim.cmd('cquit 1') else next_step() end
  end, 180)
end
next_step()
vim.defer_fn(function() io.stderr:write('terminal Escape test timed out\n'); vim.cmd('cquit 1') end, 12000)
