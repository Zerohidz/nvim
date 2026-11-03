# Spec — Neo-tree Git status cwd takibi

> Durum: DOĞRULANDI · Tarih: 2026-10-19

## İş gereksinimi ve kapsam

`:cd`, `gN` veya `gP` ile çalışma dizini değiştiğinde `<leader>eg` güncel reponun değişen dosyalarını göstermeli. Mevcut düzeltme talebi kapsamındaki küçük config hatası için ayrı tasarım onayı gerekmiyor. Keymap, session açma, filesystem filtreleme ve diğer mevcut kullanıcı değişiklikleri kapsam dışıdır.

## Tasarım ve bağlayıcı kararlar

- `lua/plugins/neo-tree.lua` içindeki `opts.event_handlers` üzerinden `vim_dir_changed` olayında `require("neo-tree.sources.manager").dir_changed("git_status")` çağrılır.
- Neo-tree'nin filesystem kaynağının kullandığı mekanizma tekrar kullanılır: açık kaynak yeni cwd'ye navigate eder; kapalı kaynak path'ini sıfırlayıp dirty işaretlenir, kendiliğinden açılmaz.
- `git_status.bind_to_cwd=true` tek başına reddedildi: kurulu sürüm yalnız eski `state.path` üzerinde refresh yapıyor; gerçek iki repo testi bu seçenekle eski A dosyasını göstermeye devam etti.
- Custom autocmd veya keymap değişikliği eklenmez. Git status repo root davranışı korunur; nested cwd için aynı repo bütünü gösterilir.
- Kullanıcının mevcut dirty değişiklikleri korunur.

## Kabul kriterleri ve kanıt

Fixture: `/tmp/neo-tree-cwd-check.lua`; gerçek Neovim config ve kurulu Neo-tree, iki ayrı geçici Git repo A/B, her birinde farklı untracked dosya. Kontroller gerçek plugin `state.path` ve render edilen buffer satırlarını okur; beklenen dosyanın varlığı ve diğer reponun dosyasının yokluğu birlikte doğrulanır.

| # | Given / When / Then | Kanıt |
|---|---|---|
| AC1 | Given A Git status açık, when `:cd B`, then kök B olur ve yalnız B değişikliği gösterilir. | `/tmp/neo-cwd-final.log`: `PASS cd open A -> B` |
| AC2 | Given B Git status gösterildi ve kapatıldı, when `:cd A` ve yeniden açılış, then kök A olur ve yalnız A değişikliği gösterilir. | `PASS cd closed B -> A reopen` |
| AC3 | Given filesystem içinde gerçek B node'u seçili, when mevcut `gN` callback'i ve Git status açılışı, then kök B olur. | `PASS gN callback B then git status open` |
| AC4 | Given gN ile B'ye gidildi, when mevcut `gP` callback'i ve Git status açılışı, then kök A olur. | `PASS gP callback returns A then git status open` |
| AC5 | Given A Git status, when A/nested cwd, then repo root A ve A değişikliği korunur. | `PASS nested cwd keeps A repo root` |
| AC6 | Given önceki repo dosyaları gösteriliyor, when Git dışı cwd, then eski repo dosyaları görünmez ve kök güncel cwd olur. | `PASS non-git cwd clears old repo files` |

## QA

`NEO_TEST_LOG=/tmp/neo-cwd-final.log nvim --headless -c 'luafile /tmp/neo-tree-cwd-check.lua'` komutu exit 0 ve 7 PASS üretti (initial A dahil).

Önceki davranış, handler kaldırılarak ayrı süreçte doğrulandı: `/tmp/neo-cwd-before-final.log` initial A PASS, açık `:cd A -> B` FAIL (kök A, buffer A-changed.txt). Bind seçeneğinin tek başına yetersizliği `/tmp/neo-cwd-bind.log` içinde aynı FAIL ile doğrulandı.

Bu terminal config değişikliği için CSS/computed style/browser ölçümü uygulanamaz; doğrulama canlı Neovim plugin state ve render edilmiş buffer üzerinde yapıldı. Screenshot/görsel UI doğrulaması yapılmadı. Kalıcı test ve memory değişikliği eklenmedi.
