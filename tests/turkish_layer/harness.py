#!/usr/bin/env python3
"""Türkçe katman diferansiyel testi: aynı senaryolar gerçek TUI'de (tmux) iki Neovim'de koşar.

Tuşlar tmux `send-keys -H` ile ham bayt olarak gider (gerçek terminal girdisi; tmux'un `;`
ayırıcısı gibi tuzaklar yok). Durum `--listen` soketinden okunur. Referans (ör. 0.12) ile
aday (ör. nightly) arasındaki her fark ya bug ya bilinçli değişikliktir.

Kullanım:
  harness.py --nvim /usr/bin/nvim --out ref.json
  harness.py --nvim /path/to/nightly/nvim --out cand.json
  harness.py --compare ref.json cand.json
"""
import re
import argparse
import json
import os
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path

import pynvim

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from scenarios import SCENARIOS  # noqa: E402

SPECIAL = {
    "<Esc>": b"\x1b", "<CR>": b"\r", "<Space>": b" ", "<BS>": b"\x7f", "<Tab>": b"\t",
    "<Up>": b"\x1b[A", "<Down>": b"\x1b[B", "<Right>": b"\x1b[C", "<Left>": b"\x1b[D",
}


def token_bytes(tok):
    if tok in SPECIAL:
        return SPECIAL[tok]
    if tok.startswith("<C-") and tok.endswith(">"):
        ch = tok[3:-1]
        if len(ch) == 1 and ch.isascii():
            return bytes([ord(ch.lower()) & 0x1F])
        # Ctrl + çok baytlı / noktalama: kitty CSI u (kitty+tmux extkeys altında böyle gelir)
        return f"\x1b[{ord(ch)};5u".encode()
    return tok.encode()


class Session:
    def __init__(self, nvim_bin, width=120, height=30):
        self.dir = Path(tempfile.mkdtemp(prefix="trlayer-"))
        self.sock = str(self.dir / "nvim.sock")
        self.server = "trlayer-" + str(os.getpid())
        self.file = self.dir / "t.txt"
        self.file.write_text("x\n")
        # WAYLAND_DISPLAY yok: yank'ler gerçek panoya değil test tmux sunucusuna gider (OSC 52)
        env = f"-u WAYLAND_DISPLAY XDG_STATE_HOME={self.dir}/state"
        # cwd sabit: terminal/statusline içeriği nereden çalıştırıldığına bağlı olmasın
        self.tmux("-f", "/dev/null", "new-session", "-d", "-c", str(Path(__file__).resolve().parents[2]),
                  "-x", str(width), "-y", str(height),
                  f"env {env} {nvim_bin} -n --listen {self.sock} {self.file}; sleep 600")
        deadline = time.time() + 20
        while not os.path.exists(self.sock):
            if time.time() > deadline:
                raise RuntimeError("nvim başlamadı: " + self.screen())
            time.sleep(0.1)
        self.nvim = pynvim.attach("socket", path=self.sock)
        # VeryLazy + which-key gibi gecikmeli kurulumlar bitsin
        while self.nvim.eval("v:vim_did_enter") != 1:
            time.sleep(0.1)
        time.sleep(2.5)
        self.version = self.nvim.exec_lua("return tostring(vim.version())")

    def tmux(self, *args, check=True):
        return subprocess.run(["tmux", "-L", self.server, *args], check=check,
                              capture_output=True, text=True).stdout

    def screen(self):
        return self.tmux("capture-pane", "-p", check=False)

    def send(self, data):
        if data:
            self.tmux("send-keys", "-H", *[f"{b:02x}" for b in data])

    def blocking(self):
        return self.nvim.api.get_mode()["blocking"]

    def settle(self, timeout=4.0):
        """timeoutlen=3000: belirsiz map'ler 3 sn bekler. Bloklu kalırsa False."""
        time.sleep(0.25)
        end = time.time() + timeout
        while self.blocking():
            if time.time() > end:
                return False
            time.sleep(0.05)
        self.nvim.eval("1")
        return True

    def reset(self, sc):
        for _ in range(3):
            self.send(b"\x1b")
            time.sleep(0.05)
        self.settle()
        n = self.nvim
        n.exec_lua(RESET_LUA, sc.get("lines", ["foo bar baz"]), sc.get("cursor", [1, 0]), sc.get("ft", ""))
        if sc.get("setup"):
            n.exec_lua(sc["setup"])
        self.settle()

    def run(self, sc, speed):
        self.reset(sc)
        if sc.get("rpc"):
            for tok in sc["keys"]:
                self.nvim.input(tok)
                time.sleep(0.15)
        elif speed == "human":
            for tok in sc["keys"]:
                self.send(token_bytes(tok))
                time.sleep(0.12 if tok == "<Esc>" else 0.08)
        else:
            # burst: bütün dizi tek seferde; Esc'ten sonra kısa ara (yoksa terminal Alt+tuş sayar)
            buf = b""
            for tok in sc["keys"]:
                buf += token_bytes(tok)
                if tok == "<Esc>":
                    self.send(buf)
                    buf = b""
                    time.sleep(0.08)
            self.send(buf)
        settled = self.settle()
        if not settled:
            return {"blocking": True, "mode": self.nvim.api.get_mode()["mode"],
                    # statusline saati gürültü
                    "screen": [re.sub(r"\d\d:\d\d", "HH:MM", l) for l in self.screen().rstrip().splitlines()[-3:]]}
        state = self.nvim.exec_lua(STATE_LUA, sc.get("regs", ""), sc.get("probe", ""))
        return state

    def close(self):
        # qa! RPC'si bir çıkış mesajının hit-enter istemine takılabiliyor; beklemeden öldür.
        self.tmux("kill-server", check=False)
        shutil.rmtree(self.dir, ignore_errors=True)


RESET_LUA = r"""
local lines, cursor, ft = ...
pcall(vim.cmd, "silent! only")
pcall(vim.cmd, "silent! tabonly")
if vim.fn.reg_recording() ~= "" then vim.cmd("normal! q") end
local ns = vim.api.nvim_get_namespaces()["nvim.multicursor"]
if ns then pcall(vim.api.nvim_buf_clear_namespace, 0, ns, 0, -1) end
local ok, mc = pcall(require, "multicursor-nvim")
if ok and package.loaded["multicursor-nvim"] then pcall(mc.clearCursors) end
vim.cmd("enew!")
vim.bo.bufhidden = "wipe"
if ft ~= "" then vim.bo.filetype = ft end
-- `.` önceki senaryodan sızmasın: her senaryo aynı son değişiklikle (x) başlar.
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "x" })
vim.cmd("normal! x")
vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
vim.api.nvim_win_set_cursor(0, { cursor[1], cursor[2] })
for _, r in ipairs(vim.split('abcdefghijklmnopqrstuvwxyz"/', "")) do pcall(vim.fn.setreg, r, "") end
vim.cmd("delmarks a-z")
vim.cmd("nohlsearch")
vim.fn.histdel("search")
vim.v.errmsg = ""
vim.cmd("messages clear")
"""

STATE_LUA = r"""
local regs, probe = ...
local s = {}
s.lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
s.cursor = vim.api.nvim_win_get_cursor(0)
s.mode = vim.api.nvim_get_mode().mode
s.errmsg = vim.v.errmsg
s.recording = vim.fn.reg_recording()
s.wins = #vim.tbl_filter(function(w) return vim.api.nvim_win_get_config(w).relative == "" end, vim.api.nvim_tabpage_list_wins(0))
s.ft = vim.bo.filetype
s.search = vim.fn.getreg("/")
s.regs = {}
for _, r in ipairs(vim.split(regs, "", { trimempty = true })) do s.regs[r] = vim.fn.getreg(r) end
local n = 1
local ns = vim.api.nvim_get_namespaces()["nvim.multicursor"]
if ns then n = n + #vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, {}) end
if package.loaded["multicursor-nvim"] then n = require("multicursor-nvim").numCursors() end
s.cursors = n
if probe ~= "" then s.probe = assert(loadstring(probe))() end
return s
"""


def run_all(nvim_bin, only=None):
    sess = Session(nvim_bin)
    print("nvim", sess.version, file=sys.stderr)
    results = {"version": sess.version, "cases": {}}
    try:
        for sc in SCENARIOS:
            if only and not re.search(only, sc["name"]):
                continue
            for speed in sc.get("speeds", ["rpc"] if sc.get("rpc") else ["human", "burst"]):
                key = f'{sc["name"]} [{speed}]'
                try:
                    results["cases"][key] = sess.run(sc, speed)
                except Exception as e:  # senaryo hatası diğerlerini durdurmasın
                    results["cases"][key] = {"harness_error": repr(e)}
                print(".", end="", flush=True, file=sys.stderr)
    finally:
        sess.close()
    print(file=sys.stderr)
    return results


def compare(ref, cand, verbose):
    diffs = 0
    # --only ile koşulmuş adayda olmayan durumlar karşılaştırılmaz.
    cases = {k: v for k, v in ref["cases"].items() if k in cand["cases"]}
    for key, r in cases.items():
        c = cand["cases"].get(key)
        if c != r:
            diffs += 1
            print(f"DIFF {key}")
            for f in sorted(set(r) | set(c or {})):
                rv, cv = r.get(f), (c or {}).get(f)
                if rv != cv:
                    print(f"   {f}: ref={rv!r}\n   {' ' * len(f)}  cand={cv!r}")
        elif verbose:
            print(f"SAME {key}")
    print(f"{len(cases) - diffs}/{len(cases)} aynı ({ref['version']} → {cand['version']})")
    return diffs


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--nvim")
    ap.add_argument("--out")
    ap.add_argument("--only")
    ap.add_argument("--compare", nargs=2)
    ap.add_argument("-v", action="store_true")
    a = ap.parse_args()
    if a.compare:
        ref, cand = (json.loads(Path(p).read_text()) for p in a.compare)
        sys.exit(1 if compare(ref, cand, a.v) else 0)
    res = run_all(a.nvim, a.only)
    Path(a.out).write_text(json.dumps(res, ensure_ascii=False, indent=1))
