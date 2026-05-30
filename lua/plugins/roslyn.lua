return {
  "seblyng/roslyn.nvim",
  ---@module 'roslyn.config'
  ---@type RoslynNvimConfig
  -- pinned: 49526a2 has mason-legacy binary fallback, removed in 6db5f66
  -- see: https://github.com/seblyng/roslyn.nvim/issues
  commit = "49526a2",
  ft = { "cs", "razor" },
  opts = {
    -- your configuration comes here; leave empty for default settings
  },
}
