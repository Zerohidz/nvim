return {
  "akinsho/toggleterm.nvim",
  version = "*",
  config = function()
    -- 1. Terminal için özel bir arka plan rengi tanımlıyoruz (hex kodunu zevkine göre değiştirebilirsin)
    vim.api.nvim_set_hl(0, "Term1Color", { bg = "#222e26" })
    vim.api.nvim_set_hl(0, "Term3Color", { bg = "#1e1d2b" })
    require("toggleterm").setup({
      direction = "horizontal",
      size = 30,
      shade_terminals = false,
      persist_size = true,
      auto_scroll = false,
      insert_mappings = false,
      terminal_mappings = false,

      -- Terminal her açıldığında burası tetiklenir
      on_open = function(term)
        -- Eğer açılan terminal 1 numaralı (<C-t>) terminal ise:
        if term.id == 1 then
          -- Sadece o pencerenin (window) arka planını Term1Color yap
          vim.api.nvim_set_option_value("winhl", "Normal:Term1Color", { win = term.window })
        end
        if term.id == 3 then
          -- Sadece o pencerenin (window) arka planını Term3Color yap
          vim.api.nvim_set_option_value("winhl", "Normal:Term3Color", { win = term.window })
        end
      end,
    })
  end,
}
