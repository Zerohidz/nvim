# Theme Sistemi

Nvim renk şeması, Omarchy sistem teması ile senkron çalışabilir veya elle
seçilen bir colorscheme'e (örn. `simple-focus`) sabitlenebilir. Geçiş anında
(restart gerekmeden) uygulanır.

## Kullanım

```vim
:ThemeMode              " picker aç, listeden seç
:ThemeMode omarchy      " Omarchy sistem temasıyla senkron ol
:ThemeMode simple-focus " kendi simple-focus temana sabitle
:ThemeMode gruvbox      " herhangi bir colorscheme adına sabitle
```

Picker listesi şunları içerir:
- `omarchy` — Omarchy'nin o an seçili sistem temasını kullan
- `simple-focus` — kendi custom temamız (`colors/simple-focus.lua`)
- Omarchy'nin tüm tema dizinlerinden (`~/.local/share/omarchy/themes/*` ve
  `~/.config/omarchy/themes/*`) taranan colorscheme isimleri (gruvbox,
  tokyonight-night, kanagawa, catppuccin, vb.)

Seçim `~/.local/share/nvim/theme-mode.txt` dosyasına yazılır, kalıcıdır.

## Nasıl Çalışıyor

### Dosyalar

- **`lua/config/theme-mode.lua`** — mod state'ini okur/yazar
  (`theme-mode.txt`). `"omarchy"` modunda, Omarchy'nin
  `~/.config/omarchy/current/theme/neovim.lua` dosyasından güncel
  colorscheme adını çeker (`resolve()`). Diğer her şey doğrudan colorscheme
  adı olarak kullanılır.

- **`lua/config/omarchy-themes.lua`** — ortak yardımcı modül. Omarchy'nin
  tüm tema dizinlerini (`~/.local/share/omarchy/themes/*` +
  `~/.config/omarchy/themes/*`, varsa `$OMARCHY_PATH/themes`) tarar, her
  birinin `neovim.lua` lazy-spec'ini `dofile` ile okuyup döner.

- **`lua/plugins/theme.lua`** — `LazyVim.opts.colorscheme` değerini
  `theme-mode.resolve()`'dan alır. Startup'ta uygulanan colorscheme budur.

- **`lua/plugins/all-themes.lua`** — `omarchy-themes.theme_specs()`'i
  kullanarak Omarchy temalarının kullandığı TÜM colorscheme plugin'lerini
  (`lazy = true`) otomatik ekler. Böylece picker'dan hangi tema seçilirse
  seçilsin plugin diskte hazır olur. **Omarchy güncellemesiyle yeni tema
  gelirse, plugin listesi de otomatik genişler** — sadece `:Lazy sync` ile
  yeni plugin'ler indirilir.

- **`lua/plugins/omarchy-theme-hotreload.lua`** — asıl mantık burada:
  - `apply_theme()`: `plugins.theme` modülünü yeniden `require` edip güncel
    colorscheme'i bulur, `highlight clear` + `colorscheme` ile anında
    uygular, transparency ayarlarını (`plugin/after/transparency.lua`)
    yeniden yükler.
  - `User LazyReload` autocmd: Omarchy/Lazy taraflı bir reload sinyali
    gelirse `apply_theme()`'i tetikler.
  - `:ThemeMode` komutu: `theme-mode.set(mode)` + `apply_theme()`.

### Akış (örnek: `:ThemeMode gruvbox`)

1. `theme-mode.txt` içine `gruvbox` yazılır.
2. `package.loaded["plugins.theme"] = nil` → `theme.lua` yeniden çalışır,
   `colorscheme = "gruvbox"` döner.
3. `highlight clear` + `lazy.core.loader.colorscheme("gruvbox")` (plugin
   henüz lazy-load edilmemişse yükler) + `:colorscheme gruvbox`.
4. Transparency dosyası yeniden source edilir, `redraw!`.

## Sınırlamalar / Sorun Giderme

- Picker'daki bazı temalar (`lumon`, `vantablack`, `miasma`, `retro-82`,
  `white`, `nordfox`, `everforest`...) ayrı plugin gerektirir. İlk kurulumda
  veya Omarchy güncellemesi sonrası bunlar eksikse:
  ```vim
  :Lazy sync
  ```
  çalıştır — `all-themes.lua` taraması bunları otomatik spec'e ekler, sync
  indirir.

- `:colorscheme XYZ` "E185: Cannot find color scheme" hatası veriyorsa,
  ilgili plugin henüz indirilmemiş demektir → `:Lazy sync`.

- Tek başına local dizine (`dir = stdpath("config")`) ait birden fazla lazy
  plugin spec'i TANIMLAMA — lazy.nvim aynı `dir`'e sahip specleri merge eder,
  birden fazlası tanımlanırsa biri sessizce kaybolur (config/autocmd hiç
  çalışmaz). Bu yüzden tüm hotreload + `:ThemeMode` mantığı tek bir
  `theme-hotreload` plugin spec'i içinde toplanmıştır.

## Kendi Temanı Eklemek

1. `colors/<isim>.lua` dosyanı yaz (bkz. `colors/simple-focus.lua`).
2. `:ThemeMode <isim>` ile seç. Plugin gerektirmez, `colors/` dizini her
   zaman runtimepath'te.
