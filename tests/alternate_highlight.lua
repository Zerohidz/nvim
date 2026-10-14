-- nvim --headless -u NONE -l tests/alternate_highlight.lua
local root = vim.fn.stdpath("config")
vim.opt.rtp:prepend(root)
vim.g.mapleader = " "
vim.cmd("filetype plugin indent on")
vim.cmd("syntax enable")
local recovery = require("config.alternate_highlight")
recovery.setup()
local checks = 0
local function check(ok, label)
  assert(ok, label)
  checks = checks + 1
end
local mapping = vim.fn.maparg("<leader>bb", "n", false, true)
check(type(mapping.callback) == "function", "mapping has recovery callback")
local dir = vim.fn.tempname()
vim.fn.mkdir(dir, "p")
local java = dir .. "/Example.java"
local other = dir .. "/other.lua"
vim.fn.writefile({ "public class Example {", "  private int count = 1;", "}" }, java)
vim.fn.writefile({ "local value = 1" }, other)
local function edit(path)
  vim.cmd.edit(vim.fn.fnameescape(path))
end
local function reopen()
  mapping.callback()
end
edit(java)
local buf = vim.api.nvim_get_current_buf()
edit(other)
reopen()
check(vim.api.nvim_get_current_buf() == buf and vim.bo.filetype == "java", "healthy alternate preserved")
edit(other)
vim.bo[buf].filetype = ""
vim.bo[buf].syntax = ""
reopen()
check(vim.bo.filetype == "java", "missing Java filetype recovered")
check(vim.bo.syntax == "java" or vim.treesitter.highlighter.active[buf] ~= nil, "syntax or Treesitter active")
-- Known-filetype buffers are untouched, including a deliberate syntax/TS stop.
vim.treesitter.stop(buf)
vim.b.ts_highlight = nil
vim.bo.syntax = ""
edit(other)
reopen()
check(vim.bo.syntax == "" and vim.b.ts_highlight == nil and vim.treesitter.highlighter.active[buf] == nil, "known filetype intentional highlight off preserved")
vim.bo.filetype = "bigfile"
local bigfile_syntax = vim.bo.syntax
edit(other)
reopen()
check(vim.bo.filetype == "bigfile" and vim.bo.syntax == bigfile_syntax, "bigfile bypass preserved")
vim.bo.filetype = "java"
local terminal = vim.api.nvim_create_buf(true, false)
vim.api.nvim_set_current_buf(terminal)
vim.fn.termopen({ "/bin/sh", "-c", "printf terminal" })
edit(other)
reopen()
check(vim.api.nvim_get_current_buf() == terminal and vim.bo.buftype == "terminal" and vim.bo.filetype == "", "terminal unchanged")
local unknown = dir .. "/file.unknown_alternate_test"
vim.fn.writefile({ "unknown" }, unknown)
edit(unknown)
edit(other)
reopen()
check(vim.bo.filetype == "", "unknown filetype causes no error")
edit(java)
vim.o.hidden = false
vim.o.confirm = false
vim.o.autowrite = false
vim.o.autowriteall = false
vim.bo.modified = true
local current = vim.api.nvim_get_current_buf()
local ok = pcall(reopen)
check(not ok and vim.api.nvim_get_current_buf() == current and vim.bo.modified, "edit # unsaved-change protection preserved")
vim.bo.modified = false
vim.cmd("%bwipeout!")
ok = pcall(reopen)
check(not ok, "no alternate keeps edit # error")
vim.fn.delete(dir, "rf")
print("alternate_highlight: " .. checks .. " checks passed")
