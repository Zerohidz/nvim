-- neo-tree'de N: imlecin olduğu klasörde BAĞIMSIZ yeni bir Neovim oturumu açar.
-- tmux içindeysek yeni tmux penceresi (terminal nvim), değilsek yeni Neovide penceresi.
-- Argüman üretimi test edilebilir olsun diye saf (M.plan); spawn ayrı (M.open).
-- Spec: docs/specs/neo-tree-open-folder-session.md
local M = {}

-- Yeni oturum, cwd'si hedef klasör olarak neo-tree ile açılır. Tek argv elemanı:
-- nvim "+{cmd}" biçiminde tek argümandan fazla komutu kendi split'lemiyor.
M.nvim_command = "+Neotree focus"

-- tmux shell-command'a giden sabit string. YOL bu string'e asla girmez (tırnak/boşluk
-- riski olmasın diye hedef klasör tmux'a -c argv'si ile geçiliyor).
M.tmux_shell_command = "nvim '+Neotree focus'"

---@param path string mutlak klasör yolu
---@param env table? ortam değişkenleri (test için; default vim.env)
---@return { kind: "tmux" | "neovide", cmd: string[] }
function M.plan(path, env)
  env = env or vim.env
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
  -- Neovide 0.16'da --working-dir YOK, doğru bayrak --chdir. "--" sonrası nvim'e
  -- yorumlanmadan geçen argümanlar. --reuse-instance verilmez → yeni process = ayrı oturum.
  return { kind = "neovide", cmd = { "neovide", "--chdir", path, "--", M.nvim_command } }
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
function M.open(path, env)
  local absolute, err = M.resolve(path)
  if not absolute then
    vim.notify("Yeni oturum açılamadı: " .. err, vim.log.levels.ERROR)
    return false
  end
  local planned = M.plan(absolute, env)
  if vim.fn.executable(planned.cmd[1]) ~= 1 then
    vim.notify("Yeni oturum açılamadı: '" .. planned.cmd[1] .. "' bulunamadı (PATH?)", vim.log.levels.ERROR)
    return false
  end

  if planned.kind == "tmux" then
    -- tmux hızlı çıkar; stderr'i yakalayıp kullanıcıya gösterebiliyoruz.
    local ok, handle = pcall(vim.system, planned.cmd, { detach = true }, function(result)
      if result.code ~= 0 then
        local detail = (result.stderr or ""):gsub("%s+$", "")
        if detail == "" then
          detail = "tmux çıkış kodu " .. tostring(result.code)
        end
        vim.notify("Yeni tmux penceresi açılamadı: " .. detail, vim.log.levels.ERROR)
      end
    end)
    if not ok then
      vim.notify("Yeni tmux penceresi açılamadı: " .. tostring(handle), vim.log.levels.ERROR)
      return false
    end
    vim.notify("Yeni oturum (tmux penceresi): " .. absolute)
    return true
  end

  -- GUI dalı: stdout/stderr pipe'ı ölü babaya bağlı kalmasın diye hepsi ignore;
  -- spawn hatası (ENOENT) burada senkron yakalanır.
  local ok, spawn_err = pcall(vim.system, planned.cmd, {
    detach = true,
    stdio = { "ignore", "ignore", "ignore" },
  })
  if not ok then
    vim.notify("Yeni Neovide penceresi açılamadı: " .. tostring(spawn_err), vim.log.levels.ERROR)
    return false
  end
  vim.notify("Yeni oturum (Neovide penceresi): " .. absolute)
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
