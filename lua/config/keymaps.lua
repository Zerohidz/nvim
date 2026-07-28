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
-- Mod değişmeden ÖNCE gerçek imleç kolonunu kaydet: t->n geçişinde nvim
-- cursor satır sonundaysa (gap pozisyonu) son karaktere clamp ediyor,
-- geçiş SONRASI okumak 1 kayık pozisyon veriyordu.
local function _save_term_cursor_and_go_normal()
  vim.b.term_cursor_line = vim.fn.line(".")
  vim.b.term_cursor_vcol = vim.fn.virtcol(".")
  return vim.api.nvim_replace_termcodes([[<C-\><C-n>]], true, true, true)
end
vim.keymap.set("t", "<Esc>", _save_term_cursor_and_go_normal, { expr = true, noremap = true })

-- Gerçek Escape'i claude code'a göndermek istersen (chat:cancel default'u):
-- <Esc> artık normal moda geçiyor, onun yerine <C-e> ham ESC byte'ı yollar.
-- Sadece terminal-insert modda ('t'), başka moddaki C-e'ye dokunmuyor.
vim.keymap.set("t", "<C-e>", function()
  local chan = vim.b.terminal_job_id
  if chan then
    vim.api.nvim_chan_send(chan, "\x1b")
  end
end, opts)

-- Terminal normal modda (<C-n> sonrası): C-d/C-u/gg/G nvim buffer'ında
-- scrollback gezmek yerine, altta koşan programa (claude code) yollansın.
-- claude code: Ctrl+D/Ctrl+U scroll:halfPage (~/.claude/keybindings.json),
-- gg/G için Ctrl+Home/Ctrl+End default (scroll:top/bottom).
vim.api.nvim_create_autocmd("TermOpen", {
  desc = "Terminal normal modda C-d/C-u/gg/G'yi job'a forward et",
  callback = function(args)
    local send = function(bytes)
      return function()
        local chan = vim.b.terminal_job_id
        if chan then
          vim.api.nvim_chan_send(chan, bytes)
          vim.defer_fn(function()
            vim.cmd("redraw!")
          end, 80)
        end
      end
    end
    local map_opts = { buffer = args.buf, noremap = true, silent = true }
    -- Ctrl+D/Ctrl+U yerine PageDown/PageUp: claude code'da bunlar zaten
    -- default halfPage scroll yapıyor, Ctrl+U'yu input kill-line için
    -- serbest bırakıyoruz (Scroll context modsuz aktif, çakışıyordu).
    vim.keymap.set("n", "<C-d>", send("\x1b[6~"), map_opts) -- PageDown
    vim.keymap.set("n", "<C-u>", send("\x1b[5~"), map_opts) -- PageUp
    vim.keymap.set("n", "gg", send("\x1b[1;5H"), map_opts) -- Ctrl+Home
    -- G (scroll:bottom, Ctrl+End): claude code'un bilinen bug'ı (>1 sayfa
    -- atlarsa pane blank kalıyor, upstream #71509). Workaround: force redraw
    -- hemen ardından gönder. Ctrl+L default'ta chat:clearInput olduğu için
    -- (input'u silmesin diye) app:redraw'ı ~/.claude/keybindings.json'da
    -- boş duran Ctrl+F'e bağladık, onu gönderiyoruz.
    vim.keymap.set("n", "G", function()
      local chan = vim.b.terminal_job_id
      if chan then
        vim.api.nvim_chan_send(chan, "\x1b[1;5F") -- Ctrl+End
        vim.defer_fn(function()
          vim.api.nvim_chan_send(chan, "\x06") -- Ctrl+F -> app:redraw
        end, 50)
      end
    end, map_opts)

    -- i/a (langmapper ile ı/a): insert'e dönmeden önce, kaydedilen kolon ile
    -- şu anki nvim cursor kolonu arasındaki farkı gerçek sol/sağ ok tuşu
    -- olarak job'a yollayıp uygulamanın imlecini oraya taşı, sonra insert'e gir.
    -- a, i'nin bir sağına geçer (vim'deki append semantiği).
    local function _goto_real_cursor(extra_right)
      local chan = vim.b.terminal_job_id
      local saved_line = vim.b.term_cursor_line
      local saved_vcol = vim.b.term_cursor_vcol
      if chan and saved_line and vim.fn.line(".") == saved_line then
        local delta = saved_vcol - vim.fn.virtcol(".") - extra_right
        if delta ~= 0 then
          local seq = delta > 0 and "\x1b[D" or "\x1b[C"
          vim.api.nvim_chan_send(chan, seq:rep(math.abs(delta)))
        end
      end
      vim.cmd("startinsert")
    end
    vim.keymap.set("n", "i", function()
      _goto_real_cursor(0)
    end, map_opts)
    vim.keymap.set("n", "a", function()
      _goto_real_cursor(1)
    end, map_opts)
  end,
})

-- Terminal modundayken doğrudan pencere değiştirme
vim.keymap.set("t", "<C-h>", [[<C-\><C-n><C-w>h]], opts)
vim.keymap.set("t", "<C-j>", [[<C-\><C-n><C-w>j]], opts)
vim.keymap.set("t", "<C-k>", [[<C-\><C-n><C-w>k]], opts)
vim.keymap.set("t", "<C-l>", [[<C-\><C-n><C-w>l]], opts)

-- 1 Numaralı Terminal (<C-t>)
vim.keymap.set({ "n", "t" }, "<C-t>", "<cmd>1ToggleTerm<CR>", { noremap = true, silent = true, desc = "Terminal 1" })

-- 2 Numaralı Terminal (<C-.>)
vim.keymap.set({ "n", "t" }, "<C-.>", "<cmd>2ToggleTerm<CR>", { noremap = true, silent = true, desc = "Terminal 2" })

-- (Opsiyonel) Klavye <C-/> tuşunu da aynı yere yolluyorsa (LazyVim varsayılanı için):
vim.keymap.set({ "n", "t" }, "<C-/>", "<cmd>2ToggleTerm<CR>", { noremap = true, silent = true, desc = "Terminal 2" })

-- 3 Numaralı Terminal (<C-,> yani Ctrl + Virgül)
vim.keymap.set({ "n", "t" }, "<C-,>", "<cmd>3ToggleTerm<CR>", { noremap = true, silent = true, desc = "Terminal 3" })

-- Neovide: Hyprland Super+V → Shift+Insert gönderir, terminal bunu paste'e çevirirdi
-- Neovide ise Shift+Insert'i handle etmez, explicit map lazım
if vim.g.neovide then
  local function paste()
    vim.api.nvim_paste(vim.fn.getreg("+"), true, -1)
  end
  -- Super+V (Hyprland → Shift+Insert olarak gelir)
  vim.keymap.set({ "n", "v", "i", "c", "t" }, "<S-Insert>", paste, { noremap = true, silent = true, desc = "Paste (Neovide)" })

  -- Omarchy universal clipboard, Neovide'yi terminal sınıfı saymıyor (class=neovide,
  -- clipboard.lua'daki terminal_classes listesinde yok) → Super+V burda Shift+Insert
  -- değil CTRL+V yolluyor. n/i/v/c'de CTRL+V zaten Neovide GUI paste'iyle çalışıyor,
  -- ama toggleterm'in "t" modunda CTRL+V job'a ^V byte'ı olarak gidiyordu, paste olmuyordu.
  vim.keymap.set("t", "<C-v>", paste, { noremap = true, silent = true, desc = "Paste (Neovide terminal mode)" })

  -- Shift+Enter: insert modda normal newline
  vim.keymap.set("i", "<S-CR>", "<CR>", { noremap = true, silent = true, desc = "Shift+Enter newline" })
  -- Shift+Enter: terminal modda kitty escape sequence gönder (Claude Code bunu bekliyor)
  vim.keymap.set("t", "<S-CR>", function()
    local chan = vim.b.terminal_job_id
    if chan then
      vim.api.nvim_chan_send(chan, "\x1b[13;2u")
    end
  end, { noremap = true, silent = true, desc = "Shift+Enter → kitty sequence (terminal)" })
end


-- Sadece dosya adını kopyalar (Örn: index.js)
vim.keymap.set('n', '<leader>yf', "<cmd>let @+ = expand('%:t')<CR>", { desc = 'Dosya adını kopyala' })

-- ama neo-tree kökünün olduğu yerden başlayarak dosya yolunu kopyalar (Örn: /home/user/project/index.js)
vim.keymap.set('n', '<leader>yp', function()
  local relative_path = vim.fn.expand('%:.') -- '.' işareti aktif çalışma dizinine göre path verir
  vim.fn.setreg('+', relative_path)
  print("Kopyalanan yol (CWD): " .. relative_path)
end, { desc = 'Dosya yolunu kopyala' })
