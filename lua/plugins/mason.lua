return {
  "mason-org/mason.nvim",
  opts = {
    registries = {
      "github:mason-org/mason-registry",
      "github:Crashdummyy/mason-registry",
    },
    ensure_installed = {
      -- Python araçları
      "pyright", -- Language Server (LSP)
      "black",   -- Formatter (Kodu otomatik düzenler)
      "debugpy", -- Debugger (Hata ayıklama için)
      "ruff",    -- Linter (Hataları ve stil bozukluklarını gösterir, çok hızlıdır)     "lua-language-server",

      "xmlformatter",
      "csharpier",
      "prettier",
      "stylua",
      "bicep-lsp",
      "html-lsp",
      "css-lsp",
      "eslint-lsp",
      "typescript-language-server",
      "json-lsp",
      "rust-analyzer",

      -- !
      "roslyn",
      -- "csharp-language-server",
    },
  },
}
