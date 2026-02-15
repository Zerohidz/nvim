---@diagnostic disable: undefined-global

-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")

-- Türkçe klavye düzeltmesini yükle
require("config.turkish_keys").setup()

-- #############################################################################
-- # Neovim Türkçe Q Klavye Normal Mod Optimizasyonu (Tam Kapsamlı)
-- #############################################################################
-- make deletion shortcuts not copy the deleted content into clipboard

-- =========================
-- SAFE DELETE (black hole)
-- =========================

-- Tek karakter sil
vim.keymap.set("n", "x", '"_x', opts)

-- Normal mode delete
vim.keymap.set("n", "d", '"_d', opts)
vim.keymap.set("n", "dd", '"_dd', opts)

-- Visual mode delete
vim.keymap.set("v", "d", '"_d', opts)

-- Change (c) de clipboard bozmasın
vim.keymap.set("n", "c", '"_c', opts)
vim.keymap.set("v", "c", '"_c', opts)

-- s
vim.keymap.set("n", "s", '"_s')
vim.keymap.set("v", "s", '"_s')

-- =========================
-- CUT (bilinçli kesme)
-- =========================

-- Normal mode cut
vim.keymap.set("n", "<leader>d", "d", opts)
vim.keymap.set("n", "<leader>dd", "dd", opts)

-- Visual mode cut
vim.keymap.set("v", "<leader>d", "d", opts)

-- Change + cut
vim.keymap.set("n", "<leader>c", "c", opts)
vim.keymap.set("v", "<leader>c", "c", opts)

-- Cut s
vim.keymap.set("n", "<leader>s", "s")
vim.keymap.set("v", "<leader>s", "s")

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

-- Set spellcheck off
vim.api.nvim_create_autocmd({ "BufEnter", "BufWinEnter" }, {
  callback = function()
    vim.opt_local.spell = false
  end,
})
