-- tests/yazi_passthrough.lua — yazi nvim terminalinde çalışırken nvim'in çaldığı Ctrl
-- tuşlarının (özellikle <C-h> gizli dosya toggle) yazi'ye geri gitmesi.
-- Gerçek yazi + gerçek PTY + gerçek terminal-mode dispatch doğrulaması.
-- Terminal-mode geçişleri yalnız serbest event loop'ta olduğu için steps/defer_fn
-- state machine kullanılır (vim.wait typeahead işlemez; bkz. terminal_search_mode.lua).
-- Çalıştırma: tests/run-yazi-passthrough.sh
local root = assert(vim.env.NVIM_TEST_ROOT)
vim.opt.rtp:prepend(root)
local passthrough = require("config.terminal_passthrough")
local agent = require("config.terminal_agent")

local checks = 0
local function check(value, label)
  assert(value, label)
  checks = checks + 1
end
local function screen()
  return table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
end
local function in_terminal_mode()
  return vim.api.nvim_get_mode().mode == "t"
end
local function shows(needle)
  return function()
    return screen():find(needle, 1, true) ~= nil
  end
end
local function hides(needle)
  return function()
    return screen():find(needle, 1, true) == nil
  end
end
local function type_keys(keys)
  vim.api.nvim_input(keys)
end

local script = {}
local function action(fn)
  script[#script + 1] = { action = fn }
end
local function wait_for(predicate, label, ms)
  script[#script + 1] = { predicate = predicate, label = label, timeout = ms or 20000 }
end

-- 1) ps satırı eşleştirme (saf) --------------------------------------------------
action(function()
  check(agent.is_yazi_command("yazi"), "is_yazi_command: yazi")
  check(agent.is_yazi_command("/opt/homebrew/bin/yazi --no-config"), "is_yazi_command: mutlak yol + arg")
  check(not agent.is_yazi_command("echo yazi"), "is_yazi_command: 'echo yazi' değil")
  check(not agent.is_yazi_command("sh -c yazi"), "is_yazi_command: sarmalayıcı değil (child aranır)")
  check(not agent.is_yazi_command("yazi-fu"), "is_yazi_command: benzer isim değil")
  check(not agent.is_yazi_command(""), "is_yazi_command: boş komut")
end)

-- 2) Fixture + terminal -----------------------------------------------------------
local ctx = {}
action(function()
  ctx.base = assert(vim.fn.system({ "mktemp", "-d" })):gsub("%s+$", "")
  check(vim.fn.writefile({ "gizli" }, ctx.base .. "/.secret.txt") == 0, ".secret.txt yazıldı")
  check(vim.fn.writefile({ "acik" }, ctx.base .. "/visible.txt") == 0, "visible.txt yazıldı")
  check(vim.fn.chdir(ctx.base) ~= -1, "test dizinine geçildi")
  check(vim.uv.fs_realpath(vim.fn.getcwd()) == vim.uv.fs_realpath(ctx.base), "cwd test klasörü")

  passthrough.setup()

  -- <C-h> fallback'inin pencere taşıması gözlemlensin diye solda ayrı bir pencere.
  vim.cmd("vsplit")
  ctx.left_win = vim.api.nvim_win_get_number(0)
  vim.cmd("wincmd l")

  -- yazi, kabuğun çocuğu olarak ve önplanda (gerçek kullanım şekli: terminalde `yazi`).
  ctx.job = vim.fn.termopen({ vim.o.shell, "-c", "yazi; exec " .. vim.o.shell })
  check(ctx.job > 0, "terminal açıldı")
  ctx.term_win = vim.api.nvim_get_current_win()
  check(ctx.term_win ~= ctx.left_win, "terminal sağ pencerede")
end)

wait_for(shows("visible.txt"), "yazi render oldu")

action(function()
  check(agent.is_yazi_running(), "is_yazi_running() yazi açıkken true")
  check(screen():find(".secret.txt", 1, true) == nil, "gizli dosya başta görünmüyor")
  -- Buffer-local override kurulmuş olmalı (global map'lere dokunulmadan).
  check(vim.fn.maparg("<C-h>", "t", false, true).buffer == 1, "<C-h> buffer-local t map")
  check(vim.fn.maparg("<C-t>", "t", false, true).buffer == 1, "<C-t> buffer-local t map")

  -- Tablodaki diğer tuşlar ham byte göndermeli (send enjekte edilerek, yan etkisiz).
  local sent = {}
  local function collect(byte)
    sent[#sent + 1] = byte
  end
  check(passthrough.handle("<C-k>", collect), "handle(<C-k>) yazi'de tüketir")
  check(passthrough.handle("<C-t>", collect), "handle(<C-t>) yazi'de tüketir")
  check(passthrough.handle("<C-h>", collect), "handle(<C-h>) yazi'de tüketir")
  check(sent[1] == "\011" and sent[2] == "\020" and sent[3] == "\008", "ham Ctrl byte'ları doğru")
  -- <C-n> bilinçli olarak passthrough değil: terminal modundan çıkış kanalı.
  check(not passthrough.handle("<C-n>", function()
    error("gönderilmemeli")
  end), "handle(<C-n>) tüketmez")
end)

-- 3) GERÇEK dispatch: terminal modunda <C-h> -> yazi gizli dosyaları göstermeli ----
action(function()
  type_keys("i")
end)
wait_for(in_terminal_mode, "terminal moduna geçildi", 6000)

action(function()
  type_keys("<C-h>")
end)
wait_for(shows(".secret.txt"), "<C-h> yazi'de gizli dosyayı GÖSTERDİ", 10000)

action(function()
  type_keys("<C-h>")
end)
wait_for(hides(".secret.txt"), "<C-h> tekrar basılınca gizledi", 10000)

-- 4) yazi'dan çık -> aynı terminalde davranış eskisi gibi -------------------------
action(function()
  vim.fn.chansend(ctx.job, "q")
end)
wait_for(function()
  return not agent.is_yazi_running()
end, "yazi kapanınca is_yazi_running() false")

action(function()
  type_keys("i")
end)
wait_for(in_terminal_mode, "kabukta yeniden terminal modunda", 6000)

action(function()
  type_keys("<C-h>")
end)
wait_for(function()
  return not in_terminal_mode()
end, "yazi yokken <C-h> terminal modundan çıktı", 8000)
wait_for(function()
  return vim.api.nvim_win_get_number(0) == ctx.left_win
end, "yazi yokken <C-h> pencereyi sola taşıdı (fallback)", 8000)

action(function()
  check(not passthrough.handle("<C-t>", function()
    error("gönderilmemeli")
  end), "yazi yokken handle tüketmez")
  vim.fn.jobstop(ctx.job)
  vim.fn.system({ "rm", "-rf", ctx.base })
  print(("yazi_passthrough: %d check PASS"):format(checks))
  vim.cmd("qa!")
end)

-- State machine -------------------------------------------------------------------
local index, deadline = 0, nil
local run
local function fail(message)
  io.stderr:write("yazi_passthrough FAIL: " .. message .. "\n--- ekran ---\n")
  for _, line in ipairs(vim.api.nvim_buf_get_lines(0, 0, -1, false)) do
    if line:match("%S") then
      io.stderr:write(line .. "\n")
    end
  end
  io.stderr:write("--- ekran sonu ---\n")
  pcall(vim.fn.jobstop, ctx.job)
  pcall(vim.fn.system, { "rm", "-rf", ctx.base or "" })
  vim.cmd("cquit 1")
end
local function advance()
  index = index + 1
  vim.defer_fn(run, 100)
end
run = function()
  local step = script[index]
  if not step then
    fail("beklenmedik step sonu")
    return
  end
  local ok, err = pcall(function()
    if step.action then
      step.action()
      deadline = nil
      advance()
    elseif step.predicate() then
      checks = checks + 1
      deadline = nil
      advance()
    else
      deadline = deadline or (vim.uv.now() + step.timeout)
      if vim.uv.now() > deadline then
        fail(step.label .. " (timeout " .. step.timeout .. "ms)")
      else
        vim.defer_fn(run, 100)
      end
    end
  end)
  if not ok then
    fail(tostring(err))
  end
end
vim.defer_fn(function()
  io.stderr:write("yazi_passthrough: TIMEOUT\n")
  vim.cmd("cquit 1")
end, 120000)
advance()
