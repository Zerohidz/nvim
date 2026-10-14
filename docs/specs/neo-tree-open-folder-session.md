# Spec — Neo-tree: klasörde yeni Neovim oturumu (`N`)

> Durum: DOĞRULANDI
> Tarih: 2026-10-14 · Onaylayan: dursun.korkmaz · Ortam: nvim 0.12.6, Neovide 0.16.2, tmux 3.8

## 1. İş gereksinimi

Bir klasörü iş alanı olarak gördüğümde, mevcut Neovim oturumumu bozmadan, o klasörü
çalışma dizini edinen **bağımsız** yeni bir Neovim oturumu başlatmak. "Yeni pencere"
ortama göre anlam kazanır: tmux içindeysem yeni tmux penceresi, değilsem yeni Neovide
penceresi.

## 2. Kapsam dışı

- Nvim session dosyası kaydetme/geri yükleme (`mksession`, persistence) — ayrı iş.
- Mevcut pencerede `:cd` / `tcd` ile dizin değiştirmek (kasten yapılmıyor; izolasyon istendi).
- Dosya node'unda "o dosyayı yeni oturumda aç" (yalnız klasör odaklı; dosyada parent kullanılır).
- Neovide `--reuse-instance` / `--server` ile tek nvim state'i paylaşımı.
- tmux dışında tmux oturumu başlatmak (tmux yoksa GUI dalı kullanılır, tmux başlatılmaz).

## 3. Seçilen tasarım

Neo-tree `window.mappings["N"]` buffer-local mapping'i, imleçteki node'u klasöre çevirir
(`node_folder`: klasörse kendi yolu, dosyaysa parent'ı) ve `config/open_folder_session`
modülüne verir. Modül saf bir `plan(path, env)` ile argv üretir, `open()` bunu
`vim.system{detach = true}` ile başlatır: `$TMUX` doluysa `tmux new-window -c <dir>
[-n <basename>] "nvim '+Neotree focus'"`, değilse `neovide --chdir <dir> -- "+Neotree focus"`.
Her iki dalda da yeni nvim'in cwd'si hedef klasör olur ve `+Neotree focus` ile neo-tree
odaklı açılır.

**Reddedilen alternatifler ve neden:**

| Alternatif | Neden reddedildi |
|---|---|
| Her zaman `neovide` (tmux fark etmez) | Kullanıcısı tmux'ta terminal nvim ile çalışıyor; GUI'ye zorlamak "yeni oturum"u yanlış yere koyar. |
| tmux'ta `split-window` (pane) | "Yeni pencere" isteğini karşılamıyor; dar pane'de neo-tree + editör kullanılamıyor. |
| `neovide --reuse-instance --new-window` | Ayrı oturum değil (ortak nvim state'i) ve `--server` olmadan çalışmıyor. |
| `open -a Neovide <dir>` | `+Neotree` enjekte edilemiyor, cwd/argüman aktarımı dolaylı. |
| Yolu tmux shell-command string'ine gömmek | Boşluklu/Türkçe karakterli yolda quoting hatası riski; `-c` argv'si shell'e hiç uğramıyor. |

## 4. Bağlayıcı teknik kararlar

| # | Karar | Gerekçe | Nerede uygulanacak |
|---|---|---|---|
| D1 | tmux tespiti `vim.env.TMUX` dolu ve boş değilse | Boş string tmux değildir | `open_folder_session.plan` |
| D2 | tmux dalında hedef klasör `-c` **argv** ile geçer, shell-command sabittir (`nvim '+Neotree focus'`) | tmux argv'ları space ile birleştirip shell'e verir; yol sızarsa quoting bozulur | `plan` |
| D3 | Neovide dalında `--chdir` + `-- "+Neotree focus"` | Neovide 0.16'da `--working-dir` yok; `--` sonrası nvim'e yorumlanmadan geçer | `plan` |
| D4 | `fnamemodify(:p)` sonrası sondaki `/` kırpılır (`/` hariç) | `:p` dizine trailing slash ekliyor; tmux/neovide'a temiz yol gitmeli | `open_folder_session.resolve` |
| D5 | Spawn `detach = true`; GUI dalında stdio tamamen `ignore` | Nvim kapansa da oturum yaşamalı; ölü babaya yazan pipe tıkanması riski | `open_folder_session.open` |
| D6 | Spawn öncesi `executable()` kontrolü + `pcall`, hata `vim.notify` ERROR | Sessiz düşüş yok; GUI dalında exit code gözlenemediği için hata kapıdan yakalanır | `open` |
| D7 | Silinmiş/dizin olmayan hedef reddedilir | Kullanıcı yanlış klasörde sessiz yeni pencere açmaz | `resolve` |
| D8 | Mapping yalnız neo-tree `window.mappings` içinde (buffer-local) | Dışarıda hiçbir keymap yüzeyi değişmez | `lua/plugins/neo-tree.lua` |
| D9 | `N` tuşu (leader değil) | `<leader>o` neo-tree'de order-by ile çakıştı (kullanıcı gözlemi); `N` varsayılanlarda boş | `lua/plugins/neo-tree.lua` |
| D10 | Kök dizinde `-n` verilmez (`:t` boş döner) | tmux boş pencere adını reddeder | `plan` |

## 5. Kabul kriterleri

| # | Given / When / Then | Nasıl doğrulanır | Kanıt |
|---|---|---|---|
| AC1 | Given `$TMUX` dolu, when `plan(dir)`, then argv `tmux new-window -c dir -n <basename> "nvim '+Neotree focus'"` | unit test | `run-open-folder-session.sh`: "tmux argv" PASS |
| AC2 | Given `$TMUX` yok, when `plan(dir)`, then argv `neovide --chdir dir -- "+Neotree focus"` | unit test | "neovide argv" PASS |
| AC3 | Given boşluklu/Türkçe yol, when plan/open, then yol argv'da baytsal aynı kalır | unit test | 3 check PASS (`-c` ve `--chdir` + sızma kontrolü) |
| AC4 | Given gerçek neo-tree ağacı, when `N` mapping callback'i, then hedef klasör için spawn olur | headless nvim + gerçek neo-tree + PATH'te stub `tmux` | argv kaydı: `new-window -c /tmp -n tmp "nvim '+Neotree focus'"` |
| AC5 | Given gerçek Neovide, when `--chdir d -- '+Neotree focus'`, then nvim çocuğunun cwd'si `d` ve tek argv `+Neotree focus` | `NEOVIM_BIN` wrapper logu | `PWD=<tmp>`, `ARG=+Neotree focus`, `--embed`, `-p` |
| AC6 | Given dosya node'u, when `N`, then parent klasör açılır | unit test | "file node parent klasörü" PASS |
| AC7 | Given silinmiş dizin / nil node / binary yok, when tetiklenir, then ERROR notify + `false` | unit test (notify yakalama) | 4 check PASS |
| AC8 | Given LazyVim extra mapping'leri, when config yüklenir, then `Y/O/l/s/o/P/h` bozulmadan kalır ve `N` eklenir | headless nvim gerçek config + `maparg` | `N buffer=1`, `Y=true O=true l=true s=true o=true P=true h=true` |
| AC9 | Given `/`, when plan tmux dalı, then `-n` argümanı yok | unit test | "tmux argv kök dizin" PASS |

## 6. Edge case'ler

| Durum | Beklenen davranış |
|---|---|
| Kök dizin (`/`) | `-n` verilmez, `/` olduğu gibi kalır |
| Sondaki `/` (`/a/b/`) | normalize edilir, `/a/b` |
| Dosya node'u | parent klasör kullanılır, hata vermez |
| Node silinmiş / yolu bozuk | ERROR notify, spawn yok |
| `tmux`/`neovide` PATH'te yok | ERROR notify ("bulunamadı (PATH?)"), spawn yok |
| `tmux new-window` hata dönerse (aynı isim vb.) | tmux stderr'i ERROR notify |
| Nvim kapanınca yeni oturum | yaşamaya devam eder (`detach`) |
| buffers/git_status kaynak node'ları | `node.path` üzerinden aynı şekilde çalışır |

## 7. Etkilenen dosyalar

**Değişecek:**

| Dosya | Ne değişiyor |
|---|---|
| `lua/plugins/neo-tree.lua` | `window.mappings["N"]` eklendi |
| `DURSUN_README.md` | Kısayol dokümantasyonu |

**Yeni:**

| Dosya | Amacı |
|---|---|
| `lua/config/open_folder_session.lua` | plan/resolve/open; argv üretimi saf ve test edilebilir |
| `tests/open_folder_session.lua` | 33 check: argv, yol çözümleme, node çevirisi, gerçek spawn (stub), hata yolları |
| `tests/run-open-folder-session.sh` | Runner |
| `docs/specs/neo-tree-open-folder-session.md` | Bu spec |

## 8. Riskler

| Risk | Etki | Azaltma |
|---|---|---|
| Neovide argüman semantiği değişirse (upgrade) | GUI dalı sessiz bozulur | AC5 gerçek binary ile doğrulandı; spec'te D3 sabit |
| `tmux new-window` hedef pencere adı çakışması | Pencere açılmaz | tmux stderr kullanıcıya gösterilir (D6) |
| Aynı klasörde art arda basmak | Çoklu oturum açılır | Kasıtlı: "yeni oturum" semantiği; kilit/kontrol kapsam dışı |

## 9. Danışman notları

- Kullanıcı isteğiyle danışman turları ve spec-onay ritüeli atlandı; Gate 2 gerçek kod
  doğrulamaları (neovide `--help`, `tmux list-commands`, `command/init.lua` path fallback,
  `vim.system` detach davranışı) yapıldı.
- Kod okuması sırasında düzeltilen varsayımlar: `--working-dir` yok → `--chdir`;
  neo-tree tree node'unda `get_path()` yok → `node.path` (modül her ikisini de destekliyor);
  `:p` trailing slash ekliyor → D4.

## 10. QA sonucu

- `./tests/run-open-folder-session.sh` → `open_folder_session: 33 check PASS`
- Gerçek config headless kontrolü → `N` buffer-local + merge bozulmadı (AC8)
- Gerçek neo-tree callback + stub spawn → doğru argv (AC4)
- Gerçek `neovide` + `NEOVIM_BIN` wrapper → `PWD` ve `+Neotree focus` argv doğrulandı (AC5)
- Karşılanmayan kriter: yok.
