return {
  "akinsho/toggleterm.nvim",
  version = "*",
  config = function()
    require("toggleterm").setup({
      open_mapping = [[<C-t>]], -- Ctrl + T
      direction = "horizontal", -- veya "horizontal", "vertical"
      shade_terminals = true,
      insert_mappings = true,
      terminal_mappings = true,
    })
  end,
}
