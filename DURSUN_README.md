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

### opencode terminal navigation

opencode v2 TUI'sinde (Neovim/Neovide veya aktif tmux pane) `C-n` ile normal
navigation'a geç:

- `C-u` / `C-d`: yarım sayfa yukarı / aşağı (native Ctrl+Alt+U/D).
- `gg` / `G`: ilk / son mesaj (Alt+Home / Ctrl+Alt+G).
- tmux'ta `j` / `k`: tam sayfa yukarı / aşağı (PageUp/PageDown).
- `.` / `/`: opencode'da transcript araması yok; tmux'ta durum mesajı verir,
  Neovim'de opencode'a byte gitmez.
- `i` / `a`: input'a dön. `q` / `Esc`: navigation'dan çık (opencode'a gönderilmez).

opencode'da düz `C-d` uygulamadan çıkar, `Esc` çalışan yanıtı keser; adapter bu
tuşları asla iletmez. Detection `opencode` executable'ını (node/bun wrapper dahil)
kabul eder; `run`, `serve`, `mini`, `session`, `auth` gibi komutlar kapsam dışıdır.
Keybind'ler opencode 2.0.25 ile doğrulandı; custom `tui.json` kullanılıyorsa
adapter byte'ları uyarlanmalıdır. Detay: `docs/specs/opencode-terminal-navigation.md`.

Test: `./tests/run-terminal-agent.sh` (Neovim, C compiler ve isteğe bağlı tmux).
Headless PTY testleri process detection, Claude/shell regression, native byte'lar,
gerçek terminal mode geçişi ve arama input'unu doğrular. Mevcut terminal buffer'ları
mapping'leri `TermOpen` sırasında aldığı için config değişiminden sonra yeni terminal
buffer aç veya Neovim/Neovide'yi yeniden başlat.

### Neo-tree: klasörde yeni Neovim oturumu (`N`)

Neo-tree'de bir klasörün üzerinde `N`: o klasörü çalışma dizini edinen **bağımsız** yeni
bir Neovim oturumu açar.

- tmux içindeysen: yeni tmux penceresi (`tmux new-window -c <klasör> -n <ad> "nvim '+Neotree focus'"`).
- tmux dışındaysan: yeni Neovide penceresi (`neovide --chdir <klasör> -- "+Neotree focus"`).
- Dosyanın üzerinde basarsan klasörün kendisi değil **parent'ı** açılır.
- Mevcut oturum etkilenmez; yeni süreç `detach` edildiği için bu nvim kapansa da yaşar.
- Yol geçersiz / `tmux` veya `neovide` PATH'te yoksa sessiz kalmaz, hata bildirir.

Detay: `docs/specs/neo-tree-open-folder-session.md`.
Test: `./tests/run-open-folder-session.sh`.

### Yazi terminal passthrough (`C-h` gizli dosya)

Yazi, Neovim terminalinin içinde çalışırken yazi'nin kendi kısayolları Neovim'e yenilmez:
yazi önplandayken `C-h` (gizli dosyalar / input'ta backspace), `C-k` (kill to EOL),
`C-t` (Ghostty burada aç) ve `C-v` (Neovide burada aç, sadece Neovide'da) ham byte olarak
yazi'ye gider. Yazi çalışmıyorken bu tuşlar eski işlerini yapar (`C-h`/`C-k` pencere
taşıma, `C-t` terminal 1, `C-v` yapıştırma).

Bilinçli istisnalar: `C-n` terminal modundan çıkış kanalı olarak Neovim'de kalır;
`C-j`/`C-l` yazi'de bind'li olmadığı için pencere gezinmesi olarak kalır. Tespit tuş
anında tek `ps` taramasıyla yapılır (Codex/opencode adapterlarıyla aynı desen), bu yüzden
config değişiminden sonra yeni terminal açman gerekir.

Detay: `docs/specs/yazi-terminal-passthrough.md`.
Test: `./tests/run-yazi-passthrough.sh` (gerçek yazi + PTY gerektirir).
