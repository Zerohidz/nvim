-- lua/config/turkish_keys.lua
local M = {}

function M.setup()
  -- 1. Mevcut langmap ayarlarını temizle (Çatışmayı önlemek için)
  vim.opt.langmap = ""
  vim.opt.langremap = false

  -- 2. Dönüşüm Tablosu
  local tr_maps = {
    -- Küçük Harfler
    ["ı"] = "i",
    ["i"] = "'",
    ["ş"] = ";",
    ["ğ"] = "[",
    ["ü"] = "]",
    ["ö"] = ",",
    ["ç"] = ".",

    -- Büyük Harfler (Shift kombinasyonları)
    -- Not: Türkçe Q klavyede 'i' tuşuna Shift ile basınca 'İ' çıkar.
    ["İ"] = "\"",
    ["Ş"] = ":",
    ["Ğ"] = "{",
    ["Ü"] = "}",
    ["Ö"] = "<",
    ["Ç"] = ">",

    ["."] = "/",
    [":"] = "?",
    [","] = "\\",
    [";"] = "|",
  }

  -- 3. Uygulanacak Modlar
  -- Normal (n), Görsel (v, x), Operatör Bekleyen (o)
  local modes = { "n", "v", "x", "o" }

  -- 4. Döngüsel Haritalama
  for tr_key, en_key in pairs(tr_maps) do
    for _, mode in ipairs(modes) do
      -- Varsayılan olarak remap = true (Eklentiler için gerekli)
      local should_remap = true

      -- KONTROL: Eğer hedef tuş (en_key) tablomuzda bir 'kaynak' (key) ise,
      -- bu bir döngü yaratır (Örn: ı -> i -> ').

      if tr_maps[en_key] then should_remap = false end

      vim.keymap.set(mode, tr_key, en_key, {
        remap = should_remap, -- Dinamik olarak belirlenir
        silent = true,
        desc = "TR Layout Fix: " .. tr_key .. " -> " .. en_key
      })
    end
  end
end

return M
