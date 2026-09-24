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
        files = {
          hidden = true,
          ignored = false,
          exclude = { ".git/" },
        },
        projects = {
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
