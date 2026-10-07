`:MasonInstall roslyn`

komutunu çalıştırman lazım
### Codex terminal navigation

Codex CLI 0.160.1 fullscreen terminalinde (Neovim/Neovide veya terminal içindeki
aktif tmux pane) `C-n` ile normal navigation'a geç:

- `C-u` / `C-d`: transcript PageUp / PageDown.
- `gg` / `G`: transcript başı / sonu.
- `.` veya `/`: native F3 aramasını aç ve query yaz. Query içindeki `n`/`N` metindir.
- Query'de `Enter`: ilk incremental match korunarak normal search navigation'a geç.
- Search navigation'da `n` / `Shift-n`: sonraki / önceki match.
- `i` / `a`: query'yi tekrar düzenle veya composer input'a dön.
- Search'te `Esc`, `Ctrl-c` veya normal mode'da `q`: aramayı kapat.

Search state yalnız adapter'ın açtığı aramaya ve gerçek Codex process PID'sine
bağlıdır; process değişince veya terminal kapanınca temizlenir. Composer'da
`n`/`N` ve `Enter` mevcut davranışını korur.

Claude Code için mevcut navigation/input editing devam eder. Detection yalnız
foreground interactive Codex executable veya Node CLI wrapper'ını kabul eder;
`codex exec`, `review`, `app-server` gibi komutlar kapsam dışıdır. Nested tmux'ta
terminalin gerçek client PID'si ve o client'ın aktif pane'i kullanılır. İçeride
başka bir Neovim/Vim çalışıyorsa navigation'ı o editor yönetir. Process kontrolü
`ps args` kullandığı için whitespace içeren argv değerleri platformun düzleştirdiği
çıktıya bağlıdır. Custom Codex keymap kullanılıyorsa adapter byte'ları uyarlanmalıdır.

Test: `./tests/run-terminal-agent.sh` (Neovim, C compiler ve isteğe bağlı tmux).
Headless PTY testleri process detection, Claude/shell regression, native byte'lar,
gerçek terminal mode geçişi ve arama input'unu doğrular. Mevcut terminal buffer'ları
mapping'leri `TermOpen` sırasında aldığı için config değişiminden sonra yeni terminal
buffer aç veya Neovim/Neovide'yi yeniden başlat.
