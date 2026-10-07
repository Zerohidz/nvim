# Spec — Codex terminal navigation

> Durum: DOĞRULANDI (GUI görsel kontrolü hariç) · Tarih: 2026-10-07

## 1. İş gereksinimi
Claude Code için kullanılan C-n normal navigation akışı Codex CLI için de tmux ve Neovim/Neovide terminalinde çalışmalı.

## 2. Kapsam dışı
Codex composer Vim editing, Codex CLI upstream değişikliği, commit/push ve mevcut Claude davranışını yeniden tasarlamak.

## 3. Seçilen tasarım
Codex 0.160.1 native fullscreen transcript tuşlarına adapter: C-u/d → PageUp/PageDown, gg/G → Ctrl+Home/End, ./ → F3. tmux codex-nav table; Neovim terminal normal mode buffer mappings. C-n sadece normal navigation'a geçer; i/a ile input'a dönülür. Tam sayfa native kaydırma kullanılır.

Reddedilen alternatifler: Claude C-o + / Codex'te yanlış action; C-t overlay state tracking manuel q/C-t ve süreç restart'ında senkron kaybeder; terminal scrollback fullscreen transcript'i kapsamaz.

## 4. Bağlayıcı teknik kararlar
- D7 (2026-10-07 follow-up): Codex arama girişinde Enter yalnız query kabulü yapıp sonuç navigation mode'una geçer; CLI'ye Enter göndermez. Bu modda n → Enter (next), N → Ctrl+P (previous), i → query editing, Esc/q → search close. Query editing n/N/q harflerini ve bracketed paste metnini aynen yazar. State buffer/pane-client ve gerçek Codex process identity'ye bağlıdır; pane değişimi veya process exit/restart sonrası synthetic Enter gönderilmez. Yalnız adapter ile açılmış aramaya uygulanır; normal composer Enter/n/N etkilenmez. İki repo commit/push kullanıcı tarafından yetkilendirildi.
- D1: Claude mappings ve plain shell fallback korunur; Claude input-edit logic Codex'e uygulanmaz.
- D2: Process detection executable basename ile çalışır, args içindeki incidental codex sözcüğüne dayanmaz. Neovim shell grandchildren/node wrapper desteklenir; tmux içinde Neovim önceliklidir.
- D3: Neovim terminalinde tmux client varsa aktif pane üzerinden Codex tespiti gerekir; bağımsız tmux server process tree'de child değildir.
- D4: Codex F3 search normal mode'dan terminal mode'a geçer; doğrudan . mapping langmap olmadan da çalışır.
- D5: tmux client ve pane hedefleri script'te açıkça belirtilir; yeni navigation'da gecikmeli hedefsiz send kullanılmaz.
- D6: Repo tmux dosyaları ile aktif ~/.config/tmux kopyaları senkronlanır; config reload edilir. Neovim reload/yeni terminal ihtiyacı bildirilir.

## 5. Kabul kriterleri
| # | Given / When / Then | Doğrulama | Kanıt |
|---|---|---|---|
| AC1 | İki clean repo için pull --ff-only başarılı olur | git | İkisi up-to-date, exit 0 |
| AC2 | Codex çalışan nvim terminal normal mode'da C-u/d ve gg/G native transcript navigation byte'larını gönderir | headless nvim + PTY | tests/run-terminal-agent.sh: 83 process/live PTY checks + 13 gerçek mode/input checks geçti |
| AC3 | Codex terminalinde . ve / F3 aramayı açar, input terminale gider | headless nvim + PTY | tests/run-terminal-agent.sh: 83 process/live PTY checks + 13 gerçek mode/input checks geçti |
| AC4 | tmux Codex pane'de C-n codex-nav açar; scroll/jump/search/exit doğru çalışır | isolated tmux server/PTY | unittest: 5 tests OK; gerçek 0.160.1 Codex C-n/NAV, scroll/jump, ./F3 ve i/input doğrulandı |
| AC5 | Claude navigation ve shell fallback korunur, executable false positives engellenir | behavioral regression tests + review | Claude/shell fixtures geçti; code-reviewer + architect-review; yeni blocking bulgu yok |
| AC6 | Shell/node/wrapper ve nvim-terminal içindeki tmux aktif pane detection çalışır | process fixture + tmux test | node/wrapper, suspended/background, editor/TTY boundary ve canlı nested tmux active-pane switch geçti |
| AC7 | Repo değişiklikleri aktif tmux config ile eşleşir | cmp + source-file | ~/.config/tmux repo dizinine symlink; iki cmp exit 0; source-file exit 0; aktif codex-nav bindings okundu |
| AC8 | Adapter aramasında query n/N içerirse aynen yazılır; Enter sonrası n/N native next/previous gönderir; i edit ve Esc/q close çalışır; composer n/N/Enter korunur | PTY + canlı Codex + review | Neovim 124 checks PASS; tmux 5 tests OK (pane/process guard ve multiline paste dahil); gerçek Codex query Enter → search-nav, n/N ile eşleşmeler değişti, Find: Codex aynı kaldı; code-reviewer yeni actionable bulgu yok |

## 6. Edge case'ler
Süreç yok/bitmiş: normal fallback. Codex adı prompt/arg içinde: algılanmaz. Birden çok pane: yalnız aktif hedef. Claude input editing: ayrı kalır.

## 7. Etkilenen dosyalar
nvim lua/config/keymaps.lua; yeni lua/config/terminal_agent.lua ve anlamlı regression testleri. dotfiles tmux/home/zerohidz/.config/tmux/tmux.conf, ctrl-n.sh ve ilgili test/doc.

## 8. Riskler
Custom Codex keymap varsayılan tuşları değiştirirse adapter ayrıca güncellenmelidir. Eski inline Codex sürümlerinde fullscreen araması garanti edilmez. Neovide GUI görsel testi erişim yoksa açıkça doğrulanmadı diye raporlanır.
`ps args` argv tırnak sınırlarını korumaz: `codex "review this code"` gibi subcommand ile başlayan tek prompt yanlışlıkla noninteractive sayılabilir. Böyle başlangıçlar için `codex -- "review this code"` veya Codex açıldıktan sonra prompt yazılması kullanılabilir. Native `--no-alt-screen` bu fullscreen sözleşmesinin dışındadır.

## 9. Danışman notları
Mimari/domain/red-team: Codex adapter ayrı; direct child tespiti yetersiz; delayed tmux hedefleri sabitlenmeli; native main transcript/F3 toggle state'ten daha sağlam. Exact upstream rust-v0.160.1 keymap.rs ve transcript_view/input.rs incelendi.

## 10. QA sonucu
- Neovim: ./tests/run-terminal-agent.sh → 83 process/live PTY + 13 gerçek terminal-mode/input checks PASS.
- Dotfiles: python3 -m unittest discover -s tmux/tests -v → 5 tests OK.
- Her iki repo git diff --check → exit 0.
- Gerçek Codex 0.160.1, ayrı tmux server: C-n codex-nav, CtrlU/D gg/G navigation, . F3 Find: OpenAI; NAV_QA_DRAFT korundu. Esc/C-n/i sonrası NAV_QA_DRAFT_SUFFIX composer'a ulaştı. Prompt submit edilmedi; model task çalıştırılmadı. Test server kapatıldı.
- Code-reviewer ve architect-review bulguları (j/k input yönü, noninteractive commands, inner editor boundary) düzeltildi. ps argv quoting sınırlaması belgelendi.
- Terminal UI olduğundan Playwright DOM/computed style uygulanamaz; PTY canlı akış kullanıldı.
- Neovide GUI screenshot DOĞRULANMADI: cua.getApp("Neovide") → Computer Use server error -10005, codex app-server exited before returning a response. GUI görsel test haricindeki davranış kriterleri karşılandı.
- Mevcut Neovim terminal buffer'ları TermOpen mapping'leri aldığı için yeni terminal açılması veya Neovim/Neovide restart gerekir.

### Follow-up QA (n/N search)
- Neovim tests: 83 process/PTY + 41 gerçek search-mode/input/composer regression PASS.
- tmux tests: 5 tests OK, 9.085 s; query typing, Enter swallow, n/N bytes, edit/close, bracketed paste, pane switch, process exit/restart guard.
- Gerçek Codex 0.160.1: query Enter sonrası codex-search-nav; n ve N farklı eşleşmelere giderken query aynı kaldı. Native CLI footer kendi Enter/CtrlP hintlerini göstermeyi sürdürür; adapter tuşları dış terminal/editor tarafından uygulanır.
- Görev dışı lazy-lock.json Obsidian lock değişikliği commit kapsamına alınmadı.
