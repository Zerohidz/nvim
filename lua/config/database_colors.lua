local M = {}
local ns = vim.api.nvim_create_namespace("DatabaseColumnColors")
local compact_ns = vim.api.nvim_create_namespace("DatabaseCompactColumns")
local max_width = 40
local palette = { "DiagnosticInfo", "DiagnosticHint", "DiagnosticWarn", "DiagnosticOk", "Special", "Identifier" }

local function groups()
  for index, source in ipairs(palette) do
    vim.api.nvim_set_hl(0, "DatabaseColumn" .. index, { link = source })
  end
end

function M.apply(buf)
  if not vim.api.nvim_buf_is_loaded(buf) or vim.bo[buf].filetype ~= "dbout" then return end
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  vim.api.nvim_buf_clear_namespace(buf, compact_ns, 0, -1)
  local win = vim.fn.win_findbuf(buf)[1]
  if not win then return end
  for _, result_win in ipairs(vim.fn.win_findbuf(buf)) do
    vim.wo[result_win].conceallevel = 2
    vim.wo[result_win].concealcursor = "nvc"
  end
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local function mark(row, from, to, column)
    if to <= from then return end
    vim.api.nvim_buf_set_extmark(buf, ns, row - 1, from, {
      end_col = to,
      hl_group = "DatabaseColumn" .. ((column - 1) % #palette + 1),
      hl_mode = "combine",
      priority = 90,
    })
  end
  local layout = vim.b[buf].db_ui_expanded_layout
  if layout == true or layout == 1 then
    local column = 0
    for row, line in ipairs(lines) do
      if line:match("^%-%[ RECORD %d+ %]") then
        column = 0
      else
        local pipe = line:find("|", 1, true)
        if pipe then
          column = column + 1
          mark(row, 0, pipe - 1, column)
        end
      end
    end
  else
    local ranges
    local function color_row(row)
      local line = lines[row]
      for column, range in ipairs(ranges) do
        local from = vim.fn.virtcol2col(win, row, range[1] + 1)
        local to = vim.fn.virtcol2col(win, row, range[2] + 1)
        if from > 0 then mark(row, from - 1, to > 0 and to - 1 or #line, column) end
        if range[2] - range[1] > max_width then
          local start = vim.fn.virtcol2col(win, row, range[1] + max_width)
          local finish = to > 0 and to - 1 or #line
          if start > 0 and start - 1 < finish then
            local hidden = line:sub(start, finish)
            vim.api.nvim_buf_set_extmark(buf, compact_ns, row - 1, start - 1, {
              end_col = finish,
              conceal = hidden:find("%S") and "…" or " ",
            })
          end
        end
      end
    end
    for row, line in ipairs(lines) do
      if line:match("^[%s%-%+]+$") and line:find("-", 1, true) then
        ranges = {}
        local from = 0
        for index = 1, #line do
          if line:sub(index, index) == "+" then
            ranges[#ranges + 1] = { from, index - 1 }
            from = index
          end
        end
        ranges[#ranges + 1] = { from, #line }
        if row > 1 then color_row(row - 1) end
        color_row(row)
      elseif line:match("^%(%d+ rows?%)") or line:match("^%s*$") then
        ranges = nil
      elseif ranges then
        color_row(row)
      end
    end
  end
end

function M.setup()
  groups()
  local group = vim.api.nvim_create_augroup("DatabaseColors", { clear = true })
  vim.api.nvim_create_autocmd("ColorScheme", { group = group, callback = groups })
  vim.api.nvim_create_autocmd({ "FileType", "BufWinEnter" }, {
    group = group,
    callback = function(event)
      if vim.bo[event.buf].filetype == "dbout" then vim.schedule(function() M.apply(event.buf) end) end
    end,
  })
  vim.api.nvim_create_autocmd("User", {
    group = group,
    pattern = "*DBExecutePost",
    callback = function(event)
      local buf = vim.fn.bufnr(event.match:gsub("/DBExecutePost$", ""))
      if buf > 0 then vim.schedule(function() M.apply(buf) end) end
    end,
  })
end

return M
