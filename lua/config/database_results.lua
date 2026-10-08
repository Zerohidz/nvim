local M = {}
local pending = {}
local layout_scrolloff = {}
local function expanded(buf)
  local value = vim.b[buf].db_ui_expanded_layout
  return value == true or value == 1
end

local function records(lines, expanded)
  local result, block, row, active, continuation = {}, 0, 0, false, false
  for index, line in ipairs(lines) do
    if expanded then
      local number = tonumber(line:match("^%-%[ RECORD (%d+) %]"))
      if number then
        if number == 1 then block = block + 1 end
        result[#result + 1] = { line = index, block = block, row = number }
      end
    elseif line:match("^[%s%-%+]+$") and line:find("-", 1, true) then
      block, row, active, continuation = block + 1, 0, true, false
    elseif line:match("^%(%d+ rows?%)") or line:match("^%s*$") then
      active = false
    elseif active then
      if not continuation then
        row = row + 1
        result[#result + 1] = { line = index, block = block, row = row }
      end
      continuation = line:match("%+%s*$") ~= nil
    end
  end
  return result
end

function M.resize(buf)
  for _, win in ipairs(vim.fn.win_findbuf(buf)) do
    if vim.api.nvim_win_is_valid(win) and #vim.api.nvim_tabpage_list_wins(vim.api.nvim_win_get_tabpage(win)) > 1 then
      local size = require("toggleterm.config").get("size")
      if type(size) == "function" then size = size({ direction = "horizontal" }) end
      vim.api.nvim_win_set_height(win, size)
    end
  end
end

function M.restore_height()
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.bo[buf].filetype == "dbout" then M.resize(buf) end
  end
end

function M.navigate_or_scroll(direction)
  local current = vim.api.nvim_get_current_win()
  local neighbor = vim.fn.win_getid(vim.fn.winnr(direction))
  if neighbor ~= current and neighbor ~= 0 then
    vim.api.nvim_set_current_win(neighbor)
  else
    vim.cmd("normal! " .. (direction == "h" and "zH" or "zL"))
  end
end

function M.toggle()
  local buf = vim.api.nvim_get_current_buf()
  local db = vim.b.db
  local url = type(db) == "table" and db.db_url or ""
  if url:match("^postgres") then
    local cursor = vim.api.nvim_win_get_cursor(0)[1]
    local selected
    for _, record in ipairs(records(vim.api.nvim_buf_get_lines(buf, 0, -1, false), expanded(buf))) do
      if record.line > cursor then break end
      selected = record
    end
    if selected then
      selected.buf = buf
      pending[db.output] = selected
    end
  end
  local ok, err = pcall(vim.fn["db_ui#dbout#toggle_layout"])
  if not ok then
    if type(db) == "table" then pending[db.output] = nil end
    error(err)
  end
end

-- FK atlama geçmişi: her atlamadan önceki sorgu (dosyası), görünümü ve imlecin hangi kayıtta /
-- ekranda nerede olduğu saklanır; <C-t> ile geri dönülünce aynı yere oturtulur.
local history = {}
-- Sıradaki sonuç gelince: geçmişe ekle (push), detay görünüme çevir (expanded), imleci oturt (restore/focus).
local after_result

local function arm(opts)
  opts.t = vim.uv.now()
  after_result = opts
end

-- İmlecin bulunduğu kayıt (block/row), kayıt içindeki satır farkı ve ekran kayması.
local function snapshot(buf)
  local cursor = vim.api.nvim_win_get_cursor(0)
  local selected
  for _, record in ipairs(records(vim.api.nvim_buf_get_lines(buf, 0, -1, false), expanded(buf))) do
    if record.line > cursor[1] then break end
    selected = record
  end
  if not selected then return nil end
  return {
    block = selected.block, row = selected.row, off = cursor[1] - selected.line,
    col = cursor[2], scroll = cursor[1] - vim.fn.line("w0"),
  }
end

local function restore(buf, snap)
  local win = vim.fn.win_findbuf(buf)[1]
  if not win then return end
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  for _, record in ipairs(records(lines, expanded(buf))) do
    if record.block == snap.block and record.row == snap.row then
      local line = math.min(record.line + snap.off, #lines)
      vim.api.nvim_win_call(win, function()
        vim.fn.winrestview({ lnum = line, col = snap.col, topline = math.max(1, line - snap.scroll) })
      end)
      return
    end
  end
end

-- Atlanılan hedefte ilk kaydın başlığı ekranın en üstünde, imleç ilk alanda olsun.
local function focus_first_record(buf)
  local win = vim.fn.win_findbuf(buf)[1]
  if not win then return end
  local first = records(vim.api.nvim_buf_get_lines(buf, 0, -1, false), expanded(buf))[1]
  if not first then return end
  vim.api.nvim_win_call(win, function()
    local line = math.min(first.line + (expanded(buf) and 1 or 0), vim.api.nvim_buf_line_count(buf))
    vim.fn.winrestview({ lnum = line, col = 0, topline = first.line })
  end)
end

-- Eklentinin FK atlaması kolon adını tablo başlığından okuyor; detay (expanded) görünümde
-- her satır "kolon | değer" olduğu için orada "No valid foreign key found" veriyordu.
-- Detay görünümde kolon/değeri imlecin satırından okuyup aynı sorguyu çalıştırır.
function M.jump_to_foreign_key()
  local buf = vim.api.nvim_get_current_buf()
  local db = vim.b[buf].db
  local is_expanded = expanded(buf)
  if type(db) == "table" and db.input then
    arm({ push = { input = db.input, expanded = is_expanded, snap = snapshot(buf) }, expanded = is_expanded, focus = true })
  end
  if is_expanded then
    vim.fn.CodexDBUIJumpExpanded()
  else
    vim.fn["db_ui#dbout#jump_to_foreign_table"]()
  end
end

function M.back()
  local entry = table.remove(history)
  if not entry then
    return vim.notify("Geri gidilecek sonuç yok", vim.log.levels.INFO)
  end
  arm({ expanded = entry.expanded, restore = entry.snap })
  vim.cmd("DB < " .. vim.fn.fnameescape(entry.input))
end

function M.setup()
  vim.cmd([[
    function! CodexDBUIJumpExpanded() abort
      let m = matchlist(getline('.'), '^\(\S\+\)\s*|\s\?\(.\{-}\)\s*$')
      if empty(m)
        return db_ui#notifications#error('Önce bir alanın (kolon | değer) üzerine gel.')
      endif
      let field_name = m[1]
      let field_value = m[2]
      if field_value ==# ''
        return db_ui#notifications#error('Alan boş (NULL), gidilecek kayıt yok.')
      endif
      let db_url = b:db.db_url
      let scheme = db_ui#schemas#get(db#url#parse(db_url).scheme)
      if empty(scheme)
        return db_ui#notifications#error('Bu veritabanı türü foreign key atlamasını desteklemiyor.')
      endif
      let fk_query = substitute(scheme.foreign_key_query, '{col_name}', field_name, '')
      let Parser = get(scheme, 'parse_virtual_results', scheme.parse_results)
      let result = Parser(db_ui#schemas#query(db_url, scheme, fk_query), 3)
      if empty(result)
        return db_ui#notifications#error('No valid foreign key found.')
      endif
      let [foreign_table, foreign_column, foreign_schema] = result[0]
      exe 'DB ' . printf(scheme.select_foreign_key_query, foreign_schema, foreign_table, foreign_column, db_ui#utils#quote_query_value(field_value))
    endfunction
  ]])
  local group = vim.api.nvim_create_augroup("DatabaseResults", { clear = true })
  -- FK atlaması / geri dönüş sonrası: geçmişe ekle, gerekirse detay görünüme çevir.
  vim.api.nvim_create_autocmd("User", {
    group = group,
    pattern = "*DBExecutePost",
    callback = function(event)
      local job = after_result
      if not job then return end
      after_result = nil
      if vim.uv.now() - job.t > 8000 then return end -- atlama başarısız olmuş, eski kayıt
      if job.push then history[#history + 1] = job.push end
      if not job.expanded and not job.restore and not job.focus then return end
      local path = event.match:gsub("/DBExecutePost$", "")
      vim.schedule(function()
        local buf = vim.fn.bufnr(path)
        if buf < 0 then buf = vim.api.nvim_get_current_buf() end
        if job.expanded and not expanded(buf) then
          -- Detay görünüme çevirmek sorguyu yeniden çalıştırır; imleci o bitince oturt.
          arm({ restore = job.restore, focus = job.focus })
          local win = vim.fn.win_findbuf(buf)[1]
          if win then
            vim.api.nvim_win_call(win, function() pcall(vim.fn["db_ui#dbout#toggle_layout"]) end)
          end
          return
        end
        if job.restore then
          restore(buf, job.restore)
        elseif job.focus then
          focus_first_record(buf)
        end
      end)
    end,
  })
  vim.api.nvim_create_autocmd({ "FileType", "BufWinEnter" }, {
    group = group,
    callback = function(event)
      if vim.bo[event.buf].filetype == "dbout" then
        vim.schedule(function()
          if vim.api.nvim_buf_is_valid(event.buf) then M.resize(event.buf) end
        end)
      end
    end,
  })
  vim.api.nvim_create_autocmd("User", {
    group = group,
    pattern = "*DBExecutePost",
    callback = function(event)
      local path = event.match:gsub("/DBExecutePost$", "")
      local selected = pending[path]
      if not selected then return end
      pending[path] = nil
      vim.schedule(function()
        local buf = selected.buf
        if buf < 0 or not vim.api.nvim_buf_is_loaded(buf) then return end
        local db = vim.b[buf].db
        if type(db) ~= "table" or db.exit_status ~= 0 then return end
        local target, last_line
        local is_expanded = expanded(buf)
        local all_records = records(vim.api.nvim_buf_get_lines(buf, 0, -1, false), is_expanded)
        for index, record in ipairs(all_records) do
          if record.block == selected.block and record.row == selected.row then
            target = record.line
            last_line = all_records[index + 1] and all_records[index + 1].line - 1 or vim.api.nvim_buf_line_count(buf)
            break
          end
        end
        if target then
          for _, win in ipairs(vim.fn.win_findbuf(buf)) do
            vim.api.nvim_win_call(win, function()
              if layout_scrolloff[win] then
                vim.wo.scrolloff = layout_scrolloff[win]
                layout_scrolloff[win] = nil
              end
              vim.api.nvim_win_set_cursor(win, { target, 0 })
              vim.cmd("normal! zv")
              if is_expanded then
                local padding = math.min(vim.wo.scrolloff, math.floor(vim.api.nvim_win_get_height(win) / 2), last_line - target)
                if padding < vim.wo.scrolloff then
                  layout_scrolloff[win] = vim.wo.scrolloff
                  vim.wo.scrolloff = padding
                end
                vim.api.nvim_win_set_cursor(win, { target + padding, 0 })
                vim.fn.winrestview({ topline = target, leftcol = 0 })
              else
                vim.cmd("normal! zt")
              end
            end)
          end
        end
      end)
    end,
  })
end

return M
