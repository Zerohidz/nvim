local idea = "/Applications/IntelliJ IDEA.app/Contents/MacOS/idea"

return {
  "stevearc/conform.nvim",
  opts = function(_, opts)
    opts.formatters_by_ft = opts.formatters_by_ft or {}
    opts.formatters_by_ft.xml = { "xmlformatter" }

    opts.formatters = opts.formatters or {}
    -- 4 boşluk; attribute sırası/<x/> korunur (default'u sıralıyor ve açıyor); attribute ve metin kırılmaz,
    -- boş satırlar silinir (--blanks verilmez)
    opts.formatters.xmlformatter = {
      prepend_args = { "--indent", "4", "--preserve-attributes", "--selfclose", "--eof-newline" },
    }

    -- Seçili projeler (config/format_projects.lua) IntelliJ'in kendi formatter'ıyla, projenin kod stiliyle formatlanır.
    -- conform geçici kopyayı dosyanın yanına yazar; .editorconfig de uygulanır. bin/idea-format önce açık IDE'deki
    -- plugin'i (intellij-plugin/, hızlı) dener, yoksa `idea format` komut satırına düşer.
    opts.formatters.intellij = {
      command = vim.fn.stdpath("config") .. "/bin/idea-format",
      args = function(_, ctx)
        return { require("config.format_projects").get(ctx.filename).style, "$FILENAME" }
      end,
      stdin = false,
      condition = function(_, ctx)
        return vim.fn.executable(idea) == 1 and require("config.format_projects").get(ctx.filename) ~= nil
      end,
    }

    -- Seçili projede IntelliJ, diğerlerinde mevcut formatter'lar (Java: jdtls, JS: prettier)
    for _, ft in ipairs({ "java", "javascript", "javascriptreact" }) do
      local default = opts.formatters_by_ft[ft] or {}
      opts.formatters_by_ft[ft] = function(bufnr)
        if require("config.format_projects").get(vim.api.nvim_buf_get_name(bufnr)) then
          return { "intellij", lsp_format = "never", timeout_ms = 20000 }
        end
        return default
      end
    end
  end,
}
