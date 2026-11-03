# Spec — Yazi terminal passthrough (`<C-h>` gizli dosya toggle)

> Durum: DOĞRULANDI
> Tarih: 2026-10-14 · Onaylayan: dursun.korkmaz · Ortam: nvim 0.12.6, yazi 26.9.1

## 1. İş gereksinimi

Yazi'yi Neovim terminalinde kullanırken yazi'nin kendi kısayolları Neovim tarafından
çalınmasın — özellikle `Ctrl-h` ile gizli dosyaları göster/gizle çalışsın. Yazi
çalışmıyorken mevcut Neovim kısayollarının davranışı **birebir** korunmalı.

Ctrl-H/J/K/L, Yazi çalışan terminalde yalnız normal modda pencere değiştirmeli;
terminal modunda ham tuş Yazi'ye gitmeli. Diğer buffer'larda insert modunda da
pencere gezinmesi çalışmalı.

## 2. Kapsam dışı

- Yazi config'ini değiştirmek (`~/.config/yazi/keymap.toml` — kısayol yazi'de `<C-h>` kalır).
- Codex/opencode navigasyon adapter'larının davranışı (yalnız ortak `detect_in_buffer`
  helper'ı paylaşılmıştır, eşleştirme mantığı değişmemiştir).
- tmux içindeki yazi (ayrı PTY/client zinciri; mevcut `detect` tmux punte mantığına bırakılır).
- `<C-n>` gibi "terminal modundan çıkış" tuşlarını yazi'ye vermek.

## 3. Seçilen tasarım

Yazi aynı terminal buffer'ının içinde başlayıp çıktığı için tespit **tuş anında** yapılır:
`config/terminal_agent`'ın tek `ps` anlık görüntüsüyle yaptığı foreground-process
taraması `is_yazi_command` eşleştiricisiyle genişletildi. `config/terminal_passthrough`
`TermOpen`'da o buffer'a buffer-local `t`-modu override'ları kurar; tuş basıldığında yazi
önplandaysa ham Ctrl byte'ı `nvim_chan_send` ile job'a gider, değilse orijinal eylem
(fallback) çalışır. Global terminal mapping'leri korunur; insert moduna Ctrl-H/J/K/L
pencere gezinme eşlemeleri eklenir.

**Reddedilen alternatifler ve neden:**

| Alternatif | Neden reddedilir |
|---|---|
| `TermOpen`'da terminalin komutuna bakıp kalıcı unmap | Kullanıcı kabukta `y` yazıp yazi'yi elle başlatıyor; launch command sadece shell, tespit imkânsız |
| Tüm terminallerde `<C-h>` unmap | Kabukta pencere gezinmesi kaybolur |
| Yazi'de tuşu değiştirmek | Sorun nvim tarafında; diğer Ctrl çakışmaları da durur |
| Sadece `<C-h>` yaması | `<C-t>`/`<C-k>`/`<C-v>` aynı hata sınıfı; aynı liste içinde tek noktada çözülür |

## 4. Bağlayıcı teknik kararlar

| # | Karar | Gerekçe | Nerede uygulanacak |
|---|---|---|---|
| D1 | Tespit tuş anında, yazi'nin job pid ağacında foreground (`ps` `+`) eşleşmesiyle | Yazi aynı buffer'da dynamic olarak başlayıp bitiyor | `terminal_agent.is_yazi_running` |
| D2 | Yazi "agent" değildir: `agent_kind()` yazi döndürmez, ayrı matcher kullanılır | Codex/opencode navigasyon dalları yazi'ye uygulanmaz | `terminal_agent.is_yazi_command` |
| D3 | Override'lar buffer-local, `TermOpen`'da, `nowait` | Global yüzey değişmez; sadece ilgili terminalde etkili | `terminal_passthrough.setup` |
| D4 | Passthrough kümesi `{<C-h>, <C-j>, <C-k>, <C-l>, <C-t>, <C-v>}`; ham byte 0x08/0x0A/0x0B/0x0C/0x14/0x16 | Yazi terminalinde gezinme yalnız normal modda; diğer Ctrl kısayolları korunur | `terminal_passthrough.keys` |
| D5 | `<C-n>` passthrough **değil** | Terminal modundan çıkış kanalı; kullanıcı tuzağa düşmesin | `keys` tablosuna almama |
| D6 | Ctrl-H/J/K/L Yazi terminal modunda passthrough; normal modda gezinme | Kullanıcının dört yönde aynı kapsam talebi | `keys` ve insert keymaps |
| D7 | `<C-v>` override yalnız `vim.g.neovide` varsa | Paste map'i sadece Neovide'da var; yoksa çalınan tuş yok | `setup` |
| D8 | Gezinme fallback'ları termcode dönüşümü + non-remap `nvim_feedkeys` kullanır | Ctrl-N eşlemesine tekrar girilmez; kabukta dört yönde gezinme korunur | `keys[k].fallback` |
| D9 | `agent()` ortak `detect_in_buffer(match)` üzerinden çalışır | Kod tekrarı yok; mevcut 132+41 check'lik suite korunur | `terminal_agent` |

## 5. Kabul kriterleri

| # | Given / When / Then | Nasıl doğrulanır | Kanıt |
|---|---|---|---|
| AC1 | Given yazi önplanda ve terminal modu, when `<C-h>` basılır, then yazi gizli dosyaları gösterir | gerçek PTY + gerçek yazi + gerçek t-modu dispatch, ekran içeriği | `run-yazi-passthrough.sh`: "<C-h> yazi'de gizli dosyayı GÖSTERDİ" PASS |
| AC2 | Given gizli dosyalar açık, when tekrar `<C-h>`, then tekrar gizlenir | aynı | "tekrar basılınca gizledi" PASS |
| AC3 | Given yazi çalışmıyor, when `<C-h>`, then terminal modundan çıkıp pencere sola taşınır | state-machine pencere/pence kontrolü | 2 check PASS (fallback) |
| AC4 | Given yazi önplanda, when `<C-k>`/`<C-t>`/`<C-h>`, then ham byte 0x0B/0x14/0x08 gönderilir | `handle()` + enjekte `send` | "ham Ctrl byte'ları doğru" PASS |
| AC5 | `<C-n>` hiçbir koşulda yazi'ye gönderilmez | `handle("<C-n>")` false | PASS |
| AC6 | Given yazi açık, when `<C-t>`, then `<cmd>1ToggleTerm` çalışmaz (yazi'ye gider) | AC4 + `handle` dönüşü | PASS |
| AC7 | Given yazi kapalı, when `handle("<C-t>")`, then false (fallback'e düşer) | test | PASS |
| AC8 | `is_yazi_command`: `yazi`, `/opt/homebrew/bin/yazi --no-config` true; `echo yazi`, `sh -c yazi`, `yazi-fu`, `""` false | unit test | 6 check PASS |
| AC9 | Override'lar buffer-local; global map'ler bozulmaz | `maparg(...).buffer == 1` | "<C-h>/<C-t> buffer-local t map" PASS |
| AC10 | Mevcut Codex/opencode adapter suite'i etkilenmez | `run-terminal-agent.sh` | `PASS: 132 checks` + `PASS: 41 checks` |
| AC11 | Yazi terminal modunda Ctrl-J/K/L pencere değiştirmez ve ham byte gönderir | Gerçek Yazi/PTY dispatch + byte kontrolü | `run-yazi-passthrough.sh` |
| AC12 | Yazi normal modunda Ctrl-H/J/K/L komşu pencereye geçer | Her yönde gerçek split + tuş dispatch | `run-yazi-passthrough.sh` |
| AC13 | Başka buffer insert modundayken Ctrl-H/J/K/L komşu pencereye geçer | Yazi aynı anda açıkken gerçek split + dispatch | `run-yazi-passthrough.sh` |
| AC14 | Yazi kapandıktan sonra aynı terminalde Ctrl-J/K/L gezinmesi geri gelir | Her yönde gerçek split + terminal dispatch | `run-yazi-passthrough.sh` |

## 6. Edge case'ler

| Durum | Beklenen davranış |
|---|---|
| yazi'dan çıkılıp aynı terminalde kabuğa dönülmesi | Sonraki tuşlar fallback'e döner (AC3/AC7) |
| `vim.b.terminal_job_id` yok | `handle` false → fallback |
| Yazi child süreçlerle çalışıyor (previewer vb.) | Eşleşen süreç foreground yazi'nin kendisi; `detect` ağacı ziyaret eder |
| Neovide dışı terminal (GUI yok) | `<C-v>` override kurulmaz |
| İçeride başka nvim/vim çalışıyorsa | `detect` o alt ağaca girmez (mevcut koruma korunur) |
| Yazi input modunda `<C-h>` | Aynı byte → yazi'de backspace |

## 7. Etkilenen dosyalar

**Değişecek:**

| Dosya | Ne değişiyor |
|---|---|
| `lua/config/terminal_agent.lua` | `is_yazi_command`, `detect_in_buffer` (refactor), `is_yazi_running` |
| `lua/config/autocmds.lua` | `require("config.terminal_passthrough").setup()` |
| `DURSUN_README.md` | Dokümantasyon |

**Yeni:**

| Dosya | Amacı |
|---|---|
| `lua/config/terminal_passthrough.lua` | keys tablosu, `handle`, `setup` (TermOpen override) |
| `tests/yazi_passthrough.lua` | 30 check: gerçek yazi/PTY/t-modu dispatch + fallback |
| `tests/run-yazi-passthrough.sh` | Runner (`yazi` yoksa atlar) |

## 8. Riskler

| Risk | Etki | Azaltma |
|---|---|---|
| Tuş başına `ps -Aww` maliyeti | Terminalde tuş gecikmesi | Mevcut codex/opencode adapter'larıyla aynı desen; tek tarama, yalnız t-modu override tuşlarında |
| Yazi'nin `<C-x>`/`<C-t>` gibi tuşlarda kitty-keyboard CSI u beklemesi | Yanlış yorumlanma | Legacy Ctrl byte'ları tüm terminallerde geçerli; AC1 ile gerçek yazi'de doğrulandı |
| Gelecekte yeni nvim t-modu Ctrl map'i eklenirse | Yeni çakışma | `keys` tablosuna satır eklemek yeterli; README'de not |

## 9. Danışman notları

- Kullanıcı isteğiyle danışman turları atlandı. Test yazımı sırasında bulunan gerçek
  kısıtlar: headless `:startinsert` terminal moduna sokmuyor ve `vim.wait` typeahead
  işlemez → testler `defer_fn` state machine + `nvim_input` ile yazıldı
  (`tests/terminal_search_mode.lua` deseni).

## 10. QA sonucu

- `./tests/run-yazi-passthrough.sh` → `yazi_passthrough: 30 check PASS`
- `./tests/run-terminal-agent.sh` → `PASS: 132 checks` + `PASS: 41 checks` (regresyon yok)
- Karşılanmayan kriter: yok.
