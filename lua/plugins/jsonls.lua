return {
  "neovim/nvim-lspconfig",
  opts = {
    servers = {
      jsonls = {
        -- git repo yoksa dosyanın kendi dizinini root say (eski single_file_support davranışı)
        root_dir = function(bufnr, on_dir)
          local fname = vim.api.nvim_buf_get_name(bufnr)
          on_dir(vim.fs.root(fname, ".git") or vim.fs.dirname(fname))
        end,
      },
    },
  },
}
