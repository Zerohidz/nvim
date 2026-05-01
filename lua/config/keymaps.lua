-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- Subword navigasyonu: ]v = ileri (e gibi, sona), [v = geri (b gibi, başa)
-- iv/av text object'iyle tutarlı. Türkçe klavyede: üv / ğv
-- PascalCase: Transformer|Maintenanc|e  Frontend|Busines|s
-- snake_case:  som|e_variabl|e
-- digit:       htt|p2x|x
--
-- İleri: subword'ün SONUNA atla  (\ze = cursor buraya düşer)
--   \l\ze\u      → küçük harf ÖNCESİ büyük harf: cursor küçük harfte  (rM → r)
--   \u\ze\u\l    → büyük-büyük-küçük: cursor 1. büyükte             (LPa → L)
--   \a\ze\d      → harf önce rakam                                   (p2  → p)
--   \d\ze\a      → rakam önce harf                                   (2x  → 2)
--   [^_]\ze_     → alt çizgi öncesi                                  (e_v → e)
--   \k\ze\>      → kelimenin son karakteri                           (end)
local _sw_end = [[\l\ze\u\|\u\ze\u\l\|\a\ze\d\|\d\ze\a\|[^_]\ze_\|\k\ze\>]]
--
-- Geri: önceki subword'ün BAŞINA atla  (\zs = cursor buraya düşer)
local _sw_bwd = [[\l\zs\u\|\u\zs\u\ze\l\|_\+\zs\k\|\a\zs\d\|\d\zs\a\|\<\zs\k]]

local function _sw_next()
  for _ = 1, vim.v.count1 do
    vim.fn.search(_sw_end, "W")
  end
end
local function _sw_prev()
  for _ = 1, vim.v.count1 do
    vim.fn.search(_sw_bwd, "bW")
  end
end

-- Terminalde: üv / ğv (langmap: ü→], ğ→[)
vim.keymap.set({ "n", "x", "o" }, "]v", _sw_next, { desc = "Next subword" })
vim.keymap.set({ "n", "x", "o" }, "[v", _sw_prev, { desc = "Prev subword" })

-- VSCodium: langmap ü→] çevirisi sonrası ] prefix state'i bekleme vscode-neovim'de
-- bozuluyor. Explicit üv/ğv tanımlamayla langmap+prefix zinciri bypass edilir.
vim.keymap.set({ "n", "x", "o" }, "üv", _sw_next, { desc = "Next subword" })
vim.keymap.set({ "n", "x", "o" }, "ğv", _sw_prev, { desc = "Prev subword" })

-- Terminal
local opts = { noremap = true, silent = true }
vim.keymap.set("t", "<C-n>", [[<C-\><C-n>]], { noremap = true })

-- Terminal modundayken doğrudan pencere değiştirme
vim.keymap.set("t", "<C-h>", [[<C-\><C-n><C-w>h]], opts)
vim.keymap.set("t", "<C-j>", [[<C-\><C-n><C-w>j]], opts)
vim.keymap.set("t", "<C-k>", [[<C-\><C-n><C-w>k]], opts)
vim.keymap.set("t", "<C-l>", [[<C-\><C-n><C-w>l]], opts)
