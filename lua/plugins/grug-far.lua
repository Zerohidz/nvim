return {
  "MagicDuck/grug-far.nvim",
  opts = {
    -- <leader>sr: default düz metin arama; regex için buffer'da <C-x>
    prefills = { flags = "--fixed-strings" },
  },
  init = function()
    vim.api.nvim_create_autocmd("FileType", {
      pattern = "grug-far",
      callback = function(args)
        vim.keymap.set({ "n", "i" }, "<C-x>", function()
          require("grug-far").get_instance(0):toggle_flags({ "--fixed-strings" })
        end, { buffer = args.buf, desc = "Toggle literal/regex search" })
      end,
    })
  end,
}
