# Spec — Alternate buffer filetype recovery

> Durum: UYGULANDI · Tarih: 2026-10-14 · Yetki: kullanıcının düzeltme talebi

## 1. İş gereksinimi

Neovide'da `<leader>bb` ile önceki kaynak dosyaya dönüldüğünde mevcut syntax highlighting tekrar çalışmalı.
Canlı oturumda sorunlu Java buffer'ının `filetype=''`, `syntax=''` ve Treesitter highlighter olmadan açıldığı görüldü; `filetype detect` sonrası `filetype='java'` ve Treesitter aktif oldu. Filetype'ın ilk kez neden kaybolduğu henüz kanıtlanmadı.

## 2. Kapsam dışı

Tema değişikliği, plugin update, parser kurulumu, global BufEnter handler, mevcut terminal keymap'leri ve repo uygulama kodu.

## 3. Seçilen tasarım

Mevcut `:edit #` çalıştırılır. Hedef normal bir buffer, okunabilir dosya ve boş filetype ise `filetype detect` çalıştırılır. Mevcut FileType handler'ları LazyVim Treesitter ve Vim syntax kurallarını uygular. Bilinen filetype için hiçbir highlighting müdahalesi yapılmaz. `setup()` mevcut oturumda çağrılabilir.

| Alternatif | Neden reddedildi |
|---|---|
| Her dönüşte Treesitter restart | Bilinçli kapatılmış highlighting ve bigfile davranışını bozabilir |
| Global BufEnter onarımı | Kanıtlanan `<leader>bb` kapsamını aşar |

## 4. Bağlayıcı teknik kararlar

| # | Karar | Gerekçe | Nerede |
|---|---|---|---|
| D1 | Önce değişmeden `edit #` | Alternate ve unsaved-change semantiğini koru | `lua/config/alternate_highlight.lua` |
| D2 | Yalnız normal, okunabilir, boş filetype hedefte detect | Kanıtlanan arızayı dar kapsamda düzelt | aynı module |
| D3 | Mevcut FileType handler'larını kullan | TS enable/disable, parser ve syntax fallback tek sahibinde kalsın | aynı module |
| D4 | Bilinen filetype ve terminal'e dokunma | Intentional off ve bigfile korunur | aynı module |
| D5 | Idempotent mapping setup, live reload | Oturum kapatma gerektirme | `lua/config/keymaps.lua` |

## 5. Kabul kriterleri

| # | Given / When / Then | Nasıl doğrulanır | Kanıt |
|---|---|---|---|
| AC1 | Given sağlıklı Java dosyası, when leader bb, then aynı alternate buffer ve Java filetype korunur | mapping callback testi | 10 checks passed |
| AC2 | Given okunabilir Java buffer boş filetype ve syntax, when leader bb, then Java filetype ve TS veya syntax aktif | minimal mapping testi ve canlı oturum | minimal testte 10 checks passed; canlı M.open ile unloaded alternate9 → buf9 filetype java ve TS active |
| AC3 | Given bilinen filetype'da Treesitter stop ve syntax off, when leader bb, then highlighting off korunur | gerçek stop testi | 10 checks passed |
| AC4 | Given bigfile, when leader bb, then bigfile filetype ve highlighting durumu korunur | mapping testi | 10 checks passed |
| AC5 | Given terminal, when leader bb, then terminal buftype ve boş filetype korunur | termopen testi | 10 checks passed |
| AC6 | Given tanınmayan uzantı, when leader bb, then boş filetype hatasız kalır | fixture testi | 10 checks passed |
| AC7 | Given nohidden ve değişmiş buffer, when leader bb, then edit # hata verir ve değişiklikler korunur | mapping testi | 10 checks passed |
| AC8 | Given alternate yok, when leader bb, then mevcut edit # hata semantiği korunur | mapping testi | 10 checks passed |

## 6. Edge case'ler

Okunamayan veya adsız buffer'da recovery uygulanmaz. Bir buffer unload olmuş olsa da `edit #` tamamlandıktan sonraki güncel buffer değerlendirilir. Filetype'ın kaybolma nedeni düzeltilmiş olduğu iddia edilmez.

## 7. Etkilenen dosyalar

- `lua/config/keymaps.lua`: module setup çağrısı.
- `lua/config/alternate_highlight.lua`: mapping ve dar filetype recovery.
- `tests/alternate_highlight.lua`: mapping davranış testleri.

## 8. Riskler

Boş filetype tespitinde standart FileType handler'ları yeniden çalışır; tekrar eden gereksiz çağrılar nonempty guard ile engellenir. Bilinen filetype'da eksik TS ayrı arızadır, bu scope'ta restart edilmez.

## 9. Danışman notları

Koordinatörün canlı incelemesi recovery'yi doğruladı. Runtime incelemesi Treesitter stop'un `ts_highlight=nil` yaptığını gösterdi; bundan dolayı nil değere bakarak restart seçeneği reddedildi.

## 10. QA sonucu

- `/opt/homebrew/bin/nvim --headless -u NONE -l tests/alternate_highlight.lua`: 10 checks passed.
- Canlı Neovide oturumunda RPC ile yeni mapping çalıştırıldı: kapalı Java alternate buffer yeniden açıldı, `filetype=java` ve Treesitter aktif doğrulandı. Screenshot alınmadı.
- Code-reviewer ve architect-review bulgu vermedi.
- Full config testinin bigfile fixture koşusu tutarlı geçmedi; bu suite başarılı olarak raporlanmaz. Minimal suite ve canlı Java doğrulaması ayrı kanıtlardır.
