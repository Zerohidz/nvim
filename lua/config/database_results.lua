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

function M.setup()
  local group = vim.api.nvim_create_augroup("DatabaseResults", { clear = true })
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
