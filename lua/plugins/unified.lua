return {
  "axkirillov/unified.nvim",
  opts = {
    -- your configuration comes here
  },
  config = function(_, opts)
    require("unified").setup(opts)
    -- unified'ın kendi dosya ağacı her zaman en sola açılıyor (wincmd H sabit, ayarı yok).
    -- Açıldıktan sonra config/sidebar.lua'daki tarafa taşı.
    local file_tree = require("unified.file_tree")
    local show = file_tree.show
    file_tree.show = function(...)
      local result = show(...)
      local win = require("unified.file_tree.state").window
      if require("config.sidebar").position == "right" and win and vim.api.nvim_win_is_valid(win) then
        local width = vim.api.nvim_win_get_width(win)
        vim.fn.win_execute(win, "wincmd L")
        vim.api.nvim_win_set_width(win, width)
      end
      return result
    end
  end,
}
