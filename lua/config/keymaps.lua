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
vim.keymap.set("t", "<C-n>", _save_term_cursor_and_go_normal, { expr = true, noremap = true })

-- Gerçek imleci (job'daki) hedef satır+ekran koluna taşır: kaydedilen pozisyonla
-- hedef arasındaki farkı önce yukarı/aşağı, sonra sol/sağ ok byte'ı olarak
-- gönderir, kaydı günceller. Çok satırlı input'ta satır atlamayı da destekler.
-- Çağıran taraf sadece _cursor_in_input_box() true ise bunu çağırır -- kutu
-- dışında (scrollback'te) kör delta göndermek Up/Down'ı claude'un prompt
-- geçmişini/agent view'i tetikleyen kısayollara çeviriyordu.
local function _real_cursor_goto(target_line, target_vcol)
  local chan = vim.b.terminal_job_id
  local saved_line = vim.b.term_cursor_line
  if not chan or not saved_line then
    return false
  end
  local line_delta = saved_line - target_line
  if line_delta ~= 0 then
    local vseq = line_delta > 0 and "\x1b[A" or "\x1b[B" -- Up/Down
    vim.api.nvim_chan_send(chan, vseq:rep(math.abs(line_delta)))
  end
  local col_delta = vim.b.term_cursor_vcol - target_vcol
  if col_delta ~= 0 then
    local seq = col_delta > 0 and "\x1b[D" or "\x1b[C"
    vim.api.nvim_chan_send(chan, seq:rep(math.abs(col_delta)))
  end
  vim.b.term_cursor_line = target_line
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
  if _real_cursor_goto(vim.fn.line("."), start_vcol) then
    local chan = vim.b.terminal_job_id
    vim.api.nvim_chan_send(chan, ("\x1b[3~"):rep(width))
  end
end

-- Terminal buffer'ında (bash toggleterm) o an gerçekten claude code çalışıyor
-- mu: buffer adı hep "bash" (toggleterm cmd bash, claude elle başlatılıyor),
-- o yüzden statik değil dinamik kontrol lazım: shell'in child process'lerine bak.
local function _is_claude_running()
  local chan = vim.b.terminal_job_id
  if not chan then
    return false
  end
  local ok, pid = pcall(vim.fn.jobpid, chan)
  if not ok or not pid then
    return false
  end
  local ok2, out = pcall(vim.fn.system, { "ps", "--ppid", tostring(pid), "-o", "args=" })
  return ok2 and out:find("claude") ~= nil
end

-- Bir tuşu default nvim davranışına (remap edilmeden) geri besler.
local function _fallback(keys)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), "n", false)
end

-- Claude code'un input kutusu her zaman düz çizgilerden (─/╭╮╰╯) bir border'la
-- çizili. Cursor o border çiftinin İÇİNDE mi diye taze bakıp karar veriyoruz
-- (flag/one-shot state yerine): C-d/C-u ile eski output'a gidip geri dönülse
-- bile her i/a basışında yeniden hesaplanır, doğru sonuç verir.
local _border_re = vim.regex([[^\s*[─═╭╮╰╯┌┐└┘]\+\s*$]])
local function _line_is_border(lnum)
  local text = vim.fn.getline(lnum)
  if text == "" then
    return false
  end
  return _border_re:match_str(text) ~= nil
end
local function _cursor_in_input_box()
  local last = vim.fn.line("$")
  local bottom
  for l = last, math.max(1, last - 200), -1 do
    if _line_is_border(l) then
      bottom = l
      break
    end
  end
  if not bottom then
    return false
  end
  local top
  for l = bottom - 1, math.max(1, bottom - 200), -1 do
    if _line_is_border(l) then
      top = l
      break
    end
  end
  if not top then
    return false
  end
  local cur = vim.fn.line(".")
  return cur > top and cur < bottom
end

-- Terminal normal modda (<C-n> sonrası): claude code çalışıyorsa C-d/C-u/gg/G
-- nvim buffer'ında scrollback gezmek yerine job'a yollansın; çalışmıyorsa
-- (düz bash) nvim'in kendi default davranışına düşülür.
-- claude code: Ctrl+D/Ctrl+U scroll:halfPage (~/.claude/keybindings.json),
-- gg/G için Ctrl+Home/Ctrl+End default (scroll:top/bottom).
vim.api.nvim_create_autocmd("TermOpen", {
  desc = "Terminal normal modda C-d/C-u/gg/G'yi (claude çalışıyorsa) job'a forward et",
  callback = function(args)
    -- Hem nvim'in kendi scrollback davranışı hem (claude çalışıyorsa) job'a
    -- forward: ikisi çakışmıyor, ikisi de olsun.
    local send = function(bytes, fallback_keys)
      return function()
        _fallback(fallback_keys)
        if _is_claude_running() then
          local chan = vim.b.terminal_job_id
          if chan then
            vim.api.nvim_chan_send(chan, bytes)
            vim.defer_fn(function()
              vim.cmd("redraw!")
            end, 80)
          end
        end
      end
    end
    local map_opts = { buffer = args.buf, noremap = true, silent = true }
    -- Ctrl+D/Ctrl+U yerine PageDown/PageUp: claude code'da bunlar zaten
    -- default halfPage scroll yapıyor, Ctrl+U'yu input kill-line için
    -- serbest bırakıyoruz (Scroll context modsuz aktif, çakışıyordu).
    vim.keymap.set("n", "<C-d>", send("\x1b[6~", "<C-d>"), map_opts) -- PageDown
    vim.keymap.set("n", "<C-u>", send("\x1b[5~", "<C-u>"), map_opts) -- PageUp
    vim.keymap.set("n", "gg", send("\x1b[1;5H", "gg"), map_opts) -- Ctrl+Home
    -- G (scroll:bottom, Ctrl+End): claude code'un bilinen bug'ı (>1 sayfa
    -- atlarsa pane blank kalıyor, upstream #71509). Workaround: force redraw
    -- hemen ardından gönder. Ctrl+L default'ta chat:clearInput olduğu için
    -- (input'u silmesin diye) app:redraw'ı ~/.claude/keybindings.json'da
    -- boş duran Ctrl+F'e bağladık, onu gönderiyoruz.
    vim.keymap.set("n", "G", function()
      _fallback("G")
      if _is_claude_running() then
        local chan = vim.b.terminal_job_id
        if chan then
          vim.api.nvim_chan_send(chan, "\x1b[1;5F") -- Ctrl+End
          vim.defer_fn(function()
            vim.api.nvim_chan_send(chan, "\x06") -- Ctrl+F -> app:redraw
          end, 50)
        end
      end
    end, map_opts)

    -- i/a (langmapper ile ı/a): insert'e dönmeden önce gerçek imleci şu anki
    -- nvim cursor kolonuna taşı. a, i'nin bir sağına geçer (append semantiği).
    -- SADECE cursor input kutusunun (border çizgileri arası) İÇİNDEYSE düzeltme
    -- gönderilir (gg/G/C-d/C-u ile eski output'a gidilip orda kalınmışsa hiç
    -- deneme -- kutu dışına kör delta göndermek Up/Down'ı önceki prompt/agent
    -- view tetikleyicisine çeviriyordu). Kutu içindeyken eski (kanıtlanmış,
    -- kör tek-seferlik) delta yöntemi kullanılır -- bkz. _real_cursor_goto notu.
    vim.keymap.set("n", "i", function()
      if not _is_claude_running() then
        _fallback("i")
        return
      end
      if _cursor_in_input_box() then
        _real_cursor_goto(vim.fn.line("."), vim.fn.virtcol("."))
      end
      vim.cmd("startinsert")
      vim.b.term_cursor_line = vim.fn.line(".")
      vim.b.term_cursor_vcol = vim.fn.virtcol(".")
    end, map_opts)
    vim.keymap.set("n", "a", function()
      if not _is_claude_running() then
        _fallback("a")
        return
      end
      if _cursor_in_input_box() then
        _real_cursor_goto(vim.fn.line("."), vim.fn.virtcol(".") + 1)
      end
      vim.cmd("startinsert")
      vim.b.term_cursor_line = vim.fn.line(".")
      vim.b.term_cursor_vcol = vim.fn.virtcol(".")
    end, map_opts)

    -- x: cursor'daki karakteri gerçek input'ta sil (insert'e geçmez).
    vim.keymap.set("n", "x", function()
      if not _is_claude_running() then
        _fallback("x")
        return
      end
      if _real_cursor_goto(vim.fn.line("."), vim.fn.virtcol(".")) then
        vim.api.nvim_chan_send(vim.b.terminal_job_id, "\x1b[3~")
      end
    end, map_opts)

    -- dw/db/diw: vim'in kendi word motion/textobject'ini simüle edip
    -- gerçek input'ta o kadar Delete tuşuyla siler (insert'e geçmez).
    vim.keymap.set("n", "dw", function()
      if not _is_claude_running() then
        _fallback("dw")
        return
      end
      _delete_word("w")
    end, map_opts)
    vim.keymap.set("n", "db", function()
      if not _is_claude_running() then
        _fallback("db")
        return
      end
      _delete_word("b")
    end, map_opts)
    vim.keymap.set("n", "diw", function()
      if not _is_claude_running() then
        _fallback("diw")
        return
      end
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

  -- Zoom (font + pencere birlikte büyür/küçülür): neovide_scale_factor tüm
  -- UI'yi ölçekliyor, numpad + gerektirmeyen <C-=>/<C--> art arda hızlı basılabilir.
  local function _zoom(delta)
    local scale = (vim.g.neovide_scale_factor or 1.0) + delta
    vim.g.neovide_scale_factor = math.max(0.3, math.min(3.0, scale))
  end
  local zoom_opts = { noremap = true, silent = true }
  vim.keymap.set({ "n", "i", "v", "t" }, "<C-=>", function() _zoom(0.05) end,
    vim.tbl_extend("force", zoom_opts, { desc = "Neovide zoom in" }))
  vim.keymap.set({ "n", "i", "v", "t" }, "<C-*>", function() _zoom(0.05) end,
    vim.tbl_extend("force", zoom_opts, { desc = "Neovide zoom in" }))
  vim.keymap.set({ "n", "i", "v", "t" }, "<C-->", function() _zoom(-0.05) end,
    vim.tbl_extend("force", zoom_opts, { desc = "Neovide zoom out" }))
  vim.keymap.set({ "n", "i", "v", "t" }, "<C-0>", function() vim.g.neovide_scale_factor = 0.95 end,
    vim.tbl_extend("force", zoom_opts, { desc = "Neovide zoom reset" }))
end


-- Sadece dosya adını kopyalar (Örn: index.js)
vim.keymap.set('n', '<leader>yf', "<cmd>let @+ = expand('%:t')<CR>", { desc = 'Dosya adını kopyala' })

-- ama neo-tree kökünün olduğu yerden başlayarak dosya yolunu kopyalar (Örn: /home/user/project/index.js)
vim.keymap.set('n', '<leader>yp', function()
  local relative_path = vim.fn.expand('%:.') -- '.' işareti aktif çalışma dizinine göre path verir
  vim.fn.setreg('+', relative_path)
  print("Kopyalanan yol (CWD): " .. relative_path)
end, { desc = 'Dosya yolunu kopyala' })


-- Manual
vim.keymap.set('n', '<leader>k', function()
  vim.cmd('Man ' .. vim.fn.expand('<cword>'))
end, { desc = 'Open man page for word under cursor' })
