-- lua/config/turkish_keys.lua
local M = {}

-- Neovim, çok baytlı langmap karakterini map aramasından ÖNCE mi çeviriyor? (neovim db0fca2,
-- 0.13-dev; tek baytta 0.12'de de böyle.) Evet ise yazılan ı → i olur ve `i` lhs'li her map
-- (ör. langmapper'ın `'` varyantı) ı'yı yutar. Sürüm yerine davranış ölçülür: backport ya da
-- geri alma olursa da doğru kalır. Geçici "ıl" langmap'i: eski davranışta sadece l (sağa) çalışır.
--
-- Aynı değişiklik Ctrl'den sonraki karakteri her modda (insert dahil) langmap'liyor ama map'in
-- lhs'ini çevirmiyor: langmapper'ın <C-ü> → <C-]> gibi map_all_ctrl map'lerine hiç ulaşılamıyor.
-- <C-]> map'i yoksa <C-ü> ham kalıyor. ctrl_tr_lost.
local function probe_langmap(keys, lhs)
  local saved = vim.o.langmap
  local buf = vim.api.nvim_create_buf(false, true)
  local hit = false
  vim.o.langmap = "ıl"
  local ok = pcall(vim.api.nvim_buf_call, buf, function()
    vim.keymap.set("n", lhs, function() hit = true end, { buffer = buf })
    vim.api.nvim_feedkeys(vim.keycode(keys), "xt", false)
  end)
  vim.o.langmap = saved
  vim.api.nvim_buf_delete(buf, { force = true })
  return ok and hit
end

-- langmapper setup'ından önce seçenekleri hazırla; keymap/hook'lar sonra kurulur.
function M.setup_langmap()
  M.native_multibyte_langmap = probe_langmap("ı", "l")
  M.ctrl_tr_lost = M.native_multibyte_langmap and not probe_langmap("<C-ı>", "<C-ı>")
  vim.opt.langremap = false

  local function escape(str)
    return vim.fn.escape(str, [[;,."|\]])
  end

  -- Türkçe Q klavye: bastığın tuş -> Vim'in görmesi gereken
  local maps = {
    { "ı", "i" },
    { "i", "'" },
    { "ş", ";" },
    { "ğ", "[" },
    { "ü", "]" },
    { "ö", "," },
    { "ç", "." },
    { "İ", '"' },
    { "Ş", ":" },
    { "Ğ", "{" },
    { "Ü", "}" },
    { "Ö", "<" },
    { "Ç", ">" },
    { ".", "/" },
    { ":", "?" },
    { ",", "\\" },
    { ";", "|" },
  }

  local pairs_list = {}
  for _, pair in ipairs(maps) do
    table.insert(pairs_list, escape(pair[1]) .. escape(pair[2]))
  end

  vim.opt.langmap = table.concat(pairs_list, ",")
  M.langmap_pairs = maps
end

function M.setup()
  if M._configured then return end
  M._configured = true
  M.setup_langmap()

  -- Textobject düzeltmesi:
  -- Hızlı yazınca langmap textobject'in 2. karakterini (İ, Ğ, vs.) çevirmiyor.
  -- Sebep: C-level handler sonraki char'ı doğrudan input buffer'dan okuyor.
  -- Çözüm 1: tek karakter op-pending keymap → C-level okuma sırasında da uygulanır.
  -- Çözüm 2: iX/aX explicit keymapları → yavaş yazma için yedek yol.
  local tr_to_en = {
    { "İ", '"' },
    { "i", "'" },
    { "ğ", "[" },
    { "ü", "]" },
    { "Ğ", "{" },
    { "Ü", "}" },
    { "Ö", "<" },
    { "Ç", ">" },
    { "ç", "." },
    { "ö", "," },
    { "ş", ";" },
    { "Ş", ":" },
    { "ı", "i" },
  }
  -- Yerel çok baytlı langmap'te textobject karakteri de çevriliyor; bu map'ler o zaman zararlı:
  -- ı→i ile `i`→`'` zinciri dıw'yi d'w yapar, iX/aX o-modda `i`/`a`'yı belirsizleştirir.
  for _, pair in ipairs(M.native_multibyte_langmap and {} or tr_to_en) do
    -- Tek karakter: op-pending ve visual'da her bağlamda çalışır (hızlı yazma fix)
    vim.keymap.set({ "x", "o" }, pair[1], pair[2], { remap = true, silent = true })
    -- iX / aX: belt and suspenders
    vim.keymap.set({ "x", "o" }, "i" .. pair[1], "i" .. pair[2], { remap = true, silent = true })
    vim.keymap.set({ "x", "o" }, "a" .. pair[1], "a" .. pair[2], { remap = true, silent = true })
  end

  -- Ctrl+TR kayboluyorsa (ctrl_tr_lost) map ile yakalanamaz: tuş map'siz çekirdeğe ulaştığında
  -- (key == typed) on_key'de yut, langmapper'ın map_all_ctrl karşılığını (<C-ü> → <C-]> ...) gönder.
  -- Langmap'in uygulanıp uygulanmaması önceki tuşun KeyTyped'ına bağlı (LANGMAP_ADJUST); langmapper
  -- map'i eşleşirse key = K_LUA olur, o zaman dokunma. Beslenen tuşun typed'ı boş, döngü olmaz.
  -- <C-ğ> (= <C-[> = Esc) langmapper.lua'da bilerek siliniyor; Esc map'lerine düşmesin diye noremap.
  if M.ctrl_tr_lost then
    local ctrl = {}
    for _, pair in ipairs(M.langmap_pairs) do
      if #pair[1] > 1 then
        local en = pair[1] == "ğ" and pair[1] or ({ ["<"] = "lt" })[pair[2]] or pair[2]
        ctrl[vim.keycode("<C-" .. pair[1] .. ">")] = { vim.keycode("<C-" .. en .. ">"), pair[1] == "ğ" and "ni" or "mi" }
      end
    end
    vim.on_key(function(key, typed)
      local to = ctrl[typed]
      if to and key == typed and not vim.fn.mode():match("^[sS\19]") then
        vim.api.nvim_feedkeys(to[1], to[2], false)
        return ""
      end
    end, vim.api.nvim_create_namespace("turkish_keys_ctrl_tr"))
  end

  -- Yerel langmap'te kısmi eşleşme hatası: input.c handle_mapping, çevrilmiş çok baytlı ilk tuşu
  -- (ü, 2 bayt) map'in lhs'iyle (], 1 bayt) bayt sayısıyla karşılaştırıyor; ü tek başına gelince
  -- (insan hızı) `]v` kısmi eşleşme sayılmıyor, d ü v → d + ham ü + v. n modunda which-key'in `]`
  -- tetikleyicisi bunu örtüyor; x/o'da aynı şeyi yap: `]`/`[` tam eşleşir, sonraki tuşu okur.
  -- Map varsa remap'le besle (en uzun eşleşme kazanır; expr dönüşü olamaz: lhs ile başlayan rhs'nin
  -- ilk tuşu yeniden map'lenmez), yoksa yerleşik komuta çevrilmiş karakterle noremap ver (map'ten
  -- gelen tuşa langmap uygulanmaz). Hata düzelse de zararsız: kısmi eşleşme bu map'ten önce bekler.
  if M.native_multibyte_langmap then
    local lm = {}
    for _, pair in ipairs(M.langmap_pairs) do lm[pair[1]] = pair[2] end
    for _, key in ipairs({ "]", "[" }) do
      vim.keymap.set({ "x", "o" }, key, function()
        local ok, c = pcall(vim.fn.getcharstr)
        local mode = vim.fn.mode(1):match("^no") and "o" or "x"
        -- İptal: yerleşik `]<Esc>` operatörü bırakır, visual'da kalır.
        if not ok or c == "\27" or c == "\3" then return mode == "o" and "<Esc>" or "" end
        local mapped = vim.fn.maparg(key .. (lm[c] or c), mode) ~= "" or vim.fn.maparg(key .. c, mode) ~= ""
        vim.api.nvim_feedkeys(mapped and key .. c or key .. (lm[c] or c), mapped and "mi" or "ni", false)
        return ""
      end, { expr = true, desc = key .. " (yerel langmap kısmi eşleşme düzeltmesi)" })
    end
  end

  -- ---------------------------------------------------------------------------
  -- Makro kaydı fix: Neovim makroları pre-langmap karakterleri kaydeder (ı, ğ…)
  -- RecordingLeave'de normal-mod kısımlarını Türkçe→İngilizce çeviririz.
  -- Insert moddaki Türkçe metne dokunulmaz.
  -- ---------------------------------------------------------------------------
  local tr_to_en_macro = {
    ["ı"] = "i",  ["i"] = "'",  ["ş"] = ";",  ["ğ"] = "[",  ["ü"] = "]",
    ["ö"] = ",",  ["ç"] = ".",  ["İ"] = '"',  ["Ş"] = ":",  ["Ğ"] = "{",
    ["Ü"] = "}",  ["Ö"] = "<",  ["Ç"] = ">",  ["."] = "/",  [":"] = "?",
    [","] = "\\", [";"] = "|",
  }

  local function normalize_macro(macro)
    if macro == "" then return "" end

    local function lmap(c) return tr_to_en_macro[c] or c end

    -- Doğrudan insert moda giren tek karakterler (operatör sonrası değil)
    -- Not: s/S flash plugin arama olarak da kullanılıyor; insert state'de
    --      çevirme yapılmadığı için arama terimleri de korunur.
    local ENTERS_INSERT = { i=true, a=true, o=true, I=true, A=true, O=true, s=true, S=true, R=true }
    -- Motion bekleyen operatörler
    local OPERATORS     = { c=true, d=true, y=true, g=true, [">"]=true, ["<"]=true, ["="]=true }
    -- Motion sonrası insert moda giren operatörler (sadece c)
    local CHANGE_OPS    = { c=true }
    -- Sonrasındaki 1 karakteri ham bırakan komutlar (langmap arama modunda uygulanmaz)
    local CHAR_KEEP     = { f=true, F=true, t=true, T=true }

    local result = {}
    -- "normal" | "after_op" | "after_op_mod" | "insert" | "search" | "char_keep"
    local state = "normal"
    local pending_op = nil
    local pos = 1

    while pos <= #macro do
      local byte = macro:byte(pos)
      local len  = (byte < 0x80) and 1 or (byte < 0xE0) and 2 or (byte < 0xF0) and 3 or 4
      local char = macro:sub(pos, pos + len - 1)
      pos = pos + len

      if state == "insert" then
        table.insert(result, char)
        if byte == 0x1B or byte == 0x03 then  -- ESC veya Ctrl-C
          state = "normal"
        end

      elseif state == "search" then
        -- Arama terimi: langmap arama modunda uygulanmaz → çevirme yok
        table.insert(result, char)
        if byte == 0x0D or byte == 0x1B then  -- CR veya ESC → aramadan çık
          state = "normal"
        end

      elseif state == "char_keep" then
        -- f/F/t/T sonrası 1 literal karakter: olduğu gibi bırak
        table.insert(result, char)
        state = "normal"

      elseif state == "normal" then
        local t = lmap(char)
        table.insert(result, t)
        if     ENTERS_INSERT[t]     then state = "insert"
        elseif t == "/" or t == "?" then state = "search"
        elseif CHAR_KEEP[t]         then state = "char_keep"
        elseif OPERATORS[t]         then state = "after_op" ; pending_op = t
        end

      elseif state == "after_op" then
        local t = lmap(char)
        table.insert(result, t)
        if byte >= 0x31 and byte <= 0x39 then          -- rakam sayacı → bekle
        elseif t == "i" or t == "a"      then state = "after_op_mod"
        elseif t == pending_op           then          -- cc / dd / yy
          state = CHANGE_OPS[pending_op] and "insert" or "normal" ; pending_op = nil
        else                                           -- doğrudan motion: cw, d$…
          state = CHANGE_OPS[pending_op] and "insert" or "normal" ; pending_op = nil
        end

      elseif state == "after_op_mod" then
        -- text object karakteri: ciw'daki w
        local t = lmap(char)
        table.insert(result, t)
        state = CHANGE_OPS[pending_op] and "insert" or "normal"
        pending_op = nil
      end
    end

    return table.concat(result)
  end

  local pending = {}
  vim.api.nvim_create_autocmd("RecordingLeave", {
    group = vim.api.nvim_create_augroup("TurkishMacroRecording", { clear = true }),
    callback = function()
      local reg = vim.v.event.regname
      local macro = vim.v.event.regcontents
      local target = reg:lower()
      -- RecordingLeave register commit'inden önce çalışır. Append prefix'ini
      -- şimdi al; aynı input batch'inde önceki kayıt henüz normalize olmayabilir.
      local prefix = reg ~= target and vim.fn.getreg(target) or ""
      local normalized_prefix = prefix
      if pending[target] and pending[target].raw == prefix then
        normalized_prefix = pending[target].normalized
      end
      local entry = { raw = prefix .. macro, normalized = normalized_prefix .. normalize_macro(macro) }
      pending[target] = entry
      vim.schedule(function()
        -- Eski callback yeni kaydı veya sonradan değiştirilmiş register'ı ezmez.
        if pending[target] ~= entry then return end
        pending[target] = nil
        if vim.fn.getreg(target) == entry.raw then
          vim.fn.setreg(target, entry.normalized)
        end
      end)
    end,
  })
end

return M
