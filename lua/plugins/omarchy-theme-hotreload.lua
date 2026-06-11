return {
	{
		name = "theme-hotreload",
		dir = vim.fn.stdpath("config"),
		lazy = false,
		priority = 1000,
		config = function()
			local theme_mode = require("config.theme-mode")
			local transparency_file = vim.fn.stdpath("config") .. "/plugin/after/transparency.lua"

			local function apply_theme()
				-- Re-resolve the colorscheme from the current theme mode
				package.loaded["plugins.theme"] = nil
				local ok, theme_spec = pcall(require, "plugins.theme")
				if not ok then
					return
				end

				-- Clear all highlight groups before applying new theme
				vim.cmd("highlight clear")
				if vim.fn.exists("syntax_on") == 1 then
					vim.cmd("syntax reset")
				end

				-- Reset background to default so colorscheme can set it properly (light themes will set to light)
				vim.o.background = "dark"

				-- Find and apply the new colorscheme
				for _, spec in ipairs(theme_spec) do
					if spec[1] == "LazyVim/LazyVim" and spec.opts and spec.opts.colorscheme then
						local colorscheme = spec.opts.colorscheme

						-- Load the colorscheme plugin
						require("lazy.core.loader").colorscheme(colorscheme)

						vim.defer_fn(function()
							-- Apply the colorscheme (it will set background itself)
							local applied_ok, err = pcall(vim.cmd.colorscheme, colorscheme)
							if not applied_ok then
								vim.notify(
									("Colorscheme '%s' uygulanamadı (plugin kurulu değil?)\n%s"):format(colorscheme, err),
									vim.log.levels.ERROR
								)
							end

							-- Force redraw to update all UI elements
							vim.cmd("redraw!")

							-- Reload transparency settings
							if vim.fn.filereadable(transparency_file) == 1 then
								vim.defer_fn(function()
									vim.cmd.source(transparency_file)

									-- Trigger UI updates for various plugins
									vim.api.nvim_exec_autocmds("ColorScheme", { modeline = false })
									vim.api.nvim_exec_autocmds("VimEnter", { modeline = false })

									-- Final redraw
									vim.cmd("redraw!")
								end, 5)
							end
						end, 5)

						break
					end
				end
			end

			-- Reapply when Omarchy/Lazy signal a reload (e.g. omarchy theme switch)
			vim.api.nvim_create_autocmd("User", {
				pattern = "LazyReload",
				callback = function()
					vim.schedule(apply_theme)
				end,
			})

			-- Manual theme mode switcher: omarchy sync, simple-focus, or any
			-- colorscheme from omarchy's theme directories (scanned live, so
			-- new themes added by omarchy updates show up automatically)
			local function theme_choices()
				local choices = { "omarchy", "simple-focus" }
				local seen = { omarchy = true, ["simple-focus"] = true }

				for _, spec in ipairs(require("config.omarchy-themes").theme_specs()) do
					for _, s in ipairs(spec) do
						if s[1] == "LazyVim/LazyVim" and s.opts and s.opts.colorscheme then
							local cs = s.opts.colorscheme
							if not seen[cs] then
								seen[cs] = true
								table.insert(choices, cs)
							end
						end
					end
				end

				return choices
			end

			local function set_and_apply(mode)
				theme_mode.set(mode)
				apply_theme()
			end

			vim.api.nvim_create_user_command("ThemeMode", function(opts)
				if opts.args ~= "" then
					set_and_apply(opts.args)
					return
				end
				local choices = theme_choices()
				vim.ui.select(choices, { prompt = "Theme mode (current: " .. theme_mode.get() .. ")" }, function(choice)
					if choice then
						set_and_apply(choice)
					end
				end)
			end, {
				nargs = "?",
				complete = function()
					return theme_choices()
				end,
			})
		end,
	},
}
