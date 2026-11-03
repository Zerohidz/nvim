local M = {}

-- Kitty's editor marker lets its conditional Ctrl+N mapping pass through.
-- Detect the builtin TUI by its documented client name; GUI and headless
-- instances must not write terminal escape sequences to stdout.
local function send_marker(active)
  if vim.g.neovide then
    return
  end

  local has_tui = false
  for _, ui in ipairs(vim.api.nvim_list_uis()) do
    local client = vim.api.nvim_get_chan_info(ui.chan).client
    if client and client.name == "nvim-tui" then
      has_tui = true
      break
    end
  end
  if not has_tui then
    return
  end

  local marker = "\027]1337;SetUserVar=in_editor" .. (active and "=MQ==" or "") .. "\007"
  if vim.api.nvim_ui_send then
    vim.api.nvim_ui_send(marker)
  else
    io.stdout:write(marker)
    io.stdout:flush()
  end
end

function M.setup()
  local group = vim.api.nvim_create_augroup("KittyEditorKeys", { clear = true })
  vim.api.nvim_create_autocmd({ "VimEnter", "VimResume", "UIEnter" }, {
    group = group,
    callback = function()
      send_marker(true)
    end,
  })
  vim.api.nvim_create_autocmd({ "VimLeavePre", "VimSuspend" }, {
    group = group,
    callback = function()
      send_marker(false)
    end,
  })
end

return M
