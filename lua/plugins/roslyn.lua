return {
  "seblyng/roslyn.nvim",
  ---@module 'roslyn.config'
  ---@type RoslynNvimConfig
  -- Pinned: upstream 6db5f66 removed mason-legacy binary fallback and
  -- --logLevel/--extensionLogDirectory args. Roslyn 5.4.0+ requires both.
  -- Revert when upstream fixes: https://github.com/seblyng/roslyn.nvim
  commit = "49526a2",
  ft = { "cs", "razor" },
  opts = {
    -- your configuration comes here; leave empty for default settings
  },
}
