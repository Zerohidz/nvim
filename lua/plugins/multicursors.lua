-- Multicursor. Neovim 0.13+ yerleşik olanı kullanır (:h multicursor; yazarken diğer imleçlerde canlı
-- görünür). Daha eskisinde jake-stewart/multicursor.nvim. Eski smoka7/multicursors.nvim (hydra) çıkışta
-- which-key'in buffer tetikleyicilerini (i, [, ], z) bozuk geri yüklüyordu → ı/i insert'e girmiyordu.
local native = vim.fn.has("nvim-0.13") == 1

-- <leader>j/k sonrası j/k basılı tutulursa (ya da arka arkaya basılırsa) imleç eklemeye devam et.
-- Hyprland repeat_delay 250ms; 500ms j/k gelmezse ya da başka tuş basılırsa biter.
-- Döngüyle tuş okunmuyor: plugin'in eklemesi feedkeys ile ertelenmiş çalışıyor. Bunun yerine geçici
-- buffer-local j/k map'leri; bitişte sadece onlar silinir (mevcut map kaydedip geri yükleme yok).
local sticky_ns = vim.api.nvim_create_namespace("multicursor_sticky_lines")
local function sticky_lines(add, dir)
  local timer = assert(vim.uv.new_timer())
  local buf

  local function stop()
    timer:stop()
    vim.on_key(nil, sticky_ns)
    if buf and vim.api.nvim_buf_is_valid(buf) then
      pcall(vim.keymap.del, "n", "j", { buffer = buf })
      pcall(vim.keymap.del, "n", "k", { buffer = buf })
    end
    buf = nil
  end

  local function step(d)
    add(d)
    timer:stop()
    timer:start(500, 0, vim.schedule_wrap(stop))
  end

  return function()
    if buf then
      return step(dir)
    end
    step(dir)
    -- Buffer'da zaten j/k map'i varsa ezme; tek seferlik ekleme ile yetin.
    local cur = vim.api.nvim_get_current_buf()
    for _, key in ipairs({ "j", "k" }) do
      if vim.fn.maparg(key, "n", false, true).buffer == 1 then
        return
      end
    end
    buf = cur
    vim.keymap.set("n", "j", function() step(1) end, { buffer = buf, nowait = true })
    vim.keymap.set("n", "k", function() step(-1) end, { buffer = buf, nowait = true })
    vim.on_key(function(_, typed)
      if typed ~= "" and typed ~= "j" and typed ~= "k" then
        vim.schedule(stop)
      end
    end, sticky_ns)
  end
end

local function setup_native()
  local ns = vim.api.nvim_create_namespace("nvim.multicursor")
  local function active()
    return #vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, { limit = 1 }) > 0
  end
  local function normal(keys)
    vim.cmd.normal({ vim.keycode(keys), bang = true })
  end

  local set = vim.keymap.set
  -- Buraya imleç koy, ana imleç sonraki eşleşmeye geçsin (eski <leader>m akışı)
  -- `*` arama register'ını ve hlsearch'ü değiştirir; plugin sürümü değiştirmiyordu, geri al.
  local function keep_search(keys)
    return function()
      local pattern, hl = vim.fn.getreg("/"), vim.v.hlsearch
      normal(keys)
      vim.fn.setreg("/", pattern)
      vim.schedule(function() vim.v.hlsearch = hl end)
    end
  end
  set("n", "<leader>m", keep_search("Q*"), { desc = "Multicursor: sonraki eşleşme" })
  set("n", "<leader>M", keep_search("zq*"), { desc = "Multicursor: tüm eşleşmeler" })
  set("x", "<leader>M", "zq*", { remap = false, desc = "Multicursor: seçimdeki tüm eşleşmeler" })
  set("n", "<leader>j", sticky_lines(function(dir) normal(dir > 0 and "Qj" or "Qk") end, 1), { desc = "Multicursor: alt satır" })
  set("n", "<leader>k", sticky_lines(function(dir) normal(dir > 0 and "Qj" or "Qk") end, -1), { desc = "Multicursor: üst satır" })

  -- 0.13'te Q imleç koyuyor; 0.12'deki "son kaydedilen makroyu [count] kez oynat" korunur.
  -- Yukarıdaki normal("Q…") bang'li olduğu için yerleşik Q'ya gider.
  set("n", "Q", function()
    local reg = vim.fn.reg_recorded()
    return reg ~= "" and "@" .. reg or ""
  end, { expr = true, desc = "Son kaydedilen makroyu oynat" })

  -- <C-l> (yerleşik temizleme) LazyVim'de pencere geçişi; imleç varken <Esc> temizlesin.
  local esc = vim.fn.maparg("<Esc>", "n", false, true)
  set("n", "<Esc>", function()
    if active() then
      vim.api.nvim_buf_clear_namespace(0, ns, 0, -1)
      return ""
    end
    if esc.callback then
      return esc.callback()
    end
    return esc.rhs ~= nil and vim.keycode(esc.rhs) or vim.keycode("<Esc>")
  end, { expr = true, desc = "Multicursor temizle / Esc" })
end

local function setup_plugin()
  local mc = require("multicursor-nvim")
  mc.setup()

  local set = vim.keymap.set

  -- Kelime/seçim eşleşmesine imleç ekle (eski <leader>m akışı)
  set({ "n", "x" }, "<leader>m", function() mc.matchAddCursor(1) end, { desc = "Multicursor: sonraki eşleşme" })
  set({ "n", "x" }, "<leader>M", mc.matchAllAddCursors, { desc = "Multicursor: tüm eşleşmeler" })

  set({ "n", "x" }, "<leader>j", sticky_lines(mc.lineAddCursor, 1), { desc = "Multicursor: alt satır" })
  set({ "n", "x" }, "<leader>k", sticky_lines(mc.lineAddCursor, -1), { desc = "Multicursor: üst satır" })

  -- Her satıra imleç: gaıp (paragraf) ya da görsel seçim + ga.
  -- Plugin g@'yi typeahead'in SONUNA feed ediyor ("nt"); hızlı yazınca "ıp" önce işlenip
  -- insert'e giriyordu. Feed'i başa ("i") zorla.
  set({ "n", "x" }, "ga", function()
    local feedkeys = vim.fn.feedkeys
    vim.fn.feedkeys = function(keys, mode)
      return feedkeys(keys, (mode or "") .. "i")
    end
    local ok, err = pcall(mc.addCursorOperator)
    vim.fn.feedkeys = feedkeys
    if not ok then
      error(err)
    end
  end, { desc = "Multicursor: aralıktaki her satır" })

  -- Ctrl+tık ile imleç ekle/kaldır
  set("n", "<C-LeftMouse>", mc.handleMouse)
  set("n", "<C-LeftDrag>", mc.handleMouseDrag)
  set("n", "<C-LeftRelease>", mc.handleMouseRelease)

  -- Yalnızca birden fazla imleç varken
  mc.addKeymapLayer(function(layerSet)
    -- Eski hydra'daki n/N/q/Q alışkanlığı
    layerSet({ "n", "x" }, "n", function() mc.matchAddCursor(1) end)
    layerSet({ "n", "x" }, "N", function() mc.matchAddCursor(-1) end)
    layerSet({ "n", "x" }, "q", function() mc.matchSkipCursor(1) end)
    layerSet({ "n", "x" }, "Q", function() mc.matchSkipCursor(-1) end)

    layerSet({ "n", "x" }, "<Left>", mc.prevCursor)
    layerSet({ "n", "x" }, "<Right>", mc.nextCursor)

    layerSet("n", "<Esc>", function()
      if not mc.cursorsEnabled() then
        mc.enableCursors()
      else
        mc.clearCursors()
      end
    end)
  end)

  local hl = vim.api.nvim_set_hl
  hl(0, "MultiCursorCursor", { reverse = true })
  hl(0, "MultiCursorVisual", { link = "Visual" })
  hl(0, "MultiCursorSign", { link = "SignColumn" })
  hl(0, "MultiCursorMatchPreview", { link = "Search" })
  hl(0, "MultiCursorDisabledCursor", { reverse = true })
  hl(0, "MultiCursorDisabledVisual", { link = "Visual" })
  hl(0, "MultiCursorDisabledSign", { link = "SignColumn" })
end

if native then
  -- schedule: LazyVim'in VeryLazy'de kurduğu <Esc> map'inden sonra sarmalansın
  vim.api.nvim_create_autocmd("User", { pattern = "VeryLazy", once = true, callback = vim.schedule_wrap(setup_native) })
end

return {
  "jake-stewart/multicursor.nvim",
  branch = "1.0",
  enabled = not native,
  event = "VeryLazy",
  config = setup_plugin,
}
