-- Database browsing and schema-aware SQL completion inside Neovim.
local sql_ft = { "sql", "mysql", "plsql" }
local function is_sql()
  return vim.tbl_contains(sql_ft, vim.bo.filetype)
end

return {
  { "tpope/vim-dadbod", cmd = "DB" },
  {
    "kristijanhusak/vim-dadbod-ui",
    dependencies = { "tpope/vim-dadbod" },
    cmd = { "DBUI", "DBUIToggle", "DBUIAddConnection", "DBUIFindBuffer" },
    keys = {
      { "<leader>vv", "<cmd>DBUIToggle<cr>", desc = "Veritabanı paneli" },
      { "<leader>va", "<cmd>DBUIAddConnection<cr>", desc = "Veritabanı bağlantısı ekle" },
    },
    init = function()
      require("config.database_help").setup()
      require("config.database_results").setup()
      require("config.database_colors").setup()
      local data = vim.fn.stdpath("data") .. "/dadbod_ui"
      vim.g.db_ui_save_location = data
      vim.g.db_ui_tmp_query_location = data .. "/tmp"
      vim.g.db_ui_use_nerd_fonts = 1
      vim.g.db_ui_show_database_icon = 1
      vim.g.db_ui_execute_on_save = 0 -- Run explicitly with <leader>vr.
      vim.g.db_ui_auto_execute_table_helpers = 0
      -- Dadbod's default S/E shadow Scratch and Neo-tree in query buffers.
      vim.g.db_ui_disable_mappings_sql = 1
      vim.g.db_ui_disable_mappings_javascript = 1
      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("DatabaseKeymaps", { clear = true }),
        pattern = { "sql", "mysql", "plsql", "dbout" },
        callback = function(event)
          local function map(modes, key, target, desc)
            vim.keymap.set(modes, "<leader>v" .. key, "<Plug>(DBUI_" .. target .. ")",
              { buffer = event.buf, remap = true, silent = true, desc = desc })
          end
          if vim.bo[event.buf].filetype == "dbout" then
            for _, direction in ipairs({ "h", "l" }) do
              local side = direction
              vim.keymap.set("n", "<C-" .. side .. ">", function()
                require("config.database_results").navigate_or_scroll(side)
              end, { buffer = event.buf, silent = true,
                desc = side == "h" and "Sol pencere / yarım ekran sola" or "Sağ pencere / yarım ekran sağa" })
            end
            vim.keymap.set("n", "<leader>vl", require("config.database_results").toggle,
              { buffer = event.buf, silent = true, desc = "Database result layout (keep record)" })
            vim.keymap.set("n", "<leader>R", require("config.database_results").toggle,
              { buffer = event.buf, silent = true, desc = "Database result layout (keep record)" })
          else
            map({ "n", "x" }, "r", "ExecuteQuery", "Run database query")
            map("n", "w", "SaveQuery", "Save database query")
            map("n", "e", "EditBindParameters", "Database bind parameters")
          end
        end,
      })
    end,
  },
  {
    "kristijanhusak/vim-dadbod-completion",
    dependencies = { "tpope/vim-dadbod" },
    ft = sql_ft,
    init = function()
      vim.g.omni_sql_default_compl_type = "syntax"
      vim.g.loaded_sql_completion = true
    end,
  },
  {
    "saghen/blink.cmp",
    dependencies = { "kristijanhusak/vim-dadbod-completion" },
    opts = function(_, opts)
      opts.sources.providers.dadbod = {
        name = "Dadbod",
        module = "vim_dadbod_completion.blink",
      }
      opts.sources.per_filetype = opts.sources.per_filetype or {}
      for _, ft in ipairs(sql_ft) do
        opts.sources.per_filetype[ft] = { "dadbod", "snippets", "buffer" }
      end

      -- Keep LazyVim's snippet/AI Tab behavior outside SQL buffers.
      opts.keymap["<Tab>"] = {
        function(cmp)
          if not is_sql() then return end
          local col = vim.api.nvim_win_get_cursor(0)[2]
          local before = vim.api.nvim_get_current_line():sub(1, col)
          if not cmp.is_visible() and before:match("^%s*$") then return end
          return cmp.select_next() or cmp.show()
        end,
        LazyVim.cmp.map({ "snippet_forward", "ai_nes", "ai_accept" }),
        "fallback",
      }
      opts.keymap["<S-Tab>"] = {
        function(cmp)
          if is_sql() then return cmp.select_prev() end
        end,
        "snippet_backward",
        "fallback",
      }
    end,
  },
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "sql" } },
  },
}
