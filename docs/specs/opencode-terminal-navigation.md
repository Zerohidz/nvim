# Spec — opencode terminal navigation

> Durum: DOĞRULANDI (gerçek opencode 2.0.25 TUI E2E dahil) · Tarih: 2026-10-12

## 1. İş gereksinimi
Codex CLI için yapılan C-n normal navigation akışı opencode TUI için de tmux ve Neovim/Neovide terminalinde çalışmalı: C-u/d yarım sayfa, j/k tam sayfa (tmux), gg/G ilk/son mesaj, i/a/q/Esc çıkış.

## 2. Kapsam dışı
opencode transcript araması (v2'de yok), model/session yönetimi, opencode upstream değişikliği, `mini` inline arayüzü ve mevcut Codex/Claude davranışının yeniden tasarımı.

## 3. Seçilen tasarım
opencode'un native session scroll keybind'lerine adapter: tmux `opencode-nav` key table + Neovim terminal normal mode buffer map'leri. C-n yalnızca normal navigation'a geçer; i/a ile input'a dönülür. Ham `C-d` (app.exit) ve `Esc` (session.interrupt) opencode'a asla gönderilmez; adapter bunları native scroll anahtarlarına çevirir.

Reddedilen alternatifler: ham C-u/C-d iletmek (C-d opencode'u kapatır, C-u input siler); SGR wheel byte'ları (opencode'un native half-page tuşları var, gerekmez); `tui.json` keybind değiştirmek (kullanıcı config'ine kalıcı bağımlılık ve upstream drift riski).

## 4. Bağlayıcı teknik kararlar
Bayt sözleşmesi (opencode 2.0.25 kurulu binary default'larıyla doğrulandı; 2.0.20'de ilk doğrulama, 2.0.25'te tekrarlandı):

| NAV eylem | opencode action | v2.0.25 default | adapter baytı (hex) | tmux key |
|---|---|---|---|---|
| C-u yarım sayfa yukarı | `session.half.page.up` | ctrl+alt+u | `1b 15` | `M-C-u` |
| C-d yarım sayfa aşağı | `session.half.page.down` | ctrl+alt+d | `1b 04` | `M-C-d` |
| k / j tam sayfa | `session.page.up/down` | pageup / pagedown | `1b 5b 35 7e` / `1b 5b 36 7e` | `PageUp` / `PageDown` |
| gg ilk mesaj | `session.first` | ctrl+g,home,alt+home | `1b 5b 31 3b 33 48` (alt+home) | `M-Home` |
| G son mesaj | `session.last` | ctrl+alt+g,end | `1b 07` | `M-C-g` |

- D1: Düz `0x15` yasak (`input.delete_to_line_start`), düz `0x04` yasak (`app.exit`), `Esc` adapter'dan gönderilmez (`session.interrupt`). Bu üçü opencode-nav dışında da davranış değiştirmez.
- D2 (tmux): `opencode-nav` + `opencode-nav-g` table; status-right `NAV`; `.`/`/` bilgi mesajı verir (arama yok); table içi C-n scrollback pager açar; i/a/q/Esc `switch-client -T root`. j/k sembolik Page tuşu, diğerleri `send-keys M-*`; hedefler mevcut client/pane'e bağlıdır.
- D3 (Neovim): TermOpen normal mode map'leri; `terminal_agent.agent()` tek `ps` taramasıyla foreground agent'ı döndürür (codex → opencode). Codex search state'ine dokunulmaz; i/a `startinsert`; `.`/`/` opencode'da opencode'a byte göndermez (Neovim default'una düşer).
- D4 (detection): executable basename + node/bun wrapper; `run`, `serve`, `mini`, `session`, `auth`, `models` gibi noninteractive subcommand'lar nav tetiklemez; öncelik Vim > Claude > Codex > opencode. tmux `identity` modu yalnız Codex pid döndürür; codex-halfpage/search guard'ları bu yüzden değişmez.
- D5 (sürüm pin'i): doğrulama `opencode --version` + binary/tui.json default kontrolü + yükseltme sonrası manuel smoke ile yapılır. v2.0.20→2.0.25'te action id'leri `messages_*` alias'ı kazandı; `session.*` isimleri ve yukarıdaki byte'lar aynı kaldı.

## 5. Kabul kriterleri
| # | Given / When / Then | Doğrulama | Kanıt |
|---|---|---|---|
| AC1 | opencode pane'de C-n `opencode-nav` açar; C-u/d/j/k/gg/G opencode'u öldürmeden doğru native byte'ları gönderir | isolated tmux + PTY | unittest 7 tests OK; `test_opencode_table_native_bytes` `1b15`/`1b04`/`1b[5~`/`1b[6~`/`1b[1;3H`/`1b07` byte'larını pinler |
| AC2 | Nav'da ham C-d/Esc opencode'a ulaşmaz; i/a/q/Esc table'dan çıkarır | isolated tmux + gerçek opencode | E2E: Esc sonrası süreç yaşadı, `.`/`/` sonrası ekran değişmedi; negatif kontrol: ham C-d opencode'u kapattı |
| AC3 | Gerçek opencode TUI'de C-u görünür şekilde yarım sayfa kaydırır | gerçek opencode 2.0.25 + PTY | E2E 21/21 PASS: G→dip, C-u ekranı değiştirdi, C-d geri aldı; tüm akış boyunca süreç yaşadı |
| AC4 | Neovim terminal normal mode'da opencode map'leri native byte'ları gönderir; Codex/Claude/shell davranışı korunur | headless nvim + PTY | `tests/run-terminal-agent.sh`: 132 process/PTY + 41 search/composer checks PASS |
| AC5 | Detection false positive üretmez; node/bun wrapper ve öncelik sırası çalışır | process fixture | tmux `test_opencode` + nvim opencode komut matrisi geçti |
| AC6 | Bayt sözleşmesi kurulu sürümün default'larıyla uyumludur | binary default kontrolü | v2.0.25: half.page=ctrl+alt+u/d, first=ctrl+g,home,alt+home, last=ctrl+alt+g,end, page=pageup/pagedown |

## 6. Edge case'ler
Süreç yok/bitmiş → normal fallback. `opencode run/serve/...` → nav yok; `mini` kapsam dışı. Birden çok client → yalnız tetikleyen client'ın table'ı değişir. Custom `tui.json` override'ı veya upgrade keybind'leri değiştirirse adapter güncellenmeli; parser legacy `ESC+harf` desteğini kaybederse `M-C-*` sembolik anahtarları yeniden doğrulanmalı.

## 7. Etkilenen dosyalar
- dotfiles: `tmux/home/zerohidz/.config/tmux/tmux.conf` (opencode-nav), `ctrl-n.sh` (opencode detection), `tmux/tests/test_codex_navigation.py`, `tmux/README.md`.
- nvim: `lua/config/terminal_agent.lua` (`agent_kind`/`agent`/`is_opencode_command`), `lua/config/keymaps.lua` (TermOpen opencode dalları), `tests/terminal_agent.lua`, `tests/run-terminal-agent.sh`, `tests/terminal-agent-fixture.c`, bu spec, `DURSUN_README.md`.

## 8. Riskler
Upstream keybind drift'i (2.0.20→2.0.25'te alias değişimi yaşandı; byte'lar sabit). Kullanıcı `tui.json` override'ı adapter'ı sessizce bozar. tmux `send-keys M-*` çıktısı tmux sürümü/`extended-keys` ayarından bağımsız ölçüldü (3.8, legacy baytlar); başka tmux sürümlerinde byte testleri koruma sağlar.

## 9. QA sonucu (2026-10-12)
- tmux: `python3 -m unittest discover -s tmux/tests -v` → 7 tests OK (13.761 s).
- Neovim: `./tests/run-terminal-agent.sh` → 132 process/PTY + 41 search/composer checks PASS.
- Gerçek opencode v2.0.25 (izole tmux server, 113 mesajlık session sadece görüntülendi; hiçbir prompt submit edilmedi): 21/21 PASS — C-n/NAV, half-page + full page + first/last, Esc/`.`, `/`, i/a/q güvenliği, negatif kontrol (ham C-d çıkış).
- Ham byte matrisi (gerçek TUI, doğrudan pane'e): legacy `1b15`/`1b04`, modifyOtherKeys (`1b[27;7;117~`) ve kitty CSI-u (`1b[117;7u`) formlarının tümü 2.0.25'te scroll etti; ctrl+g/alt+home/ctrl+alt+g ilk/son mesaja gitti.
- v2.0.25 binary default'ları bayt sözleşmesiyle uyumlu.
