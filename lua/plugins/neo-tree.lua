return {
  "nvim-neo-tree/neo-tree.nvim",
  opts = {
    filesystem = {
      filtered_items = {
        visible = false,         -- Gizli öğeleri varsayılan olarak gösterme (H ile açılır)
        hide_dotfiles = false,   -- Nokta ile başlayanları gizle
        hide_gitignored = false, -- .gitignore içindekileri (input/output) GÖSTER
        never_show = {           -- Bunları hiçbir zaman görme
          ".git",
          ".DS_Store",
          "thumbs.db",
        },
      },
    },
  },
}
