-- Load all colorscheme plugins referenced by Omarchy's theme directories
-- (lazy, never applied here) so they're available for hot-reload / :ThemeMode.
-- New Omarchy theme updates are picked up automatically (just :Lazy sync).

local plugins = {}
local seen = {}

for _, spec in ipairs(require("config.omarchy-themes").theme_specs()) do
	for _, s in ipairs(spec) do
		if s[1] and s[1] ~= "LazyVim/LazyVim" and not seen[s[1]] then
			seen[s[1]] = true
			table.insert(plugins, {
				s[1],
				name = s.name,
				lazy = true,
				priority = 1000,
			})
		end
	end
end

return plugins
