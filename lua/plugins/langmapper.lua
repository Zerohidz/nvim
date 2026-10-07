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
    --
    -- Makro fix: Türkçe layout'taki i . : , ; aynı zamanda gerçek Vim tuşları.
    -- Çevrilmiş mapping'ler (ör. which-key'nin ' trigger'ı → i) makro replay'inde
    -- register'daki gerçek i/./: tuşlarını yakalayıp E20 "Mark not set" vb.
    -- üretiyordu. Bu lhs'ler makro çalışırken ham (noremap) tuş olarak beslenir,
    -- normal kullanımda orijinal mapping'e yönlendirilir.
    local u = require("langmapper.utils")
    local ascii_collision = "[i%.:,;]"
    local map_for_layouts = u._map_for_layouts
    u._map_for_layouts = function(mode, lhs, rhs, opts, map_cb)
      return map_for_layouts(mode, lhs, rhs, opts, function(m, tr_lhs, r, o)
        if tr_lhs:find("<", 1, true) or not tr_lhs:find(ascii_collision) then
          return map_cb(m, tr_lhs, r, o)
        end
        local wrapped = vim.tbl_extend("force", o or {}, { expr = true, noremap = false, replace_keycodes = false })
        wrapped.callback = function()
          if vim.fn.reg_executing() ~= "" then
            vim.api.nvim_feedkeys(tr_lhs, "in", false)
            return ""
          end
          return vim.keycode(lhs)
        end
        return map_cb(m, tr_lhs, "", wrapped)
      end)
    end

    require("langmapper").setup({
      hack_keymap = true,           -- vim.keymap.set ve nvim_set_keymap'i wrap et
      disable_hack_modes = { "i", "c" }, -- Insert ve command-line modda çevirme (arama modunda Türkçe harf yazabilmek için)
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
