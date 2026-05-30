return {
  "seblyng/roslyn.nvim",
  ---@module 'roslyn.config'
  ---@type RoslynNvimConfig
  ft = { "cs", "razor" },
  opts = {
    -- your configuration comes here; leave empty for default settings
  },
  config = function(_, opts)
    require("roslyn").setup(opts)

    -- Override cmd: upstream removed --logLevel/--extensionLogDirectory args (6db5f66),
    -- but Roslyn 5.4.0+ requires them. Also adds fallback for mason binary named "roslyn"
    -- (Crashdummyy registry) in addition to "roslyn-language-server".
    vim.lsp.config("roslyn", {
      cmd = function(dispatchers, lsp_config)
        local mason = vim.fs.joinpath(vim.fn.stdpath("data"), "mason")
        local candidates = {
          vim.fs.joinpath(mason, "bin", "roslyn-language-server"),
          vim.fs.joinpath(mason, "bin", "roslyn"),
          "roslyn-language-server",
          "Microsoft.CodeAnalysis.LanguageServer",
        }
        local exe = "Microsoft.CodeAnalysis.LanguageServer"
        for _, candidate in ipairs(candidates) do
          if vim.fn.executable(candidate) == 1 then
            exe = candidate
            break
          end
        end

        local cmd = {
          exe,
          "--logLevel=Information",
          "--extensionLogDirectory=" .. vim.fs.dirname(vim.lsp.log.get_filename()),
          "--stdio",
        }

        return vim.lsp.rpc.start(cmd, dispatchers, {
          cwd = lsp_config.cmd_cwd,
          env = lsp_config.cmd_env,
          detached = lsp_config.detached,
        })
      end,
    })
  end,
}
