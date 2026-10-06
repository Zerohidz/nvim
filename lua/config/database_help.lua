local M = {}

function M.setup()
  -- Patch the drawer instance, so plugin updates do not overwrite this help.
  vim.cmd([[
    function! CodexDBUIToggleConnection(db) dict abort
      call call(self.codex_original_toggle_db, [a:db], self)
      if a:db.expanded && a:db.schema_support && has_key(a:db.schemas.items, 'public')
        let a:db.schemas.expanded = 1
        let a:db.schemas.items.public.expanded = 1
      endif
    endfunction

    function! CodexDBUIRenderHelp() dict abort
      call call(self.codex_original_render_help, [], self)
      for item in self.content
        if item.type ==# 'help'
          let item.label = substitute(item.label, '<Leader>W', 'Space v w', 'g')
          let item.label = substitute(item.label, '<Leader>E', 'Space v e', 'g')
          let item.label = substitute(item.label, '<Leader>S', 'Space v r', 'g')
          let item.label = substitute(item.label, '<Leader>R', 'Space v l / Space R', 'g')
        endif
      endfor
      if self.show_help
        call self.add('" Space v v / Space v a - Toggle database drawer / add connection', 'noaction', 'help', '', '', 0)
        call self.add('" Ctrl+H / Ctrl+L - (.dbout) Left/right window; otherwise scroll half screen', 'noaction', 'help', '', '', 0)
      endif
    endfunction
  ]])
  vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("DatabaseHelp", { clear = true }),
    pattern = "dbui",
    callback = function()
      vim.cmd([[
        let drawer = db_ui#drawer#get()
        if !has_key(drawer, 'codex_original_render_help')
          let drawer.codex_original_render_help = drawer.render_help
          let drawer.render_help = function('CodexDBUIRenderHelp')
        endif
        if !has_key(drawer, 'codex_original_toggle_db')
          let drawer.codex_original_toggle_db = drawer.toggle_db
          let drawer.toggle_db = function('CodexDBUIToggleConnection')
        endif
        unlet drawer
      ]])
    end,
  })
end

return M
