local M = {}

function M.setup()
  -- Patch the drawer instance, so plugin updates do not overwrite this help.
  vim.cmd([[
    function! CodexDBUISetExpanded(tree, value) abort
      if type(a:tree) != v:t_dict
        return
      endif
      if has_key(a:tree, 'expanded')
        let a:tree.expanded = a:value
      endif
      for child in values(a:tree)
        if type(child) == v:t_dict
          call CodexDBUISetExpanded(child, a:value)
        endif
      endfor
    endfunction

    function! CodexDBUIExpandAll(value) abort
      let drawer = db_ui#drawer#get()
      for db in values(drawer.dbui.dbs)
        call CodexDBUISetExpanded(db, 0)
        if a:value
          let db.expanded = 1
          call drawer.toggle_db(db)
        endif
      endfor
      let drawer.show_dbout_list = 0
      call drawer.render()
    endfunction

    function! CodexDBUIToggleConnection(db) dict abort
      call call(self.codex_original_toggle_db, [a:db], self)
      if a:db.expanded && a:db.schema_support && has_key(a:db.schemas.items, 'public')
        let a:db.schemas.expanded = 1
        let a:db.schemas.items.public.expanded = 1
        let a:db.schemas.items.public.tables.expanded = 1
      endif
    endfunction

    function! CodexDBUIRenderHelp() dict abort
      call call(self.codex_original_render_help, [], self)
      for item in self.content
        if item.type ==# 'help'
          let item.label = substitute(item.label, '" o - Open/Toggle', '" l - Open/Toggle', '')
          let item.label = substitute(item.label, '<Leader>W', 'Space v w', 'g')
          let item.label = substitute(item.label, '<Leader>E', 'Space v e', 'g')
          let item.label = substitute(item.label, '<Leader>S', 'Space v r', 'g')
          let item.label = substitute(item.label, '<Leader>R', 'Space v l / Space R', 'g')
        endif
      endfor
      if self.show_help
        call self.add('" zj / zk - Open connections + public tables / collapse all', 'noaction', 'help', '', '', 0)
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
      pcall(vim.keymap.del, "n", "o", { buffer = true })
      vim.keymap.set("n", "l", "<Plug>(DBUI_SelectLine)",
        { buffer = true, remap = true, silent = true, desc = "Aç / kapat" })
      vim.keymap.set("n", "zj", function() vim.fn.CodexDBUIExpandAll(1) end,
        { buffer = true, silent = true, desc = "Bağlantıları ve public tablolarını aç" })
      vim.keymap.set("n", "zk", function() vim.fn.CodexDBUIExpandAll(0) end,
        { buffer = true, silent = true, desc = "Hepsini kapat" })
    end,
  })
end

return M
