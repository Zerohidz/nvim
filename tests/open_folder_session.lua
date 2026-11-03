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
local gui_env = {} -- GUI tespiti testlerde açıkça enjekte edilir

-- 1) Argüman üretimi -------------------------------------------------------------
eq(opener.plan("/Users/dev/proje", tmux_env), {
  kind = "tmux",
  cmd = { "tmux", "new-window", "-c", "/Users/dev/proje", "-n", "proje", "nvim '+Neotree focus'" },
}, "tmux argv")

eq(opener.plan("/Users/dev/proje", gui_env, true), {
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
local tricky = "/tmp/a b/çğüş ö \"'"
eq(opener.plan(tricky, tmux_env).cmd[4], tricky, "tmux -c yolunda bozulma yok")
eq(opener.plan(tricky, gui_env, true).cmd[3], tricky, "neovide --chdir yolunda bozulma yok")
-- Yol, tmux shell-command string'inin içine asla girmiyor.
check(not opener.plan(tricky, tmux_env).cmd[6]:find(tricky, 1, true), "yol shell string'ine sızmıyor")
-- TMUX boş string ise tmux'ta sayılmayız.
check(opener.plan("/tmp/x", { TMUX = "" }).kind == "kitty", "TMUX='' terminal dalı")

eq(opener.plan("/Users/dev/proje", tmux_env, true).kind, "neovide", "Neovide miras alınmış TMUX'tan önce gelir")
eq(opener.plan(tricky, {}, false), {
  kind = "kitty",
  cmd = { "open", "-na", "kitty", "--args", "--directory", tricky, vim.fn.exepath("nvim"), "+Neotree focus" },
}, "terminal Kitty argv: özel karakterli yol tek argüman")

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
for _, binary in ipairs({ "open", "kitty", "nvim" }) do
  check(vim.fn.writefile(stub, stub_dir .. "/" .. binary) == 0, binary .. " stub yazıldı")
end
vim.fn.system({
  "chmod",
  "+x",
  stub_dir .. "/tmux",
  stub_dir .. "/neovide",
  stub_dir .. "/open",
  stub_dir .. "/kitty",
  stub_dir .. "/nvim",
})
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
check(opener.open(base .. "/proje", {}, true), "neovide dalı ok döndürdü")
eq(
  read_record(),
  { select(2, unpack(opener.plan(base .. "/proje", gui_env, true).cmd)) },
  "neovide gerçek spawn argv'sı"
)

vim.fn.delete(record)
local special_dir = base .. "/boş luk ' \" ç"
check(vim.fn.mkdir(special_dir, "p") == 1, "özel karakterli fixture")
check(opener.open(special_dir, {}, false), "terminal dalı ok döndürdü")
eq(read_record(), { select(2, unpack(opener.plan(special_dir, {}, false).cmd)) }, "terminal gerçek spawn argv'sı")

-- Hata yolu: binary PATH'te yoksa hata göster, false döndür (sessiz düşme yok).
local notices = {}
local saved_notify = vim.notify
vim.notify = function(msg, level)
  notices[#notices + 1] = { msg = msg, level = level }
end
vim.env.PATH = "/nonexistent-dir-only"
check(not opener.open(base .. "/proje", {}, true), "binary yoksa false")
check(notices[#notices].level == vim.log.levels.ERROR, "binary yoksa ERROR bildirimi")
notices = {}
check(not opener.open(base .. "/yok", {}), "silinmiş dizin false")
check(notices[#notices].msg:find("silinmiş") ~= nil, "silinmiş dizin bildirimi")
notices = {}
opener.open_node(nil)
check(notices[#notices].level == vim.log.levels.ERROR, "open_node node'suz ERROR")
-- Launcher mevcut olsa da kitty veya nvim eksikse yeni oturum başlamaz.
vim.env.PATH = stub_dir
for _, binary in ipairs({ "kitty", "nvim" }) do
  vim.fn.rename(stub_dir .. "/" .. binary, stub_dir .. "/" .. binary .. ".off")
  notices = {}
  check(not opener.open(base .. "/proje", {}, false), binary .. " yoksa terminal açılmaz")
  check(notices[#notices].msg:find("'" .. binary .. "'", 1, true) ~= nil, binary .. " eksikliği bildirildi")
  vim.fn.rename(stub_dir .. "/" .. binary .. ".off", stub_dir .. "/" .. binary)
end

-- open başarılı spawn edilip sonra hata verebilir (örn. uygulama açılamaması).
vim.fn.writefile({ "#!/bin/sh", "echo launcher-failed >&2", "exit 7" }, stub_dir .. "/open")
notices = {}
check(opener.open(base .. "/proje", {}, false), "launcher spawn başarılı")
check(
  vim.wait(3000, function()
    for _, notice in ipairs(notices) do
      if notice.level == vim.log.levels.ERROR and notice.msg:find("launcher-failed", 1, true) then
        return true
      end
    end
    return false
  end),
  "open nonzero çıkışı ERROR olarak bildirildi"
)

-- gN: aynı oturumda global cwd + public Neo-tree execute, process yok.
local saved_cwd = vim.fn.getcwd()
local saved_command = package.loaded["neo-tree.command"]
local saved_system = vim.system
local executed
package.loaded["neo-tree.command"] = {
  execute = function(opts)
    executed = opts
  end,
}
vim.system = function()
  error("cd_node yeni process açmamalı")
end
check(opener.cd_node({ type = "directory", path = special_dir }), "gN directory başarılı")
eq(vim.uv.fs_realpath(vim.fn.getcwd()), vim.uv.fs_realpath(special_dir), "gN global cwd")
eq(executed, { source = "filesystem", action = "focus", dir = norm(special_dir) }, "gN public Neo-tree root/focus")
check(opener.cd_node({ type = "file", path = base .. "/proje/src/main.go" }), "gN file parent başarılı")
eq(vim.uv.fs_realpath(vim.fn.getcwd()), vim.uv.fs_realpath(base .. "/proje/src"), "gN file parent cwd")
local previous_execute = executed
notices = {}
check(not opener.cd_node(nil), "gN nil reddedildi")
check(not opener.cd_node({ type = "directory", path = base .. "/yok" }), "gN silinmiş hedef reddedildi")
check(executed == previous_execute, "gN geçersiz node tree'yi değiştirmez")
eq(
  vim.uv.fs_realpath(vim.fn.getcwd()),
  vim.uv.fs_realpath(base .. "/proje/src"),
  "gN geçersiz node cwd'yi değiştirmez"
)
check(notices[#notices].level == vim.log.levels.ERROR, "gN invalid ERROR")
vim.system = saved_system
package.loaded["neo-tree.command"] = saved_command
vim.api.nvim_set_current_dir(saved_cwd)
vim.notify = saved_notify
vim.env.PATH = saved_path
vim.env.STUB_OUT = saved_stub_out
vim.fn.system({ "rm", "-rf", base })

print(("open_folder_session: %d check PASS"):format(checks))
