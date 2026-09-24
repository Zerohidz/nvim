require("config.remote_clipboard").setup()
-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here
vim.opt.relativenumber = false

-- Global indent: 4 boşluk (LazyVim default'u 2). Java dahil tüm dosyalar için geçerli;
-- jdtls formatlarken de shiftwidth'i tabSize olarak kullanır.
vim.opt.shiftwidth = 4
vim.opt.tabstop = 4
vim.opt.softtabstop = 4
vim.opt.expandtab = true

-- unnamedplus: y (normal+visual) otomatik sistem panosuna gider.
-- x/d/c/s (normal+visual) init.lua'da blackhole ("_) register'a map'li,
-- bu yüzden clipboard opt'undan etkilenmezler — hiçbir yere yazmazlar.
-- <leader>d/c/s/x ise "+ register'a sabit, bilinçli cut için hep pano'ya
-- yazar (SSH/tmux'ta remote_clipboard.lua'nın osc52/wl-copy provider'ıyla).
vim.opt.clipboard = "unnamedplus"

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

  -- Ekran'a göre scale: Retina/HiDPI (OS scale >= 2) -> 1.8, 1x monitor (1080p vb.) -> 1.05
  -- Referans: menubar'li ana ekran (JXA). Pencereyi 1x monitörde kullanacaksan onu
  -- ana ekran yap; tek tuşla düzeltme: <C-0> (NeovideFitScale), ince ayar <C-*>/<C-->.
  -- Not: scale sadece acilista (VimEnter) uygulanir; pencere/split degisimlerinde
  -- (orn. neo-tree acilisi) resetlenmez, manuel zoom korunur.
  local RETINA_SCALE = 1.8
  local FHD_SCALE = 1.05
  local function fit_display_scale()
    local ok, out = pcall(vim.fn.system, {
      "osascript",
      "-l",
      "JavaScript",
      "-e",
      [[ObjC.import("Cocoa"); String($.NSScreen.screens.objectAtIndex(0).backingScaleFactor)]],
    })
    local sf = ok and tonumber((out or ""):match("%d+%.?%d*"))
    if sf then
      vim.g.neovide_scale_factor = sf >= 2 and RETINA_SCALE or FHD_SCALE
    end
  end
  vim.g.neovide_scale_factor = RETINA_SCALE -- acilis defaultu; VimEnter'da duzeltildi
  vim.api.nvim_create_user_command("NeovideFitScale", fit_display_scale, {})
  vim.api.nvim_create_autocmd("VimEnter", { once = true, callback = fit_display_scale })
  vim.g.neovide_opacity = 0.95
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
