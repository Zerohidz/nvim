-- lua/config/turkish_keys.lua
local M = {}

function M.setup()
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
end

return M
