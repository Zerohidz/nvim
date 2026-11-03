return {
  "akinsho/toggleterm.nvim",
  version = "*",
  config = function()
    local function terminal_colors()
      local light = vim.o.background == "light"
      local normal = vim.api.nvim_get_hl(0, { name = "Normal", link = false })
      local background = normal.bg or (light and 0xffffff or 0x1e1e2e)
      local foreground = normal.fg or (light and 0x242424 or 0xcdd6f4)

      local function accent(groups, fallback)
        for _, group in ipairs(groups) do
          local color = vim.api.nvim_get_hl(0, { name = group, link = false }).fg
          if color then return color end
        end
        return fallback
      end

      local function tinted(color)
        local result = 0
        -- Tema vurgusunu açık temada %10, koyu temada %14 karıştırarak hafif bir ton ver.
        local strength = light and 0.10 or 0.14
        for _, shift in ipairs({ 16, 8, 0 }) do
          local base = math.floor(background / 2 ^ shift) % 256
          local tint = math.floor(color / 2 ^ shift) % 256
          result = result + math.floor(base * (1 - strength) + tint * strength + 0.5) * 2 ^ shift
        end
        return result
      end

      vim.api.nvim_set_hl(0, "Term1Color", {
        bg = tinted(accent({ "Function", "DiagnosticInfo" }, 0x7aa2f7)),
        fg = foreground,
      })
      vim.api.nvim_set_hl(0, "Term3Color", {
        bg = tinted(accent({ "Statement", "Special" }, 0xbb9af7)),
        fg = foreground,
      })
    end

    local function apply_terminal_colors(term)
      if (term.id == 1 or term.id == 3) and term.window and vim.api.nvim_win_is_valid(term.window) then
        local group = "Term" .. term.id .. "Color"
        vim.api.nvim_set_option_value("winhl", "Normal:" .. group .. ",NormalNC:" .. group, { win = term.window })
      end
    end

    terminal_colors()
    require("toggleterm").setup({
      direction = "horizontal",
      size = 40,
      shade_terminals = false,
      persist_size = true,
      auto_scroll = false,
      insert_mappings = false,
      terminal_mappings = false,

      -- Closing the terminal redistributes split heights; restore DB results afterwards.
      on_close = function()
        vim.schedule(function()
          require("config.database_results").restore_height()
        end)
      end,

      on_open = apply_terminal_colors,
    })

    -- ToggleTerm tema değişiminde winhl ayarını yeniledikten sonra özel tonları uygula.
    vim.api.nvim_create_autocmd("ColorScheme", {
      group = vim.api.nvim_create_augroup("ToggleTermColors", { clear = true }),
      callback = function()
        terminal_colors()
        for _, term in ipairs(require("toggleterm.terminal").get_all(true)) do
          apply_terminal_colors(term)
        end
      end,
    })
  end,
}
