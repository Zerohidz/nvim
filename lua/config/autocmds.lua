-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

-- "white" temasında diff arkaplanları (unified.nvim vs.) okunmuyor; GitHub light renkleriyle override et
local function white_diff_colors()
	vim.api.nvim_set_hl(0, "DiffAdd", { bg = "#dafbe1" })
	vim.api.nvim_set_hl(0, "DiffDelete", { bg = "#ffebe9" })
end

vim.api.nvim_create_autocmd("ColorScheme", {
	group = vim.api.nvim_create_augroup("white_diff_colors", { clear = true }),
	pattern = "white",
	callback = white_diff_colors,
})

-- autocmds.lua VeryLazy'de yüklendiği için colorscheme çoktan uygulanmış olabilir
if vim.g.colors_name == "white" then
	white_diff_colors()
end
