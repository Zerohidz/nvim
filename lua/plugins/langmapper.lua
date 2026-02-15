return {
  "Wansmer/langmapper.nvim",
  lazy = false,
  priority = 1, -- Her şeyden önce yüklensin, keymap.set'i wrap etsin
  config = function()
    -- default_layout: Bu fiziksel tuşlar İngilizce QWERTY'de ne üretiyor
    -- tr layout:      Aynı fiziksel tuşlar Türkçe Q'da ne üretiyor
    -- Her index aynı fiziksel tuşu temsil ediyor.
    --
    -- i → ı   ' → i   ; → ş   [ → ğ   ] → ü   , → ö   . → ç
    -- " → İ   : → Ş   { → Ğ   } → Ü   < → Ö   > → Ç
    -- / → .   ? → :   \ → ,   | → ;
    require("langmapper").setup({
      hack_keymap = true,           -- vim.keymap.set ve nvim_set_keymap'i wrap et
      disable_hack_modes = { "i" }, -- Insert modda çevirme
      map_all_ctrl = true,
      default_layout = [[i';[],.":{}<>/?\|]],
      use_layouts = { "tr" },
      layouts = {
        tr = {
          id = "tr",
          layout = [[ıişğüöçİŞĞÜÖÇ.:,;]],
        },
      },
    })
  end,
}
