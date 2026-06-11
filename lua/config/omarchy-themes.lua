-- Shared helper: read all Omarchy theme specs (lua/plugins/neovim.lua per theme dir)
local M = {}

function M.theme_specs()
	local specs = {}

	local bases = {
		vim.fn.expand("~/.config/omarchy/themes"),
	}
	if vim.env.OMARCHY_PATH then
		table.insert(bases, vim.env.OMARCHY_PATH .. "/themes")
	end

	for _, base in ipairs(bases) do
		for _, dir in ipairs(vim.fn.glob(base .. "/*", true, true)) do
			local nvfile = dir .. "/neovim.lua"
			if vim.fn.filereadable(nvfile) == 1 then
				local ok, spec = pcall(dofile, nvfile)
				if ok then
					table.insert(specs, spec)
				end
			end
		end
	end

	return specs
end

return M
