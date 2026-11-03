# Spec — Neo-tree terminal oturumu ve mevcut klasöre geçiş

> Durum: DOĞRULANDI · Tarih: 2026-10-19 · Yetki: kullanıcının doğrudan talebi

## İş gereksinimi ve kapsam
`N` kullanılan arayüze uygun bağımsız oturum açar. `gN` mevcut oturumda seçilen klasöre geçer. Dosyada parent klasör kullanılır. Diğer mevcut değişikliklere dokunulmaz.

## Tasarım ve bağlayıcı kararlar
- GUI tespiti `vim.g.neovide`; testte açık parametre ile enjekte edilebilir. Neovide öncelikli, ardından dolu TMUX, ardından terminal dalı.
- Neovide ve tmux mevcut argv sözleşmesini korur.
- Yerelde kurulu terminal Kitty: macOS `open -na kitty --args --directory <dir> <absolute-nvim> '+Neotree focus'`. Shell'e dinamik yol gömülmez. Gerekli binary eksikse ERROR bildirimi; terminalden GUI'ye fallback yok.
- `gN` ortak node_folder doğrulamasını kullanır; `vim.api.nvim_set_current_dir` ve Neo-tree command.execute ile mevcut filesystem kökünü taşır. Yeni process/window açılmaz. Mevcut dosyalar kapanmaz.
- `N` ve `gN` yalnız Neo-tree buffer mapping'leridir.

Alternatifler: her zaman Neovide kullanıcı talebine aykırıdır; kurulu olmayan Ghostty'yi TERM_PROGRAM'dan seçmek yerel ortamda çalışmaz. Kitty --help macOS open ile başlatmayı önerir. Gizli platform genellemesi kapsam dışıdır.

## Kabul kriterleri
| # | Given / When / Then | Doğrulama ve kanıt |
|---|---|---|
| AC1 | Neovide içinde N → Neovide; tmux terminalde N → tmux | 57-check suite PASS (GUI + inherited TMUX dahil) |
| AC2 | Normal terminalde N → Kitty + hedef cwd + absolute nvim + Neotree focus | 57-check suite PASS; gerçek Kitty + nvim: cwd ve Neo-tree root hedefte, filetype=neo-tree |
| AC3 | gN klasör/dosya node → kendi klasörü/parent; global cwd ve tree root değişir, spawn yok | Gerçek config headless PASS: global cwd, current cwd, state.path, açık buffer korunması; suite dosya parent testi PASS |
| AC4 | Boşluk, Türkçe, tırnaklı yollar argv'da korunur; geçersiz node/yolda ERROR | 57-check suite PASS (GUI + inherited TMUX dahil) |
| AC5 | N/gN buffer-local; mevcut mapping'ler korunur | Gerçek config headless PASS: N/gN buffer-local, Y/O/l/s/o/P/h korunuyor |

## Etkilenen dosyalar
lua/config/open_folder_session.lua, lua/plugins/neo-tree.lua, tests/open_folder_session.lua, DURSUN_README.md; önceki spec güncel belgeye yönlendirilir.

## Risk ve QA
Yeni GUI terminalin gerçek açılışı ve ekran kontrolü ayrıca doğrulanmalıdır; argv unit testi GUI'nin açıldığını tek başına kanıtlamaz.

### QA sonucu (2026-10-19)
- tests/run-open-folder-session.sh: 57 check PASS.
- Gerçek Kitty launch: boşluk, Türkçe ve apostrof içeren hedefte nvim cwd ve Neo-tree root doğrulandı; test oturumu otomatik kapandı.
- Gerçek Neo-tree headless: N/gN mapping, global/current cwd, root ve açık buffer korunması PASS.
- stylua --check ve git diff --check PASS; code-reviewer ve architect-review blocker bulmadı.
- test-ui akışı değerlendirildi: bu native Neovim kısayolu için web route/DOM/computed-style/Playwright uygulanamaz; native canlı ve headless kontrol kullanıldı. Görsel stil değişikliği yok.
- Retro: önceki testler tmux yokluğunu GUI ile eş tutuyordu; GUI varlığı ayrı test girdisi yapılarak terminal dalı ve inherited TMUX regresyonu kapsandı. Genel davranış kuralı eklenmedi.

### 2026-10-19 — Geri dönüş kısayolu
`gP` Neo-tree içinde `:cd -` çalıştırır ve mevcut filesystem kökünü cwd ile günceller. Tekrar basıldığında iki klasör arasında geçiş yapılır. Önceki dizin yoksa ERROR bildirilir.
Doğrulama: gerçek config headless `gN → gP → gP` akışında cwd ve Neo-tree root PASS; gP buffer-local PASS; stylua ve diff whitespace kontrolü PASS.

### 2026-10-21 — Üst klasöre çıkış ve arama vurgusu
Kullanıcının yeni talebiyle `gP`, önceki dizine dönüş yerine Neo-tree kökünün parent klasörüne geçer; cwd ve filesystem kökü birlikte güncellenir. cwd farklı olsa da Neo-tree kökü esas alınır; `/` üzerinde sabit kalır.
`Esc` buffer-local callback'i `vim.v.hlsearch = 0` uygular ve Neo-tree'nin mevcut `cancel` komutunu çağırır. Normal `/` aramasının vurgusu temizlenir; search register, `hlsearch` option ve preview/floating iptal davranışı korunur.
Doğrulama: gerçek full-config headless Neovim içinde mapped input ile 15 kontrol PASS (arama → Esc → n → Esc, buffer-local eşlemeler, farklı cwd, ardışık gP, filesystem root). Native görsel inceleme yapılmadı; stil değişikliği yok.
Retro: Neo-tree'nin buffer-local `cancel` eşlemesi global nohlsearch davranışını atlıyordu; callback'e aynı highlight temizliği eklendi.
