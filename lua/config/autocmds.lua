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

-- nvim dizin üstünde açılınca (nvim .) boş [No Name] buffer oluşuyor (netrw kapalı,
-- neo-tree devralıyor). 'hidden' açık olduğu için bu boş buffer terk edilince silinmiyor,
-- ilk dosya açılınca bufferline'da fazladan sekme olarak kalıyor.
-- Upstream: https://github.com/neovim/neovim/issues/17841 (workaround 'nohidden' burda
-- istenmiyor, 'hidden' genel olarak lazım) -> hedefli fix: sadece o boş buffer'ı,
-- başka gerçek bir dosya buffer'ı açılınca sil.
vim.api.nvim_create_autocmd("BufAdd", {
	group = vim.api.nvim_create_augroup("kill_stray_empty_buffer", { clear = true }),
	callback = function(args)
		if vim.bo[args.buf].buftype ~= "" or vim.api.nvim_buf_get_name(args.buf) == "" then
			return
		end
		for _, buf in ipairs(vim.api.nvim_list_bufs()) do
			local name = vim.api.nvim_buf_get_name(buf)
			if
				buf ~= args.buf
				and vim.api.nvim_buf_is_loaded(buf)
				and vim.bo[buf].buftype == ""
				and (name == "" or vim.fn.isdirectory(name) == 1)
				and not vim.bo[buf].modified
				and #vim.api.nvim_buf_get_lines(buf, 0, -1, false) <= 1
			then
				pcall(vim.api.nvim_buf_delete, buf, { force = true })
			end
		end
	end,
})
