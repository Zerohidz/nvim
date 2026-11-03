return {
  "MeanderingProgrammer/render-markdown.nvim",
  ft = { "markdown" },
  dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-tree/nvim-web-devicons" },
  opts = {
    -- Geniş tablolarda hücreleri pencereye sığacak şekilde satırlara böler ('wrap' açık olmalı)
    pipe_table = { wrap = true },
    win_options = {
      wrap = { default = vim.o.wrap, rendered = true },
    },
    -- obsidian.nvim UI'ındaki [~] ve [!] karşılıkları (varsayılanlar: [ ] [x] [-])
    checkbox = {
      custom = {
        inprogress = { raw = "[~]", rendered = "󰥔 ", highlight = "RenderMarkdownWarn" },
        important = { raw = "[!]", rendered = "󰀦 ", highlight = "RenderMarkdownError" },
      },
    },
  },
}
