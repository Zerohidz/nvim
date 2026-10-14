-- tests/open_folder_session.lua — neo-tree "N" (klasörde yeni oturum) testleri.
-- Çalıştırma: tests/run-open-folder-session.sh
local root = assert(vim.env.NVIM_TEST_ROOT)
vim.opt.rtp:prepend(root)
local opener = require("config.open_folder_session")

local checks = 0
local function check(value, label)
  assert(value, label)
  checks = checks + 1
end
local function eq(actual, expected, label)
  local a, b = vim.json.encode(actual), vim.json.encode(expected)
  assert(a == b, label .. "\n  beklenen: " .. b .. "\n  gelen  : " .. a)
  checks = checks + 1
end
-- ":p" dizinlere sondaki "/" ekler; beklentiler normalize edilmiş haliyle karşılaştırılır.
local function norm(p)
  local n = vim.fn.fnamemodify(p, ":p"):gsub("/+$", "")
  return n == "" and "/" or n
end

local tmux_env = { TMUX = "/private/tmp/tmux-1000/default,1234,0" }
local gui_env = {} -- TMUX yok

-- 1) Argüman üretimi -------------------------------------------------------------
eq(opener.plan("/Users/dev/proje", tmux_env), {
  kind = "tmux",
  cmd = { "tmux", "new-window", "-c", "/Users/dev/proje", "-n", "proje", "nvim '+Neotree focus'" },
}, "tmux argv")

eq(opener.plan("/Users/dev/proje", gui_env), {
  kind = "neovide",
  cmd = { "neovide", "--chdir", "/Users/dev/proje", "--", "+Neotree focus" },
}, "neovide argv")

-- Kök dizinde ":t" boş döner; -n verilmez (tmux boş isim kabul etmez).
eq(opener.plan("/", tmux_env).cmd, {
  "tmux",
  "new-window",
  "-c",
  "/",
  "nvim '+Neotree focus'",
}, "tmux argv kök dizin")

-- Boşluklu/Türkçe karakterli yol argv'da bozulmadan kalmalı (shell quoting yapılmıyor).
local tricky = "/tmp/a b/çğüş ö"
eq(opener.plan(tricky, tmux_env).cmd[4], tricky, "tmux -c yolunda bozulma yok")
eq(opener.plan(tricky, gui_env).cmd[3], tricky, "neovide --chdir yolunda bozulma yok")
-- Yol, tmux shell-command string'inin içine asla girmiyor.
check(not opener.plan(tricky, tmux_env).cmd[6]:find(tricky, 1, true), "yol shell string'ine sızmıyor")
-- TMUX boş string ise tmux'ta sayılmayız.
check(opener.plan("/tmp/x", { TMUX = "" }).kind == "neovide", "TMUX='' GUI dalı")

-- 2) Yol çözümleme ---------------------------------------------------------------
local base = assert(vim.fn.system({ "mktemp", "-d" })):gsub("%s+$", "")
check(vim.fn.mkdir(base .. "/proje/src", "p") == 1, "fixtures oluşturuldu")
check(vim.fn.writefile({ "x" }, base .. "/proje/src/main.go") == 0, "fixture dosya")

local abs = opener.resolve(base .. "/proje")
check(abs == norm(base .. "/proje"), "klasör mutlak yola çözülür")
check(abs == norm(base .. "/proje/"), "sondaki '/' temizlenir (tmux -c / --chdir temiz yol alır)")
check(opener.resolve("/") == "/", "kök dizin '/' olarak kalır")
local nil_path, miss_err = opener.resolve(base .. "/yok")
check(nil_path == nil and miss_err:find("silinmiş") ~= nil, "silinmiş dizin reddedilir")
check(opener.resolve(nil) == nil, "nil yol reddedilir")
check(opener.resolve("") == nil, "boş yol reddedilir")

-- Node çevirisi: klasör kendi yolu, dosya parent'ı, buffers kaynağı node.path kullanır.
local folder = opener.node_folder({
  type = "directory",
  get_path = function()
    return base .. "/proje"
  end,
})
check(folder == norm(base .. "/proje"), "directory node kendi klasörü")
local from_file = opener.node_folder({
  type = "file",
  get_path = function()
    return base .. "/proje/src/main.go"
  end,
})
check(from_file == norm(base .. "/proje/src"), "file node parent klasörü")
local from_buffer = opener.node_folder({ type = "file", path = base .. "/proje/src/main.go" })
check(from_buffer == norm(base .. "/proje/src"), "path alanlı node (buffers/git_status)")
check(opener.node_folder(nil) == nil, "node yoksa hata")
check(opener.node_folder({
  type = "directory",
  get_path = function()
    return base .. "/yok"
  end,
}) == nil, "silinmiş node hedefi reddedilir")

-- 3) Gerçek spawn: argv'yı kayıt dosyasına yazan sahte tmux/neovide ----------------
local stub_dir = base .. "/bin"
local record = base .. "/argv.txt"
check(vim.fn.mkdir(stub_dir, "p") == 1, "stub klasörü")
local stub = { "#!/bin/sh", 'printf "%s\\n" "$0" "$@" > "$STUB_OUT"', "exit 0" }
check(vim.fn.writefile(stub, stub_dir .. "/tmux") == 0, "tmux stub yazıldı")
check(vim.fn.writefile(stub, stub_dir .. "/neovide") == 0, "neovide stub yazıldı")
vim.fn.system({ "chmod", "+x", stub_dir .. "/tmux", stub_dir .. "/neovide" })
check(vim.fn.executable(stub_dir .. "/tmux") == 1, "tmux stub çalıştırılabilir")

local saved_path = vim.env.PATH
local saved_stub_out = vim.env.STUB_OUT
vim.env.PATH = stub_dir .. ":" .. vim.env.PATH
vim.env.STUB_OUT = record

local function read_record()
  for _ = 1, 200 do
    if vim.fn.filereadable(record) == 1 then
      local lines = vim.fn.readfile(record)
      -- $0 = exec edilen mutlak yol (argv[1] ile birebir aynı olmak zorunda değil),
      -- karşılaştırmayı gerçek argümanlar üzerinden yapıyoruz.
      if #lines > 1 then
        return { select(2, unpack(lines)) }
      end
    end
    vim.wait(50)
  end
  error("stub argv yazmadı: " .. record)
end

check(opener.open(base .. "/proje", { TMUX = "x,1,0" }), "tmux dalı ok döndürdü")
eq(read_record(), { select(2, unpack(opener.plan(base .. "/proje", tmux_env).cmd)) }, "tmux gerçek spawn argv'sı")

vim.fn.delete(record)
check(opener.open(base .. "/proje", {}), "neovide dalı ok döndürdü")
eq(read_record(), { select(2, unpack(opener.plan(base .. "/proje", gui_env).cmd)) }, "neovide gerçek spawn argv'sı")

-- Hata yolu: binary PATH'te yoksa hata göster, false döndür (sessiz düşme yok).
local notices = {}
local saved_notify = vim.notify
vim.notify = function(msg, level)
  notices[#notices + 1] = { msg = msg, level = level }
end
vim.env.PATH = "/nonexistent-dir-only"
check(not opener.open(base .. "/proje", {}), "binary yoksa false")
check(notices[#notices].level == vim.log.levels.ERROR, "binary yoksa ERROR bildirimi")
notices = {}
check(not opener.open(base .. "/yok", {}), "silinmiş dizin false")
check(notices[#notices].msg:find("silinmiş") ~= nil, "silinmiş dizin bildirimi")
notices = {}
opener.open_node(nil)
check(notices[#notices].level == vim.log.levels.ERROR, "open_node node'suz ERROR")
vim.notify = saved_notify
vim.env.PATH = saved_path
vim.env.STUB_OUT = saved_stub_out
vim.fn.system({ "rm", "-rf", base })

print(("open_folder_session: %d check PASS"):format(checks))
