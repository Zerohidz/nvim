-- Neovim sürüm hatalarına geçici çözümler. Her biri sürüme değil davranışa bakar: hata yoksa
-- (0.12 ya da düzeltilmiş nightly) hiçbir şey değişmez.
local M = {}

local function in_scratch(lines, fn)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  local ok, res = pcall(vim.api.nvim_buf_call, buf, fn)
  vim.api.nvim_buf_delete(buf, { force = true })
  return ok and res
end

-- neovim #42468 (0.13-dev, düzeltme PR #42485): sayı register'dan önce gelince x/X/D/C/s/S onu
-- iki kez uygular: `2"_x` 4 karakter siler. `"_x` map'lerinde `3x` = `3"_x` → 9 karakter.
M.count_before_register_squared = in_scratch({ "abcd" }, function()
  vim.api.nvim_feedkeys('2"_x', "xn", false)
  return vim.api.nvim_get_current_line() ~= "cd"
end)

--- `reg .. cmd` map'i (ör. '"_x'). Hata varsa sayıyı register'dan sonraya taşıyan expr map olur;
--- <Esc> bekleyen sayıyı iptal eder.
function M.map_register_cmd(mode, lhs, reg, cmd, opts)
  if not M.count_before_register_squared then
    return vim.keymap.set(mode, lhs, reg .. cmd, opts)
  end
  vim.keymap.set(mode, lhs, function()
    local count = vim.v.count
    return count > 0 and ("<Esc>" .. reg .. count .. cmd) or (reg .. cmd)
  end, vim.tbl_extend("force", opts or {}, { expr = true }))
end

return M
