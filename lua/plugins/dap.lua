-- Debug (LazyVim dap.core extra'sının üstüne).
-- * Tuşlar <leader>d yerine <leader>D altında: <leader>d init.lua'da "panoya kes" ("+d) operatörü.
-- * Yan panel tarafı config/sidebar.lua'dan gelir.
-- * Adaptörler Mason'dan; bash/python/php/codelldb'yi mason-nvim-dap kendisi bağlıyor,
--   C#, JS/TS ve Godot burada. Java (jdtls) ve Rust (rustaceanvim) LazyVim lang extra'larında.

--- dap.core'un <leader>d... tuşlarını <leader>D... altına taşır.
local function move_to_D(_, keys)
  for _, key in ipairs(keys) do
    if type(key) == "table" and type(key[1]) == "string" then
      key[1] = key[1]:gsub("^<leader>d", "<leader>D")
    end
  end
  return keys
end

--- Seçilen .csproj'u Debug'da derler, çıktı dll'inin yolunu döner.
local function build_csproj(csproj)
  vim.notify("dotnet build: " .. vim.fn.fnamemodify(csproj, ":t"))
  local build = vim.system({ "dotnet", "build", csproj, "-c", "Debug", "-nologo", "-v", "q" }, { text = true }):wait()
  if build.code ~= 0 then
    vim.notify("dotnet build başarısız:\n" .. (build.stdout or "") .. (build.stderr or ""), vim.log.levels.ERROR)
    return nil
  end
  local prop = vim.system({ "dotnet", "msbuild", csproj, "-getProperty:TargetPath", "-p:Configuration=Debug" }, { text = true }):wait()
  local dll = vim.trim(prop.stdout or "")
  if dll == "" then
    vim.notify("TargetPath bulunamadı: " .. csproj, vim.log.levels.ERROR)
    return nil
  end
  return dll
end

--- cwd altındaki .csproj'lardan birini seçtirip derler (tek proje varsa sormaz).
local function pick_and_build_dll()
  local projects = vim.fs.find(function(name) return name:match("%.csproj$") end, {
    path = vim.fn.getcwd(),
    type = "file",
    limit = math.huge,
  })
  projects = vim.tbl_filter(function(p) return not p:match("/obj/") and not p:match("/bin/") end, projects)
  if #projects == 0 then
    vim.notify("Bu klasörde .csproj yok", vim.log.levels.ERROR)
    return require("dap").ABORT
  end
  if #projects == 1 then
    return build_csproj(projects[1]) or require("dap").ABORT
  end
  return coroutine.create(function(co)
    vim.ui.select(projects, {
      prompt = "Hangi proje?",
      format_item = function(p) return vim.fn.fnamemodify(p, ":~:.") end,
    }, function(choice)
      coroutine.resume(co, choice and build_csproj(choice) or require("dap").ABORT)
    end)
  end)
end

return {
  {
    "mfussenegger/nvim-dap",
    keys = move_to_D,
    opts = function()
      local dap = require("dap")

      -- C# (netcoredbg)
      dap.adapters.coreclr = {
        type = "executable",
        command = vim.fn.exepath("netcoredbg"),
        args = { "--interpreter=vscode" },
      }
      dap.configurations.cs = {
        {
          type = "coreclr",
          name = "Derle ve başlat (.csproj)",
          request = "launch",
          program = pick_and_build_dll,
          cwd = "${workspaceFolder}",
          stopAtEntry = false,
          console = "integratedTerminal",
        },
        {
          type = "coreclr",
          name = "Çalışan sürece bağlan",
          request = "attach",
          processId = function() return require("dap.utils").pick_process({ filter = "dotnet" }) end,
        },
      }

      -- JS / TS (js-debug-adapter). Node 22.18+ TS'i kendisi çalıştırıyor (type stripping), tsx gerekmez.
      for _, kind in ipairs({ "node", "chrome" }) do
        dap.adapters["pwa-" .. kind] = {
          type = "server",
          host = "localhost",
          port = "${port}",
          executable = { command = "js-debug-adapter", args = { "${port}" } },
        }
        -- launch.json'lardaki "node"/"chrome" tipleri için
        dap.adapters[kind] = function(cb, config)
          config.type = "pwa-" .. kind
          cb(dap.adapters["pwa-" .. kind])
        end
      end
      local js_filetypes = { "typescript", "javascript", "typescriptreact", "javascriptreact" }
      local vscode = require("dap.ext.vscode")
      for _, t in ipairs({ "node", "pwa-node", "chrome", "pwa-chrome" }) do
        vscode.type_to_filetypes[t] = js_filetypes
      end
      for _, ft in ipairs(js_filetypes) do
        dap.configurations[ft] = {
          {
            type = "pwa-node",
            request = "launch",
            name = "Bu dosyayı node ile çalıştır",
            program = "${file}",
            cwd = "${workspaceFolder}",
            sourceMaps = true,
          },
          {
            type = "pwa-node",
            request = "attach",
            name = "Node sürecine bağlan (--inspect)",
            processId = require("dap.utils").pick_process,
            cwd = "${workspaceFolder}",
            sourceMaps = true,
          },
          {
            -- Frontend: dev server (vite/ng serve) önce çalışıyor olmalı.
            type = "pwa-chrome",
            request = "launch",
            name = "Chromium'da aç (dev server)",
            url = function()
              local url = vim.fn.input("URL: ", "http://localhost:5173")
              return url ~= "" and url or require("dap").ABORT
            end,
            webRoot = "${workspaceFolder}",
            runtimeExecutable = vim.fn.exepath("chromium"),
            sourceMaps = true,
            userDataDir = false,
          },
        }
      end

      -- Godot (GDScript): editör açıkken kendi debug sunucusunu 6006'da açar.
      dap.adapters.godot = { type = "server", host = "127.0.0.1", port = 6006 }
      dap.configurations.gdscript = {
        { type = "godot", request = "launch", name = "Godot: projeyi başlat", project = "${workspaceFolder}" },
      }
    end,
  },
  {
    "jay-babu/mason-nvim-dap.nvim",
    opts = function(_, opts)
      -- kotlin extra'sı adaptörünü otomatik kurduruyor; ~/dev'de Kotlin projesi yok.
      opts.ensure_installed = vim.tbl_filter(function(name) return name ~= "kotlin" end, opts.ensure_installed or {})
      opts.automatic_installation = { exclude = { "kotlin" } }
      opts.handlers = {
        -- Varsayılan handler: mason'da kurulu adaptörü bağlar (bash, python, php, ...).
        function(config) require("mason-nvim-dap").default_setup(config) end,
        -- Yukarıda kendimiz tanımladık; mason-nvim-dap ikinci bir kopya eklemesin.
        coreclr = function() end,
        js = function() end,
        -- C/C++ clangd extra'sında, Rust rustaceanvim'de; çift "Launch file" çıkmasın.
        codelldb = function() end,
        javadbg = function() end,
        javatest = function() end,
      }
    end,
  },
  {
    "rcarriga/nvim-dap-ui",
    keys = move_to_D,
    opts = {
      layouts = {
        {
          elements = {
            { id = "scopes", size = 0.25 },
            { id = "breakpoints", size = 0.25 },
            { id = "stacks", size = 0.25 },
            { id = "watches", size = 0.25 },
          },
          size = 40,
          position = require("config.sidebar").position,
        },
        {
          elements = { "repl", "console" },
          size = 10,
          position = "bottom",
        },
      },
    },
  },
  {
    "folke/which-key.nvim",
    opts = {
      spec = {
        { "<leader>D", group = "debug", icon = { icon = " ", color = "red" } },
        { "<leader>d", group = "panoya kes / profiler" },
      },
    },
  },
}
