-- IntelliJ'in kendi formatter'ıyla (komut satırı `idea format`) formatlanan projeler: sonuç IntelliJ Ctrl+Alt+L ile birebir aynı.
-- Listede olmayan projeler jdtls/prettier default'larıyla formatlanır. Anahtar: git kök dizininin adı.
-- style(root): IntelliJ kod stili .xml dosyasının yolu
local M = {}

-- IntelliJ'in global kod stili şeması (Settings > Code Style'da seçilen), en yeni IntelliJ sürümünden
local function global_scheme(name)
  local paths = vim.fn.glob(vim.fn.expand("~/Library/Application Support/JetBrains/IntelliJIdea*/codestyles/") .. name .. ".xml", false, true)
  table.sort(paths)
  return paths[#paths]
end

M.projects = {
  -- .idea/codeStyles/codeStyleConfig.xml: PREFERRED_PROJECT_CODE_STYLE=Mert
  ["maliye-varlikislemleri"] = {
    style = function()
      return global_scheme("Mert")
    end,
  },
  -- .idea/codeStyles/codeStyleConfig.xml: USE_PER_PROJECT_SETTINGS (girinti .editorconfig'ten)
  ["maliye-varlik-webclient"] = {
    style = function(root)
      return root .. "/.idea/codeStyles/Project.xml"
    end,
  },
}

---@param path string dosya ya da dizin
---@return {root: string, style: string}|nil
function M.get(path)
  local root = path ~= "" and vim.fs.root(path, ".git")
  local project = root and M.projects[vim.fs.basename(root)]
  local style = project and project.style(root)
  if not style or vim.fn.filereadable(style) == 0 then
    return nil
  end
  return { root = root, style = style }
end

return M
