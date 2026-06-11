-- Persisted theme mode: "omarchy" (sync with Omarchy system theme) or
-- a colorscheme name (e.g. "simple-focus", "gruvbox", "tokyonight", ...)
local M = {}

local state_file = vim.fn.stdpath("data") .. "/theme-mode.txt"

function M.get()
  local f = io.open(state_file, "r")
  if not f then
    return "omarchy"
  end
  local mode = f:read("*l")
  f:close()
  return (mode and mode ~= "") and mode or "omarchy"
end

function M.set(mode)
  local f = io.open(state_file, "w")
  if f then
    f:write(mode)
    f:close()
  end
end

-- Resolve "omarchy" mode to the colorscheme name from Omarchy's current theme.
function M.resolve(mode)
  mode = mode or M.get()
  if mode ~= "omarchy" then
    return mode
  end
  local path = vim.fn.expand("~/.config/omarchy/current/theme/neovim.lua")
  local ok, spec = pcall(dofile, path)
  if ok then
    for _, s in ipairs(spec) do
      if s[1] == "LazyVim/LazyVim" and s.opts and s.opts.colorscheme then
        return s.opts.colorscheme
      end
    end
  end
  return "gruvbox"
end

return M
