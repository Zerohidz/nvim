return {
  {
    "mfussenegger/nvim-jdtls",
    opts = function(_, opts)
      -- Run JDTLS on Java 21 without changing the project's JAVA_HOME.
      vim.list_extend(opts.cmd, {
        "--java-executable",
        "/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home/bin/java",
      })
      if vim.fn.getcwd() == vim.fn.expand("~/dev/JavaPlayground") then
        opts.settings.java.configuration = {
          runtimes = {
            { name = "JavaSE-26", path = vim.fn.expand("~/.jenv/versions/26"), default = true },
          },
        }
      end
    end,
    init = function()
      vim.api.nvim_create_autocmd("LspAttach", {
        group = vim.api.nvim_create_augroup("JavaIntroduceParameter", { clear = true }),
        callback = function(args)
          local client = vim.lsp.get_client_by_id(args.data.client_id)
          if not client or client.name ~= "jdtls" then
            return
          end
          vim.keymap.set("x", "<leader>cxp", function()
            vim.lsp.buf.code_action({
              filter = function(action)
                return action.kind == "refactor.introduce.parameter"
              end,
              apply = true,
            })
          end, { buffer = args.buf, desc = "Introduce Parameter" })
        end,
      })
    end,
  },
}
