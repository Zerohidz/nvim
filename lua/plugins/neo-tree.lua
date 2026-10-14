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
    -- Sadece neo-tree pencerelerinde geçerli (buffer-local), dışarıda hiçbir şeye dokunmaz.
    window = {
      mappings = {
        ["N"] = {
          function(state)
            local node = state and state.tree and state.tree:get_node()
            require("config.open_folder_session").open_node(node)
          end,
          desc = "Bu klasörde yeni Neovim oturumu (tmux/Neovide penceresi)",
        },
      },
    },
    filesystem = {
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
  },
}
