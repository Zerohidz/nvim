local M = {}

function M.open()
  -- Keep :edit #'s alternate-file and unsaved-change behavior.
  vim.cmd("edit #")
  local buf = vim.api.nvim_get_current_buf()
  if vim.bo[buf].buftype ~= "" or vim.bo[buf].filetype ~= "" or vim.fn.filereadable(vim.api.nvim_buf_get_name(buf)) ~= 1 then
    return
  end
  -- Reopened buffers can have lost their filetype. FileType already owns syntax,
  -- Treesitter options and bigfile handling; let the existing handlers recover it.
  vim.cmd("filetype detect")
end

function M.setup()
  vim.keymap.set("n", "<leader>bb", M.open, { desc = "Switch to Other Buffer", silent = true })
end

return M
