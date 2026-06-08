---@diagnostic disable: undefined-global

vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")

-- Türkçe klavye düzeltmesini yükle
require("config.turkish_keys").setup()

-- #############################################################################
-- # Neovim Türkçe Q Klavye Normal Mod Optimizasyonu (Tam Kapsamlı)
-- #############################################################################
-- make deletion shortcuts not copy the deleted content into clipboard

-- =========================
-- SAFE DELETE (black hole)
-- =========================

-- Tek karakter sil
vim.keymap.set("n", "x", '"_x', opts)

-- Normal mode delete
vim.keymap.set("n", "d", '"_d', opts)
vim.keymap.set("n", "dd", '"_dd', opts)

-- Visual mode delete
vim.keymap.set("v", "d", '"_d', opts)

-- Change (c) de clipboard bozmasın
vim.keymap.set("n", "c", '"_c', opts)
vim.keymap.set("v", "c", '"_c', opts)

-- s
vim.keymap.set("n", "s", '"_s')
vim.keymap.set("v", "s", '"_s')

-- =========================
-- CUT (bilinçli kesme)
-- =========================

-- Normal mode cut
vim.keymap.set("n", "<leader>d", "d", opts)
vim.keymap.set("n", "<leader>dd", "dd", opts)

-- Visual mode cut
vim.keymap.set("v", "<leader>d", "d", opts)

-- Change + cut
vim.keymap.set("n", "<leader>c", "c", opts)
vim.keymap.set("v", "<leader>c", "c", opts)

-- Cut s
vim.keymap.set("n", "<leader>s", "s")
vim.keymap.set("v", "<leader>s", "s")

-- #############################################################################
-- # Küçük kişisel ayarlar
-- #############################################################################

-- RelativeNumber gösterimini aç -----------------------------------------------
-- Başlangıç durumu
vim.opt.number = true
vim.opt.relativenumber = true

-- Insert mode'a girince kapat
vim.api.nvim_create_autocmd("InsertEnter", {
  callback = function()
    vim.opt.relativenumber = false
  end,
})

-- Insert mode'dan çıkınca aç
vim.api.nvim_create_autocmd("InsertLeave", {
  callback = function()
    vim.opt.relativenumber = true
  end,
})

-- Set spellcheck off
vim.api.nvim_create_autocmd({ "BufEnter", "BufWinEnter" }, {
  callback = function()
    vim.opt_local.spell = false
  end,
})

-- #############################################################################
-- # Terminal emulator modu (NVIM_AS_TERM=1 ile başlatılınca tam ekran terminal)
-- #############################################################################
if vim.env.NVIM_AS_TERM == "1" then
  vim.opt.shortmess:append("I")

  -- terminal buffer numarasını burada tutuyoruz, <leader>T ile geri dönmek için
  local term_buf

  vim.api.nvim_create_autocmd("VimEnter", {
    callback = function()
      vim.schedule(function()
        vim.cmd("terminal")
        term_buf = vim.api.nvim_get_current_buf()
        vim.bo[term_buf].buflisted = false -- bufferline/tab listesinde görünmesin
        vim.cmd("startinsert")
      end)
    end,
  })
  vim.api.nvim_create_autocmd("TermOpen", {
    callback = function()
      vim.wo.number = false
      vim.wo.relativenumber = false
    end,
  })
  vim.api.nvim_create_autocmd("TermClose", {
    callback = function() vim.cmd("qa!") end,
  })

  -- terminalin İÇİNDEKİ shell'in gerçek anlık dizinini /proc üzerinden oku
  -- (OSC7/shell-integration'a bağımlı değil, %100 güvenilir)
  local function term_real_cwd()
    if not (term_buf and vim.api.nvim_buf_is_valid(term_buf)) then
      return nil
    end
    local pid = vim.b[term_buf].terminal_job_pid
    return pid and vim.uv.fs_realpath("/proc/" .. pid .. "/cwd")
  end

  -- aynı pencerede, terminalin bulunduğu dizini kök alarak dosya gezgini
  -- görünümüne geç. Terminal arka planda canlı + gizli kalır.
  local function go_explorer_layout()
    local cwd = term_real_cwd() or vim.uv.cwd()
    vim.cmd("cd " .. vim.fn.fnameescape(cwd))
    vim.cmd("enew")
    vim.wo.number = true
    vim.wo.relativenumber = true
    require("neo-tree.command").execute({ toggle = true, dir = cwd })
  end

  local function go_terminal()
    if term_buf and vim.api.nvim_buf_is_valid(term_buf) then
      vim.api.nvim_set_current_buf(term_buf)
      vim.cmd("startinsert")
    end
  end

  -- <C-g> ("geç"): tek tuş, iki yönlü toggle. Terminaldeysen explorer'a,
  -- oradaysan terminale geçer (terminal-insert modunda da çalışır, mod değiştirmeye gerek yok).
  vim.keymap.set({ "n", "t" }, "<C-g>", function()
    if vim.bo.buftype == "terminal" then
      if vim.fn.mode() == "t" then
        vim.cmd("stopinsert")
      end
      go_explorer_layout()
    else
      go_terminal()
    end
  end, { desc = "AS_TERM: terminal <-> dosya gezgini toggle" })
end
