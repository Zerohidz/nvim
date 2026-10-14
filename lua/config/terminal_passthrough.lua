-- Yazi, nvim terminalinin İÇİNDE çalışıp çıkabiliyor: aynı terminal buffer'ında kabuk ile
-- yazi arasında geçiş olduğu için "bu buffer'da yazi var mı" cevabı tuş anında verilmeli.
-- terminal_agent'ın codex/opencode için kullandığı desen: tuş başına tek `ps` anlık görüntüsü.
--
-- Sorun: keymaps.lua terminal modunda <C-h>/<C-k>/<C-t>/<C-v> tuşlarını nvim için çalıyor,
-- yazi'nin kendi bind'leri (gizli dosyalar, kill-eol, Ghostty/Neovide aç) hiç görülmüyor.
-- Bu modül sadece yazi önplandayken o tuşları ham byte olarak job'a geri gönderir;
-- yazi yokken davranış birebir eski haliyle devam eder.
-- Spec: docs/specs/yazi-terminal-passthrough.md
local M = {}

-- yazi'de bind'li + nvim'in t modunda çaldığı tuşlar.
-- Bilinçli olarak LİSTEDE YOK:
--   <C-n>  terminal modundan çıkış kanalı (keymaps.lua) -> nvim'de kalmaya devam eder
--   <C-j>/<C-l>  yazi'de bind'siz -> pencere gezinmesi korunur
--   <C-=>/<C-->/<C-0>/<D-v>/<S-CR>  zoom/yapıştırma, yazi kullanmıyor
local keys = {
  ["<C-h>"] = {
    byte = "\008", -- yazi: hidden toggle (mgr) / backspace (input)
    fallback = function()
      vim.api.nvim_input("<C-\\><C-n><C-w>h")
    end,
  },
  ["<C-k>"] = {
    byte = "\011", -- yazi input: kill eol
    fallback = function()
      vim.api.nvim_input("<C-\\><C-n><C-w>k")
    end,
  },
  ["<C-t>"] = {
    byte = "\020", -- yazi: Open Ghostty here
    fallback = function()
      vim.cmd("1ToggleTerm")
    end,
  },
  ["<C-v>"] = {
    byte = "\022", -- yazi: Open Neovide here
    fallback = function()
      vim.api.nvim_paste(vim.fn.getreg("+"), true, -1)
    end,
  },
}

--- yazi bu terminal buffer'ında önplandaysa tuşu ham byte olarak job'a yollar.
---@param lhs string "<C-h>" biçiminde
---@param send? fun(byte: string) test için; default nvim_chan_send
---@return boolean consumed yazi mi tüketti (false ise fallback'e düş)
function M.handle(lhs, send)
  local key = keys[lhs]
  if not key then
    return false
  end
  if not require("config.terminal_agent").is_yazi_running() then
    return false
  end
  local chan = vim.b.terminal_job_id
  if not chan then
    return false
  end
  (send or function(byte)
    vim.api.nvim_chan_send(chan, byte)
  end)(key.byte)
  return true
end

--- Terminal buffer'larına buffer-local t-modu override'ları kurar. Global map'ler
--- olduğu gibi kalır; buffer-local olduğu için yalnız o terminalde devreye girer.
function M.setup()
  local group = vim.api.nvim_create_augroup("yazi_terminal_passthrough", { clear = true })
  vim.api.nvim_create_autocmd("TermOpen", {
    group = group,
    desc = "Yazi çalışırken çalınan Ctrl tuşlarını yazi'ye geri ver",
    callback = function(args)
      if not vim.api.nvim_buf_is_valid(args.buf) then
        return
      end
      for lhs, key in pairs(keys) do
        -- <C-v> paste'i yalnız Neovide'da map'li (keymaps.lua); orada yoksa
        -- zaten çalınmıyor, override kurmaya gerek yok.
        if not (lhs == "<C-v>" and not vim.g.neovide) then
          vim.keymap.set("t", lhs, function()
            if M.handle(lhs) then
              return
            end
            key.fallback()
          end, { buffer = args.buf, nowait = true, silent = true, desc = "Yazi passthrough / " .. lhs })
        end
      end
    end,
  })
end

return M
