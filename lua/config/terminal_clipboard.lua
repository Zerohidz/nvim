local M = {}

function M.paste()
  local text = vim.fn.getreg("+")
  local chan = vim.b.terminal_job_id
  if text == "" and vim.bo.buftype == "terminal" and chan and require("config.terminal_agent").is_codex_running() then
    -- Codex reads image data from the system clipboard when it receives Ctrl+V.
    vim.api.nvim_chan_send(chan, "\022")
    return
  end
  vim.api.nvim_paste(text, true, -1)
end

return M
