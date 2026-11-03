-- neo-tree'de N: imlecin olduğu klasörde BAĞIMSIZ yeni bir Neovim oturumu açar.
-- Neovide: yeni GUI; tmux: yeni tmux penceresi; terminal: yeni Kitty penceresi.
-- Argüman üretimi test edilebilir olsun diye saf (M.plan); spawn ayrı (M.open).
-- Spec: docs/specs/neo-tree-terminal-and-cd.md
local M = {}

-- Yeni oturum, cwd'si hedef klasör olarak neo-tree ile açılır. Tek argv elemanı:
-- nvim "+{cmd}" biçiminde tek argümandan fazla komutu kendi split'lemiyor.
M.nvim_command = "+Neotree focus"

-- tmux shell-command'a giden sabit string. YOL bu string'e asla girmez (tırnak/boşluk
-- riski olmasın diye hedef klasör tmux'a -c argv'si ile geçiliyor).
M.tmux_shell_command = "nvim '+Neotree focus'"

---@param path string mutlak klasör yolu
---@param env table? ortam değişkenleri (test için; default vim.env)
---@param is_neovide boolean? test için GUI tespiti
---@return { kind: string, cmd: string[] }
function M.plan(path, env, is_neovide)
  env = env or vim.env
  if is_neovide == nil then
    is_neovide = vim.g.neovide and vim.g.neovide ~= 0
  end
  if is_neovide then
    return { kind = "neovide", cmd = { "neovide", "--chdir", path, "--", M.nvim_command } }
  end
  local in_tmux = type(env.TMUX) == "string" and env.TMUX ~= ""
  if in_tmux then
    local cmd = { "tmux", "new-window", "-c", path }
    local name = vim.fn.fnamemodify(path, ":t")
    -- "/" gibi kök yollarda ":t" boş döner: -n hiç verme (tmux boş isim kabul etmez).
    if name ~= "" then
      table.insert(cmd, "-n")
      table.insert(cmd, name)
    end
    table.insert(cmd, M.tmux_shell_command)
    return { kind = "tmux", cmd = cmd }
  end
  -- Kitty macOS: ayrı uygulama örneği, shell kullanmadan bağımsız terminal.
  return {
    kind = "kitty",
    cmd = { "open", "-na", "kitty", "--args", "--directory", path, vim.fn.exepath("nvim"), M.nvim_command },
  }
end

--- Yolun gerçek bir klasör olup olmadığını doğrular; olmazsa nil + sebep.
--- Not: ":p" dizinlere sonuna "/" ekliyor; tmux/neovide'a temiz yol vermek için kırpılır.
---@param path any
---@return string? absolute_path
---@return string? error
function M.resolve(path)
  if type(path) ~= "string" or path == "" then
    return nil, "Klasör yolu belirlenemedi"
  end
  local absolute = vim.fn.fnamemodify(path, ":p"):gsub("/+$", "")
  if absolute == "" then
    absolute = "/"
  end
  if vim.fn.isdirectory(absolute) ~= 1 then
    return nil, "Dizin değil ya da silinmiş: " .. absolute
  end
  return absolute
end

--- neo-tree node'unu klasöre çevirir: dosyada ise parent'ı kullanılır (ölü uç bırakma).
---@param node neotree.Node?
---@return string? path
---@return string? error
function M.node_folder(node)
  if not node then
    return nil, "Neo-tree node bulunamadı"
  end
  local path = (node.get_path and node:get_path()) or node.path
  if type(path) ~= "string" or path == "" then
    return nil, "Node yolu okunamadı"
  end
  if node.type ~= "directory" then
    path = vim.fn.fnamemodify(path, ":h")
  end
  return M.resolve(path)
end

--- Hedef klasörde yeni oturum başlatır. Hata olursa sessiz kalmaz.
---@param path any mutlak klasör yolu (dosya verilirse parent'ı kullanılmaz; open_node kullan)
---@param env table? ortam değişkenleri (test için; default vim.env)
---@return boolean ok
function M.open(path, env, is_neovide)
  local absolute, err = M.resolve(path)
  if not absolute then
    vim.notify("Yeni oturum açılamadı: " .. err, vim.log.levels.ERROR)
    return false
  end
  local planned = M.plan(absolute, env, is_neovide)
  local dependencies = planned.kind == "kitty" and { "open", "kitty", "nvim" } or { planned.cmd[1] }
  for _, binary in ipairs(dependencies) do
    if vim.fn.executable(binary) ~= 1 then
      vim.notify("Yeni oturum açılamadı: '" .. binary .. "' bulunamadı (PATH?)", vim.log.levels.ERROR)
      return false
    end
  end
  local label = ({ tmux = "tmux", kitty = "Kitty", neovide = "Neovide" })[planned.kind]
  local function report(detail)
    vim.notify("Yeni " .. label .. " penceresi açılamadı: " .. detail, vim.log.levels.ERROR)
  end
  -- open ve tmux kısa ömürlü launcher'lardır; başarısız çıkışları da yakalanır.
  local options = { detach = true }
  local on_exit
  if planned.kind == "neovide" then
    options.stdio = { "ignore", "ignore", "ignore" }
  else
    on_exit = function(result)
      if result.code ~= 0 then
        local detail = (result.stderr or ""):gsub("%s+$", "")
        if detail == "" then
          detail = label .. " çıkış kodu " .. tostring(result.code)
        end
        vim.schedule(function()
          report(detail)
        end)
      end
    end
  end
  local ok, spawn_err = pcall(vim.system, planned.cmd, options, on_exit)
  if not ok then
    report(tostring(spawn_err))
    return false
  end
  vim.notify("Yeni oturum (" .. label .. " penceresi): " .. absolute)
  return true
end

--- Mevcut oturumun çalışma dizinini ve Neo-tree kökünü seçilen klasöre taşır.
function M.cd_node(node)
  local folder, err = M.node_folder(node)
  if not folder then
    vim.notify("Klasöre geçilemedi: " .. err, vim.log.levels.ERROR)
    return false
  end
  local ok, change_err = pcall(function()
    vim.api.nvim_set_current_dir(folder)
    require("neo-tree.command").execute({ source = "filesystem", action = "focus", dir = folder })
  end)
  if not ok then
    vim.notify("Klasöre geçilemedi: " .. tostring(change_err), vim.log.levels.ERROR)
    return false
  end
  return true
end

--- neo-tree mapping girişi: node klasörse kendisi, dosyaysa parent'ı.
---@param node neotree.Node?
function M.open_node(node)
  local folder, err = M.node_folder(node)
  if not folder then
    vim.notify("Yeni oturum açılamadı: " .. err, vim.log.levels.ERROR)
    return
  end
  M.open(folder)
end

return M
