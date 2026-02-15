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
end

return M
