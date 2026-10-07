#!/usr/bin/env python3
"""Macro replay with a UI attached so which-key/langmapper triggers load; requires pynvim."""
from pathlib import Path
import sys, tempfile, time

import pynvim

ROOT = Path(__file__).resolve().parents[1]
nvim = pynvim.attach("child", argv=["nvim","--embed","-n","-i","NONE","-u",str(ROOT / "init.lua")])
nvim.ui_attach(100, 30, rgb=True, ext_linegrid=True)
def pump(t=0.25): time.sleep(t); nvim.eval("1")
pump(2)
nvim.command("edit! " + tempfile.mkdtemp() + "/x.txt")
pump(0.5)
print("nmap i:", nvim.exec_lua('local m=vim.fn.maparg("i","n",false,true) return (m.desc or "none")'))
def send(k): nvim.input(k); pump()
fails=0
def reset():
    nvim.input("<Esc><Esc>"); pump()
    nvim.current.buffer[:] = ["foo bar baz", "one two three", "x y z", "a b c", "q w e"]
    nvim.funcs.cursor(1,1); nvim.command("let v:errmsg=''")
def check(label, cond, extra):
    global fails
    ok = cond and not nvim.eval("v:errmsg")
    fails += not ok
    print("PASS" if ok else "FAIL", label, extra, repr(nvim.eval("v:errmsg")), flush=True)
# insert macro
reset(); [send(k) for k in ["qa","ı","test","<Esc>","q"]]; reg=nvim.funcs.getreg("a")
reset(); send("@a"); check("insert @a", nvim.current.buffer[0]=="testfoo bar baz", (reg, nvim.current.buffer[0]))
reset(); send("Q"); check("insert Q", nvim.current.buffer[0]=="testfoo bar baz", nvim.current.buffer[0])
# movement
reset(); [send(k) for k in ["qq","j","j","w","q"]]
reset(); send("@q"); check("move @q", nvim.funcs.getpos(".")[1:3]==[3,3], nvim.funcs.getpos("."))
# dot repeat inside macro (typed ç)
reset(); [send(k) for k in ["qa","x","ç","j","q"]]; reg=nvim.funcs.getreg("a")
reset(); send("@a"); check("dot @a", nvim.current.buffer[0]=="o bar baz", (reg, nvim.current.buffer[0]))
# typed i (TR ') still jumps to a mark through mapping
reset(); nvim.funcs.cursor(3,1); send("ma"); nvim.funcs.cursor(1,1); send("ia"); check("typed i=' mark jump", nvim.funcs.line(".")==3, nvim.funcs.line("."))
# typed . (TR /) still searches
reset(); send(".two<CR>"); check("typed . search", nvim.funcs.line(".")==2, nvim.funcs.getpos("."))
# typed ı enters insert
reset(); send("ıZ<Esc>"); check("typed ı insert", nvim.current.buffer[0]=="Zfoo bar baz", nvim.current.buffer[0])
print("FAILS", fails)
nvim.close()
sys.exit(1 if fails else 0)
