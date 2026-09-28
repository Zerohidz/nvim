-- IntelliJ'in kendi formatter'ıyla formatlanan projeler: sonuç IntelliJ Ctrl+Alt+L ile birebir aynı.
-- Listede olmayan projeler jdtls/prettier default'larıyla formatlanır. Anahtar: git kök dizininin adı (repo adı).
-- Kod stili IntelliJ'in seçtiği gibi bulunur (bkz. style_of): önce projenin .idea ayarı, yoksa IDE'de seçili şema.
local M = {}

M.projects = {
  -- MOS
  "mos-mgm-idari",
  "mos-mgm-butceodenek",
  -- Maliye
  "maliye-idariislemler",
  "maliye-idari-webclient",
  "maliye-butceodenekislemleri",
  "maliye-butceodenek-webclient",
  "maliye-varlikislemleri",
  "maliye-varlik-webclient",
  "maliye-degerlikagitislemleri",
  "maliye-degerlikagit-webclient",
  "maliye-ws",
  -- Sanal Pos (hmb-mgm-sanalpos-client prettier kullanıyor; nvim orada projenin prettier ayarını uygular)
  "hmb-mgm-sanalpos",
}

local selected = {}
for _, name in ipairs(M.projects) do
  selected[name] = true
end

local function jetbrains_dir()
  local dirs = vim.fn.glob(vim.fn.expand("~/Library/Application Support/JetBrains/") .. "IntelliJIdea*", false, true)
  table.sort(dirs)
  return dirs[#dirs]
end

local function read(path)
  return vim.fn.filereadable(path) == 1 and table.concat(vim.fn.readfile(path), "\n") or nil
end

-- IntelliJ'in global kod stili şeması (~/Library/.../codestyles/<ad>.xml)
local function global_scheme(name)
  local dir = jetbrains_dir()
  local path = dir and dir .. "/codestyles/" .. name .. ".xml"
  return path and vim.fn.filereadable(path) == 1 and path or nil
end

-- IntelliJ'in projeye uyguladığı kod stili dosyası:
--   .idea/codeStyles/codeStyleConfig.xml USE_PER_PROJECT_SETTINGS  -> .idea/codeStyles/Project.xml
--   PREFERRED_PROJECT_CODE_STYLE=<ad>                               -> global <ad> şeması
--   ayar yoksa                                                      -> IDE'de seçili şema (options/code.style.schemes.xml)
local function style_of(root)
  local config = read(root .. "/.idea/codeStyles/codeStyleConfig.xml") or ""
  if config:find("USE_PER_PROJECT_SETTINGS") then
    return root .. "/.idea/codeStyles/Project.xml"
  end
  local preferred = config:match('PREFERRED_PROJECT_CODE_STYLE" value="([^"]+)"')
  if preferred then
    return global_scheme(preferred)
  end
  local dir = jetbrains_dir()
  local schemes = dir and read(dir .. "/options/code.style.schemes.xml") or ""
  return global_scheme(schemes:match('CURRENT_SCHEME_NAME" value="([^"]+)"') or "Default")
end

---@param path string dosya ya da dizin
---@return {root: string, style: string}|nil
function M.get(path)
  local root = path ~= "" and vim.fs.root(path, ".git")
  if not root or not selected[vim.fs.basename(root)] then
    return nil
  end
  local style = style_of(root)
  if not style or vim.fn.filereadable(style) == 0 then
    return nil
  end
  return { root = root, style = style }
end

return M
