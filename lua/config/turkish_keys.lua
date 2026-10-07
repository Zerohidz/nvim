-- lua/config/turkish_keys.lua
local M = {}

-- langmapper setup'ından önce seçenekleri hazırla; keymap/hook'lar sonra kurulur.
function M.setup_langmap()
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
  for _, pair in ipairs(tr_to_en) do
    -- Tek karakter: op-pending ve visual'da her bağlamda çalışır (hızlı yazma fix)
    vim.keymap.set({ "x", "o" }, pair[1], pair[2], { remap = true, silent = true })
    -- iX / aX: belt and suspenders
    vim.keymap.set({ "x", "o" }, "i" .. pair[1], "i" .. pair[2], { remap = true, silent = true })
    vim.keymap.set({ "x", "o" }, "a" .. pair[1], "a" .. pair[2], { remap = true, silent = true })
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
