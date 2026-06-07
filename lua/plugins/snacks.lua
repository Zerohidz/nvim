return {
  "folke/snacks.nvim",
  opts = {
    picker = {
      win = {
        input = {
          keys = {
            ["<C-l>"] = { "focus_preview", mode = { "i", "n" } },
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
