local M = {}

function M.move(key, direction)
  local target = vim.fn.winnr(key)
  if target ~= vim.fn.winnr() then
    if vim.fn.mode():sub(1, 1) == "t" then
      vim.cmd.stopinsert()
    end
    vim.api.nvim_set_current_win(vim.fn.win_getid(target))
  else
    vim.system({ "/opt/homebrew/bin/yabai", "-m", "window", "--focus", direction }, { detach = true })
  end
end

return M
