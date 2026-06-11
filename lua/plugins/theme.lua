local theme_mode = require("config.theme-mode")

return {
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = theme_mode.resolve(),
    },
  },
}
