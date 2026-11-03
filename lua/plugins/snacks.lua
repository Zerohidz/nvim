return {
  "folke/snacks.nvim",
  opts = {
    picker = {
      win = {
        input = {
          keys = {
            ["<C-l>"] = { "focus_preview", mode = { "i", "n" } },
            -- / aramasıyla tutarlı: düz metin <-> regex geçişi (default <a-r> de çalışır)
            ["<C-x>"] = { "toggle_regex", mode = { "i", "n" } },
          },
        },
        list = {
          keys = {
            ["<C-l>"] = "focus_preview",
            ["<C-h>"] = "focus_input",
          },
        },
        preview = {
          keys = {
            ["<C-h>"] = "focus_list",
          },
        },
      },
      sources = {
        -- <leader>sg: default düz metin (rg --fixed-strings), regex için <C-x>
        grep = { regex = false },
        -- unified.nvim'in snacks backend'i (:Unified -s) sidebar'ı "left" diye sabit açıyor;
        -- merge'den sonra çalışan config hook'uyla tarafı config/sidebar.lua'ya bağla.
        git_diff = {
          config = function(opts)
            if type(opts.layout) == "table" and type(opts.layout.layout) == "table" then
              opts.layout.layout.position = require("config.sidebar").position
            end
            return opts
          end,
        },
        files = {
          hidden = true,
          ignored = false,
          exclude = { ".git/" },
        },
        projects = {
          -- İç içe repo/worktree dizinlerini tara; derin kaynak ağaçlarında taramayı sınırla.
          dev = { "~/dev", "~/projects", "~/dev/.worktrees" },
          max_depth = 8,
          confirm = function(picker, item)
            require("snacks.picker.actions").load_session(picker, item)
            vim.schedule(function()
              for _, buf in ipairs(vim.api.nvim_list_bufs()) do
                if vim.bo[buf].filetype == "snacks_dashboard" then
                  pcall(vim.api.nvim_buf_delete, buf, { force = true })
                end
              end
            end)
          end,
        },
      },
    },
  },
}
