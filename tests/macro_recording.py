#!/usr/bin/env python3
"""Exercise real input recording/playback; requires pynvim and installed plugins."""
import argparse
import os
from pathlib import Path
import shutil
import time

import pynvim

ROOT = Path(__file__).resolve().parents[1]
TEXT = "Türkçe ıişğüöç"


def send(nvim, keys):
    nvim.input(keys)
    time.sleep(0.06)
    nvim.eval("1")  # RPC barrier: process input and scheduled RecordingLeave work.


def fresh(nvim):
    nvim.command("enew!")
    nvim.command("let v:errmsg = ''")


def assert_buffer(nvim, text, label):
    actual = list(nvim.current.buffer)
    error = nvim.eval("v:errmsg")
    assert actual == [text] and not error, f"{label}: buffer={actual!r}, error={error!r}"
    assert nvim.eval("mode()") == "n", f"{label}: left normal mode"


def run(profile, nvim_bin):
    args = [nvim_bin, "--embed", "--headless", "-i", "NONE"]
    args += ["-u", "NONE" if profile == "minimal" else str(ROOT / "init.lua")]
    nvim = pynvim.attach("child", argv=args)
    try:
        if profile == "minimal":
            nvim.exec_lua('package.path = ... .. "/lua/?.lua;" .. package.path; require("config.turkish_keys").setup()', str(ROOT))
        # A repeated setup must not install a second normalizer.
        nvim.exec_lua('require("config.turkish_keys").setup()')
        hooks = nvim.exec_lua('return #vim.api.nvim_get_autocmds({group="TurkishMacroRecording", event="RecordingLeave"})')
        assert hooks == 1, f"{profile}: duplicate RecordingLeave callbacks"
        fresh(nvim)
        for keys in ["qa", "ı", "test", "<Esc>", "q"]:
            send(nvim, keys)
        fresh(nvim)
        send(nvim, "@a")
        assert_buffer(nvim, "test", profile + " ASCII @a")
        fresh(nvim)
        for keys in ["qa", "ı", TEXT, "<Esc>", "q"]:
            send(nvim, keys)
        assert_buffer(nvim, TEXT, profile + " recording")
        macro = nvim.funcs.getreg("a")
        assert macro == "i" + TEXT + "\x1b", f"{profile}: register={macro!r}"
        fresh(nvim)
        send(nvim, "@a")
        assert_buffer(nvim, TEXT, profile + " @a")
        fresh(nvim)
        send(nvim, "@@")
        assert_buffer(nvim, TEXT, profile + " @@")
        fresh(nvim)
        send(nvim, "2@a")
        # i starts before the previous insertion's last character.
        assert_buffer(nvim, TEXT[:-1] + TEXT + TEXT[-1], profile + " 2@a")
        # qA appends only the newly recorded segment. Its existing i must stay i.
        fresh(nvim)
        for keys in ["qA", "a", "ek", "<Esc>", "q"]:
            send(nvim, keys)
        assert nvim.funcs.getreg("a") == macro + "aek\x1b", f"{profile}: qA changed the existing macro"
        fresh(nvim)
        send(nvim, "@a")
        assert_buffer(nvim, TEXT + "ek", profile + " appended @a")
        fresh(nvim)
        send(nvim, "qaıx<Esc>qqAay<Esc>q")
        assert nvim.funcs.getreg("a") == "ix\x1bay\x1b", f"{profile}: batched qA lost prefix"
        fresh(nvim)
        send(nvim, "@a")
        assert_buffer(nvim, "xy", profile + " batched append @a")
        print(f"PASS {profile}: Turkish insert, @a, @@, 2@a, qA, batched append, repeated setup")
    finally:
        try:
            nvim.command("qa!")
        except (EOFError, OSError):
            pass


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--profile", choices=["full", "minimal", "all"], default="all")
    opts = parser.parse_args()
    binary = os.environ.get("NVIM_BIN") or shutil.which("nvim")
    assert binary, "nvim executable not found"
    for profile in (["minimal", "full"] if opts.profile == "all" else [opts.profile]):
        run(profile, binary)
