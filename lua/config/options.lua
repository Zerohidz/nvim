require("config.remote_clipboard").setup()
-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here
vim.opt.relativenumber = false

-- LazyVim default: SSH dışında clipboard="unnamedplus", yani her x/y/d
-- sistem panosuna gider. remote_clipboard.lua artık gerçek bir + register
-- provider taktığı için bu görünür hale geldi (x visual modda cut gibi
-- davranıyordu). Local register'ları pano'dan ayır; pano için explicit
-- "+y / "+x veya <leader>yf, <leader>yp gibi mapler kullan.
vim.opt.clipboard = ""

-- Türkçe klavye textobject fix: ı→i'den sonra İ/Ğ için yeterli süre
-- Default 300ms, 500ms ile tuş arası 500ms'e kadar olan gecikmeler çalışır
vim.opt.timeoutlen = 3000

if vim.g.neovide then
  vim.env.TERM_PROGRAM = "ghostty"
  -- Sistem fontunu omarchy'den oku, hardcode etme (omarchy font set → restart yeter)
  local font = vim.fn.systemlist("omarchy-font-current")[1]
  if vim.v.shell_error ~= 0 or not font or font == "" then
    font = "CaskaydiaMono Nerd Font Mono"
  end
  vim.o.guifont = font .. ":h10"
  vim.g.neovide_scale_factor = 1.0
  vim.g.neovide_opacity = 0.9
  vim.g.neovide_padding_top = 30
  vim.g.neovide_padding_bottom = 30
  vim.g.neovide_padding_left = 30
  vim.g.neovide_padding_right = 30
  vim.g.neovide_scroll_animation_far_lines = 0

  -- Neovide GUI'de host terminal yok, Neovim default ANSI palette kullanıyor.
  -- Ghostty/omarchy temasındaki paletle eşitle (ghostty.conf'tan birebir).
  vim.g.terminal_color_0 = "#3c3836"
  vim.g.terminal_color_1 = "#ea6962"
  vim.g.terminal_color_2 = "#a9b665"
  vim.g.terminal_color_3 = "#d8a657"
  vim.g.terminal_color_4 = "#7daea3"
  vim.g.terminal_color_5 = "#d3869b"
  vim.g.terminal_color_6 = "#89b482"
  vim.g.terminal_color_7 = "#d4be98"
  vim.g.terminal_color_8 = "#3c3836"
  vim.g.terminal_color_9 = "#ea6962"
  vim.g.terminal_color_10 = "#a9b665"
  vim.g.terminal_color_11 = "#d8a657"
  vim.g.terminal_color_12 = "#7daea3"
  vim.g.terminal_color_13 = "#d3869b"
  vim.g.terminal_color_14 = "#89b482"
  vim.g.terminal_color_15 = "#d4be98"
end

vim.g.autoformat = false
