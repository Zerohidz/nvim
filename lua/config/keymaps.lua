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

-- Gerçek imleci (job'daki) hedef ekran koluna taşı: kaydedilen pozisyonla
-- hedef arasındaki farkı sol/sağ ok byte'ı olarak gönderir, kaydı günceller.
local function _real_cursor_goto(target_vcol)
  local chan = vim.b.terminal_job_id
  local saved_line = vim.b.term_cursor_line
  if not chan or not saved_line or vim.fn.line(".") ~= saved_line then
    return false
  end
  local delta = vim.b.term_cursor_vcol - target_vcol
  if delta ~= 0 then
    local seq = delta > 0 and "\x1b[D" or "\x1b[C"
    vim.api.nvim_chan_send(chan, seq:rep(math.abs(delta)))
  end
  vim.b.term_cursor_vcol = target_vcol
  return true
end

-- w/b/iw motion'ının sınırlarını, gerçek terminal buffer'ını hiç değiştirmeden
-- hesaplamak için: satırı tek satırlık bir scratch buffer'a kopyala, vim'in
-- kendi motion/textobject algoritmasını orda çalıştır, sonucu satırdaki byte
-- kolonlarına çevir. dw/db/diw'in davranışını simüle etmek için kullanılıyor.
local function _word_bounds(kind)
  local line = vim.fn.getline(".")
  local col = vim.fn.col(".")
  local scratch = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(scratch, 0, -1, false, { line })
  local start_col, end_col
  vim.api.nvim_buf_call(scratch, function()
    vim.api.nvim_win_set_cursor(0, { 1, col - 1 })
    if kind == "w" then
      vim.cmd("normal! w")
      local c = vim.api.nvim_win_get_cursor(0)
      start_col = col
      end_col = c[2] + 1
      if end_col <= start_col then
        end_col = #line + 1
      end
    elseif kind == "b" then
      vim.cmd("normal! b")
      local c = vim.api.nvim_win_get_cursor(0)
      start_col = c[2] + 1
      end_col = col
    elseif kind == "iw" then
      -- Visual+getpos nvim_buf_call içinde güvenilmezdi; asıl 'diw' operatörünü
      -- scratch'te çalıştırıp öncesi/sonrası satırı diff'leyerek aralığı bul.
      vim.cmd("normal! diw")
      local newline = vim.api.nvim_buf_get_lines(scratch, 0, 1, false)[1] or ""
      local maxp = math.min(#line, #newline)
      local p = 0
      while p < maxp and line:sub(p + 1, p + 1) == newline:sub(p + 1, p + 1) do
        p = p + 1
      end
      start_col = p + 1
      end_col = p + 1 + (#line - #newline)
    end
  end)
  vim.api.nvim_buf_delete(scratch, { force = true })
  if not start_col or not end_col or end_col <= start_col then
    return nil
  end
  local before = line:sub(1, start_col - 1)
  local deleted = line:sub(start_col, end_col - 1)
  return vim.fn.strdisplaywidth(before) + 1, vim.fn.strdisplaywidth(deleted)
end

-- dw/db/diw: hedef aralığa gerçek imleci taşı, o kadar Delete tuşu gönder.
local function _delete_word(kind)
  local start_vcol, width = _word_bounds(kind)
  if not start_vcol or width == 0 then
    return
  end
  if _real_cursor_goto(start_vcol) then
    local chan = vim.b.terminal_job_id
    vim.api.nvim_chan_send(chan, ("\x1b[3~"):rep(width))
  end
end

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

    -- i/a (langmapper ile ı/a): insert'e dönmeden önce gerçek imleci şu anki
    -- nvim cursor kolonuna taşı. a, i'nin bir sağına geçer (append semantiği).
    vim.keymap.set("n", "i", function()
      _real_cursor_goto(vim.fn.virtcol("."))
      vim.cmd("startinsert")
    end, map_opts)
    vim.keymap.set("n", "a", function()
      _real_cursor_goto(vim.fn.virtcol(".") + 1)
      vim.cmd("startinsert")
    end, map_opts)

    -- x: cursor'daki karakteri gerçek input'ta sil (insert'e geçmez).
    vim.keymap.set("n", "x", function()
      if _real_cursor_goto(vim.fn.virtcol(".")) then
        vim.api.nvim_chan_send(vim.b.terminal_job_id, "\x1b[3~")
      end
    end, map_opts)

    -- dw/db/diw: vim'in kendi word motion/textobject'ini simüle edip
    -- gerçek input'ta o kadar Delete tuşuyla siler (insert'e geçmez).
    vim.keymap.set("n", "dw", function()
      _delete_word("w")
    end, map_opts)
    vim.keymap.set("n", "db", function()
      _delete_word("b")
    end, map_opts)
    vim.keymap.set("n", "diw", function()
      _delete_word("iw")
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
