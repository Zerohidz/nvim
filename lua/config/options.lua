-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here
vim.opt.relativenumber = false

-- Türkçe klavye textobject fix: ı→i'den sonra İ/Ğ için yeterli süre
-- Default 300ms, 500ms ile tuş arası 500ms'e kadar olan gecikmeler çalışır
vim.opt.timeoutlen = 3000

if vim.g.neovide then
  vim.o.guifont = "CaskaydiaMono Nerd Font:h10"
  vim.g.neovide_scale_factor = 1.0
  vim.g.neovide_padding_top = 30
  vim.g.neovide_padding_bottom = 30
  vim.g.neovide_padding_left = 30
  vim.g.neovide_padding_right = 30
end
