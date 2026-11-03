# Spec — Türkçe katmanı Neovim 0.13 (nightly) uyumu

> Durum: DOĞRULANDI (0.13.0-dev-1943+gd714648b8e, 0.12.6 referans)
> Tarih: 2026-10-23 · Yetki: kullanıcının nightly'ye geçiş talebi ("bugünkü davranışı koruyacak şekilde")

## 1. İş gereksinimi

Nightly'de Türkçe Q klavyeyle bugünkü (0.12) davranış aynen sürmeli. Mac 0.12'de kalıyor: 0.12 yolu
değişmemeli.

## 2. Nightly'de ne değişti

neovim db0fca2 (#40148): çok baytlı `langmap` artık map aramasından ÖNCE uygulanıyor (tek baytta
0.12'de de öyleydi). Bunun dört yan etkisi var:

| # | Belirti | Kök neden | Çözüm | Yer |
|---|---|---|---|---|
| N1 | `ı` insert'e girmiyor | langmapper'ın `'`→`i` gibi çakışan varyantları langmap'ten geçmiş `i`'yi yakalıyor | n/x/o'da çakışan varyant kaydedilmez | `plugins/langmapper.lua` |
| N2 | `dıw` → `d'w` | turkish_keys x/o `ı`→`i`, `i`→`'` zinciri | x/o textobject map'leri yerelde kurulmaz | `config/turkish_keys.lua` |
| N3 | `yıİ`, `dıü` ... çalışmıyor | mini.ai id'yi `getcharstr` ile ham okuyor (`İ`) | mini.ai'ye TR id takma adları | `plugins/textobj.lua` |
| N4 | Ctrl+TR (`<C-ü>`, `<C-ı>` ...) map'e ulaşmıyor | Ctrl'den sonraki karakter langmap'leniyor, lhs çevrilmiyor; üstelik `LANGMAP_ADJUST` önceki tuşun `KeyTyped`'ına bağlı, sonuç deterministik değil | Tuş map'siz çekirdeğe düşerse (`key == typed`) on_key'de langmapper karşılığına çevrilir; `<C-ğ>` Esc olmasın diye noremap | `turkish_keys.lua` |
| N5 | Yavaş yazınca `düv`, `vğv`, `dü%` çalışmıyor | `input.c handle_mapping` kısmi eşleşmede lhs bayt sayısını (`]`=1) typeahead bayt sayısıyla (`ü`=2) karşılaştırıyor (`mlen == typebuf.tb_len`, olması gereken `tb_mlen`) | x/o'da `]`/`[` tetikleyici (n'de which-key zaten var): sonraki tuşu okur, map varsa remap'le, yoksa çevrilmiş karakterle noremap besler | `turkish_keys.lua` |

Langmap dışı iki nightly değişikliği daha var:

| # | Belirti | Çözüm | Yer |
|---|---|---|---|
| N6 | `3x` 9 karakter siliyor (#42468, düzeltme PR #42485 açık) | `x`/`s`/`<leader>s` sayıyı register'dan sonraya taşıyan expr map | `config/nvim_compat.lua`, `init.lua` |
| N7 | `Q` artık multicursor; 0.12'de "son makroyu oynat" | `Q` → `@<reg_recorded()>`; yerleşik MC `<leader>m/M/j/k` üzerinden; `*` arama register'ı geri yüklenir | `plugins/multicursors.lua` |

## 3. Bağlayıcı kararlar

| # | Karar | Gerekçe |
|---|---|---|
| D1 | Sürüm değil davranış probe'u (`native_multibyte_langmap`, `ctrl_tr_lost`, `count_before_register_squared`) | Backport, geri alma ya da upstream düzeltmesinde kendiliğinden doğru kalır; 0.12'de hepsi false → 0.12 yolu birebir |
| D2 | Makro normalizer'ı korunur | Upstream'de makrolarda langmap hâlâ desteklenmiyor; makro senaryoları iki sürümde aynı |
| D3 | N5 tetikleyicisi hata düzelse de zararsız | Doğru kısmi eşleşme bu tek tuşluk map'ten önce bekler |

## 4. Doğrulama

`tests/turkish_layer/` farklılık harness'ı: gerçek TUI (tmux, hex bayt), iki hız (80 ms insan / burst),
GUI chord'ları için `nvim_input`. Aynı senaryolar 0.12.6 ve nightly'de koşulur, durum (satırlar, imleç,
mod, register, hata) karşılaştırılır.

```sh
tests/turkish_layer/run.sh "<0.12 nvim komutu>" "<aday nvim komutu>"
```

Sonuç: 193 durumdan 187'si aynı. Kalan 6 durumda fark gerekçeli; hepsinde 0.12'nin kendi davranışı hatalı ya da tutarsız:

| Durum | 0.12 | Nightly |
|---|---|---|
| `yıi` (2 hız) | `y''`: satırı kopyalıyor (map zinciri) | `yi'` doğru |
| `<leader>m` ×2 `cıw` burst | jake plugin metni bozuyor (`Z"_y'w`) | doğru |
| `v l ü <Esc>` insan hızı | visual'dan çıkıyor (burst'te çıkmıyor) | iki hızda yerleşik davranış: visual kalır |
| `<C-ğ>` visual | kazara `[` gibi (`[d` → E388) | etkisiz (ikisinde de Esc değil) |
| `gcc` burst | 0.12 runtime LSP `uri.lua` hatası (rastgele) | temiz |

0.12 + yeni config, 0.12 + eski config ile aynı (yalnız bilinen gürültü). Mevcut testler
(`run-*.sh`) iki sürümde de PASS.

## 5. Upstream'e bildirilebilir

- N5: `handle_mapping` kısmi eşleşme bayt uzunluğu (tek satırlık düzeltme: `mlen` → `tb_mlen`).
- N4: Ctrl+çok baytlı karakterde langmap'in lhs'e uygulanmaması ve `KeyTyped`'a bağlılık.
