local M = {}


local tables_query = [[
select n.nspname, coalesce(c.relname, '')
from pg_namespace n
left join pg_class c on c.relnamespace = n.oid and c.relkind in ('r','p','v','m','f')
where n.nspname !~ '^pg_' and n.nspname <> 'information_schema'
  and has_schema_privilege(current_user, n.nspname, 'USAGE')
order by 1, 2]]

-- Expand every connection without blocking the UI: the table listing runs in parallel
-- psql jobs, and each connection is opened (cheap but ~150ms) as its result arrives.
local function expand_all_async()
  local urls = vim.fn.CodexDBUIUrls()
  vim.fn.CodexDBUIExpandAll(0)
  for key, url in pairs(urls) do
    if url:match("^postgres") then
      vim.system({ "psql", "-X", "-A", "-t", "-F", "\t", "-c", tables_query, url },
        { text = true, env = { PGCONNECT_TIMEOUT = "10" } },
        vim.schedule_wrap(function(res)
          if res.code ~= 0 then
            vim.notify(("DBUI %s: %s"):format(key, vim.trim(res.stderr or "")), vim.log.levels.ERROR)
            return
          end
          local rows = {}
          for line in (res.stdout or ""):gmatch("[^\r\n]+") do
            local schema, table = line:match("^([^\t]*)\t(.*)$")
            if schema then rows[#rows + 1] = { schema, table } end
          end
          if vim.fn.CodexDBUIPrepare(key) ~= "" then
            pcall(vim.fn.CodexDBUIApplyTables, key, rows)
          else
            pcall(function() vim.fn["db_ui#drawer#get"]().render() end)
          end
        end))
    else
      vim.schedule(function()
        vim.fn.CodexDBUIPrepare(key)
        pcall(function() vim.fn["db_ui#drawer#get"]().render() end)
      end)
    end
  end
end

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


    " Async expand-all: connect is cheap, the table listing runs in a psql job.
    function! CodexDBUIUrls() abort
      let urls = {}
      for [key, db] in items(db_ui#drawer#get().dbui.dbs)
        let urls[key] = db.url
      endfor
      return urls
    endfunction

    function! CodexDBUIPrepare(key) abort
      let drawer = db_ui#drawer#get()
      let db = drawer.dbui.dbs[a:key]
      call CodexDBUISetExpanded(db, 0)
      let db.expanded = 1
      call drawer.load_saved_queries(db)
      call drawer.dbui.connect(db)
      if empty(db.conn)
        return ''
      endif
      if db.scheme !~# '^postgres' || !db.schema_support
        call drawer.populate(db)
        call CodexDBUIOpenPublic(db)
        return ''
      endif
      return db.conn
    endfunction

    function! CodexDBUIOpenPublic(db) abort
      if a:db.schema_support && has_key(a:db.schemas.items, 'public')
        let a:db.schemas.expanded = 1
        let a:db.schemas.items.public.expanded = 1
        let a:db.schemas.items.public.tables.expanded = 1
      endif
    endfunction

    function! CodexDBUIApplyTables(key, rows) abort
      let drawer = db_ui#drawer#get()
      if !has_key(drawer.dbui.dbs, a:key)
        return
      endif
      let db = drawer.dbui.dbs[a:key]
      let by_schema = {}
      let db.tables.list = []
      for [schema, table] in a:rows
        if !has_key(by_schema, schema)
          let by_schema[schema] = []
        endif
        if !empty(table)
          call add(by_schema[schema], table)
          call add(db.tables.list, table)
        endif
      endfor
      let db.schemas.list = sort(keys(by_schema))
      for schema in db.schemas.list
        if !has_key(db.schemas.items, schema)
          let db.schemas.items[schema] = {'expanded': 0, 'tables': {'expanded': 1, 'list': [], 'items': {}}}
        endif
        let db.schemas.items[schema].tables.list = sort(by_schema[schema])
        call drawer.populate_table_items(db.schemas.items[schema].tables)
      endfor
      call CodexDBUIOpenPublic(db)
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
      vim.keymap.set("n", "zj", expand_all_async,
        { buffer = true, silent = true, desc = "Bağlantıları ve public tablolarını aç" })
      vim.keymap.set("n", "zk", function() vim.fn.CodexDBUIExpandAll(0) end,
        { buffer = true, silent = true, desc = "Hepsini kapat" })
    end,
  })
end

return M
