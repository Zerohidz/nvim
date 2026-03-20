return {
  {
    name = "simple-focus",
    dir = vim.fn.stdpath("config"),
    lazy = false,
    priority = 1000,
    config = function()
      vim.cmd.colorscheme("simple-focus")
    end,
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "simple-focus",
    },
  },
}
