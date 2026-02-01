---@diagnostic disable: undefined-global

-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")

-- Türkçe klavye düzeltmesini yükle
require("config.turkish_keys").setup()

-- #############################################################################
-- # Neovim Türkçe Q Klavye Normal Mod Optimizasyonu (Tam Kapsamlı)
-- #############################################################################
-- make deletion shortcuts not copy the deleted content into clipboard
vim.keymap.set("n", "x", '"_x')
vim.keymap.set("n", "d", '"_d')
vim.keymap.set("v", "d", '"_d')


-- #############################################################################
-- # Küçük kişisel ayarlar
-- #############################################################################

-- RelativeNumber gösterimini aç -----------------------------------------------
-- Başlangıç durumu
vim.opt.number = true
vim.opt.relativenumber = true

-- Insert mode'a girince kapat
vim.api.nvim_create_autocmd("InsertEnter", {
  callback = function()
    vim.opt.relativenumber = false
  end,
})

-- Insert mode'dan çıkınca aç
vim.api.nvim_create_autocmd("InsertLeave", {
  callback = function()
    vim.opt.relativenumber = true
  end,
})
