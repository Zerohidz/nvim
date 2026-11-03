return {
  "nvim-neo-tree/neo-tree.nvim",
  -- Tuş kombinasyonunu eziyoruz
  keys = {
    {
      "<leader>e",
      function()
        -- LazyVim'in root tespitini bypass edip direkt Neovim'in o anki dizininde (cwd) açar
        require("neo-tree.command").execute({ toggle = true, dir = vim.uv.cwd() })
      end,
      desc = "Explorer Neo-tree (cwd ile aç)",
    },
  },
  opts = {
    event_handlers = {
      {
        event = "vim_dir_changed",
        handler = function()
          require("neo-tree.sources.manager").dir_changed("git_status")
        end,
      },
    },
    -- Sadece neo-tree pencerelerinde geçerli (buffer-local), dışarıda hiçbir şeye dokunmaz.
    window = {
      position = require("config.sidebar").position,
      mappings = {
        ["<esc>"] = {
          function(state)
            vim.v.hlsearch = 0
            require("neo-tree.sources.common.commands").cancel(state)
          end,
          desc = "Arama vurgusunu temizle / iptal et",
        },
        ["gP"] = {
          function(state)
            local ok, err = pcall(function()
              vim.cmd.cd(vim.fn.fnamemodify(state.path or vim.fn.getcwd(), ":h"))
              require("neo-tree.command").execute({ source = "filesystem", action = "focus", dir = vim.fn.getcwd() })
            end)
            if not ok then
              vim.notify("Üst klasöre geçilemedi: " .. tostring(err), vim.log.levels.ERROR)
            end
          end,
          desc = "Üst klasöre geç (cwd ve Neo-tree kökü)",
        },
        ["gN"] = {
          function(state)
            local node = state and state.tree and state.tree:get_node()
            require("config.open_folder_session").cd_node(node)
          end,
          desc = "Bu klasöre geç (cwd ve Neo-tree kökü)",
        },
        ["N"] = {
          function(state)
            local node = state and state.tree and state.tree:get_node()
            require("config.open_folder_session").open_node(node)
          end,
          desc = "Bu klasörde yeni Neovim oturumu (Neovide/tmux/Kitty penceresi)",
        },
      },
    },
    filesystem = {
      window = {
        mappings = {
          -- Türkçe düzende . → /: global normal arama eşlemesini kullan.
          ["/"] = "none",
        },
      },
      filtered_items = {
        visible = false,
        hide_dotfiles = false,
        hide_gitignored = false,
        never_show = {
          ".git",
          ".DS_Store",
          "thumbs.db",
        },
      },
    },
    git_status = {
      window = {
        mappings = {
          ["/"] = "none",
        },
      },
    },
  },
}
