-- Variable segment text object (replaces vim-textobj-variable-segment)
-- Works in both terminal Neovim and vscode-neovim.
--
-- Reason for this approach: vim-textobj-user generates `xnoremap iv :<C-u>call ...`
-- The `:<C-u>` pattern in visual mode causes vscode-neovim to fail to sync the
-- selection back to VS Code. mini.ai uses a Lua-native approach that avoids this.
--
-- Usage: `iv` = inner variable segment, `av` = around variable segment
-- Examples: PascalCase -> Pascal | Case, snake_case -> snake | case

local function variable_segment(ai_type)
  local saved = vim.fn.getpos(".")
  local cur_row, cur_col = saved[2], saved[3]

  -- Patterns that mark the START of a segment (same as original plugin)
  local left_bounds = { "_\\+\\k", "\\<", "\\l\\u", "\\u\\u\\ze\\l", "\\a\\d", "\\d\\a" }

  -- Collect all segment-start positions found by searching backward
  local starts = {}
  for _, pat in ipairs(left_bounds) do
    vim.fn.setpos(".", saved)
    if vim.fn.search(pat, "bce") > 0 then
      table.insert(starts, vim.fn.getpos("."))
    end
  end
  vim.fn.setpos(".", saved)

  -- Pick the closest start: same line, at or before cursor, max column
  local best = nil
  for _, p in ipairs(starts) do
    if p[2] == cur_row and p[3] <= cur_col then
      if best == nil or p[3] > best[3] then
        best = p
      end
    end
  end

  -- Fallback: same line but after cursor
  if best == nil then
    for _, p in ipairs(starts) do
      if p[2] == cur_row and p[3] > cur_col then
        if best == nil then
          best = p
        end
      end
    end
  end

  if best == nil then
    best = saved
  end

  -- From the start, search for the end of the segment
  vim.fn.setpos(".", best)
  local right_pat = ai_type == "i"
      and "\\k_\\|\\l\\u\\|\\u\\u\\l\\|\\a\\d\\|\\d\\a\\|\\k\\>"
      or "_\\|\\l\\u\\|\\u\\u\\l\\|\\a\\d\\|\\d\\a\\|\\k\\>"
  vim.fn.search(right_pat, "c")
  local finish = vim.fn.getpos(".")

  vim.fn.setpos(".", saved)

  return {
    from = { line = best[2], col = best[3] },
    to = { line = finish[2], col = finish[3] },
  }
end

return {
  {
    "nvim-mini/mini.ai",
    opts = function(_, opts)
      opts.custom_textobjects = opts.custom_textobjects or {}
      opts.custom_textobjects.v = variable_segment
    end,
  },
}
