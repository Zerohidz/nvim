# Spec — Türkçe klavye makro kaydı

> Durum: DOĞRULANDI
> Tarih: 2026-10-07 · Yetki: kullanıcının sorunu deneyerek bulup düzeltme talebi

## 1. İş gereksinimi

`qa`, `ı`, metin, Escape, `q`, `@a` akışı kaydedilen metni tekrar yazmalı. Türkçe Insert metni korunmalı; `E20: Mark not set` oluşmamalı.

## 2. Kapsam dışı

Makro normalizer'ının bütün Vim komutlarını kapsayacak şekilde yeniden yazılması, plugin güncellemesi, diğer kişisel keymap'lerin değiştirilmesi ve gerçek VS Code UI otomasyonu bu düzeltmenin kapsamı dışındadır.

## 3. Seçilen tasarım

`langmap` seçenekleri `config.lazy` yüklenmeden önce hazırlanır. Langmapper böylece ilk `setup()` sırasında gerçek Türkçe eşlemeleri görür. Keymap ve RecordingLeave hook'larının önceki yüklenme sırası korunur. Mevcut normalizer korunur; setup tekrar çağrıldığında ikinci hook kurulmaz. `qA` için yalnız `RecordingLeave.regcontents` içindeki yeni segment normalize edilir; önceden dönüştürülmüş register prefix'i tekrar çevrilmez.

Boş langmap ile başlatılan langmapper `i`/`ı` varyantlarını callback'e dönüştürüyordu. Bu callback replay sırasında tekrar input kuyruğuna `i` ekleyerek komut/metin sırasını bozuyordu. Ayrıca setup iki kez çağrıldığında iki normalizer hook'u, ilk dönüşümdeki `i` karakterini ikinci dönüşümde mark komutu `'` olarak çeviriyor ve `E20` üretebiliyordu. Başlangıç sırasını düzelten A/B deneyi aynı kurulu plugin sürümüyle geçti.

| Alternatif | Neden seçilmedi |
|---|---|
| Langmapper'ı kaldırmak | Diğer Türkçe keymap ihtiyaçlarını değiştirir. |
| Normalizer'ı kaldırmak | Minimal Neovim'de nolangremap ile ham `ı` replay deneyi başarısız. |
| Tüm setup'ı erkene taşımak | Textobject keymap'lerinin plugin'lerle yüklenme sırasını değiştirir. |

## 4. Bağlayıcı teknik kararlar

| # | Karar | Gerekçe | Yer |
|---|---|---|---|
| D1 | `setup_langmap()` lazy'den önce; `setup()` sonra | Langmapper'a doğru seçenekler, mevcut keymap sırası | `init.lua` |
| D2 | Setup idempotent, named augroup clear | İkinci çağrı kayıtları ikinci kez dönüştürmemeli | `turkish_keys.lua` |
| D3 | Append prefix korunur | Önceki `i` tekrar `'` olmamalı | RecordingLeave callback |
| D4 | Gerçek `nvim_input` kayıt/oynatma testi | Normalizer unit test'i callback/input sırası hatasını yakalayamaz | `tests/macro_recording.py` |

## 5. Kabul kriterleri

| # | Given / When / Then | Doğrulama | Kanıt |
|---|---|---|---|
| AC1 | Türkçe `ı` ile ASCII `test` kaydedilip @a oynatıldığında metin aynen yazılır, error boş | Full + minimal embedded Neovim | PASS iki profil |
| AC2 | Türkçe Insert metni aynen korunur | Register ve buffer karşılaştırması | `Türkçe ıişğüöç` birebir PASS |
| AC3 | @a, @@ ve 2@a çalışır | Gerçek input ve buffer kontrolü | PASS iki profil; i'nin cursor önüne ekleme semantiği hesaba katıldı |
| AC4 | qA append mevcut register prefix'ini değiştirmez | Register ve replay karşılaştırması | PASS iki profil |
| AC6 | Aynı input batch içinde kayıt ardından qA append geldiğinde prefix korunur | `qaıx<Esc>qqAay<Esc>q`, register ve replay | `ix<Esc>ay<Esc>` register, `xy` buffer PASS iki profil |
| AC5 | Setup tekrar çağrıldığında bir callback kalır ve replay bozulmaz | Autocmd sayısı + replay | Bir RecordingLeave callback, PASS iki profil |

## 6. Edge case'ler

| Durum | Beklenen davranış |
|---|---|
| Boş kayıt | Dönüşüm yapma |
| Aynı batch içinde ardışık append | Pending normalize prefix korunur, yalnız son callback yazar |
| Uppercase register append | Önceki prefix'i koru, yalnız yeni segmenti çevir |
| İkinci setup çağrısı | İkinci normalizer kurulmaz |
| Insert'teki Türkçe harfler | Olduğu gibi korunur |

## 7. Etkilenen dosyalar

| Dosya | Değişiklik |
|---|---|
| `init.lua` | Erken langmap initialization |
| `lua/config/turkish_keys.lua` | Setup ayrımı, idempotence, append segment normalizasyonu |
| `tests/macro_recording.py` | Full ve minimal input regresyonları |
| `tests/run-macro-recording.sh` | PYTHON_BIN / NVIM_BIN ile çalıştırılabilir test |
| `docs/specs/turkish-macro-recording.md` | Tasarım ve kanıt |

## 8. Riskler

RecordingLeave sonrası dönüşüm scheduled olduğundan, kayıt durdurma ile replay aynı input batch içinde gönderilirse (`q@a`) dönüşümden önce replay başlayabilir. Kabul kriterleri ayrı kullanıcı tuş girişleri ve scheduler barrier sonrası replay içindir; bu önceki tasarım sınırlaması devam eder. Aynı batch içindeki ardışık kayıtlar/append için pending register içeriği takip edilir; eski callback yeni kaydı ezmez.

Mevcut normalizer sınırlı bir normal/insert/search state machine'dir; tüm Vim komutları, keycode'lar ve plugin callback'leri için genel doğruluk iddiası yoktur. Testler kurulu plugin'lerle headless Neovim'i doğrular; gerçek VS Code oturumundaki extension/input davranışı ayrıca doğrulanmalıdır.

## 9. Danışman ve tarihsel kanıt

Tarihsel A/B, mevcut kurulu langmapper sürümüyle eski config'leri çalıştırdı: `a182b7e^` kaydedilen `ıtest<Esc>` makrosunu oynattı; 2026-02-16 tarihli `a182b7e` ve daha sonraki adaylar başarısız oldu. Bu, mevcut plugin ile config regresyon sınırıdır; her tarihsel plugin sürümünün yeniden kurulması değildir. `8978237` normalizer'ı ekleyerek register'ı `i` ile başlatabildi fakat initialization sırası problemini çözmedi. `vim.on_key` deneyi hatalı sırada typed `ı` yerine Lua callback ve sonradan beslenen `i`, doğru sırada doğrudan `ı` gösterdi.

## 10. QA sonucu

- Önce: full config testinde beklenen `iTürkçe ıişğüöç<Esc>` register yerine `'Türk.e iişğüöç<Esc>` üretildi; test başarısız oldu.
- Sonra: `PYTHON_BIN=/tmp/nvim-macro-debug-venv/bin/python tests/run-macro-recording.sh` iki profil için PASS.
- Gerçek UI değil, embedded headless Neovim input/recording/replay testi kullanıldı.
- `g:vscode=1` ile full config startup denendi; dış Neovim oturumunda VS Code extension bridge'inin sağladığı `vscode` Lua modülü bulunmadığından LazyVim VS Code extra yüklenemedi. Gerçek extension oturumu doğrulanmadı; bu sınırdan plugin/config değişikliği türetilmedi.

## 11. Retro — olay ve sistem analizi

- Olay: Kullanıcının “mark not set” bildirimi gerçek `nvim_input` ile araştırıldı. Plugin initialization sırası playback'i bozuyordu; tekrarlanan setup çift normalizasyonla `i`yi `'`ye çeviriyordu. Review ayrıca tek input batch içindeki append'in register prefix'ini kaybettiğini buldu; pending-entry düzeltmesi ve bağımsız test bu kaybı kapattı.
- Sistem: Register dönüşümünü tek başına kontrol etmek, plugin setup ve gerçek input kuyruğu etkileşimini yakalamıyordu. İlk testin her adım arasındaki scheduler barrier'ı da append race'ini gizledi. `tests/macro_recording.py` artık full/minimal startup, gerçek kayıt/replay, tekrar setup ve barriersız batched append'i birlikte doğruluyor; aynı hata sınıfı için mekanizma yeni genel kurallar yerine repo regression testidir.
- Sınır: Aynı batch içindeki hemen replay ve gerçek VS Code bridge akışı doğrulanmış başarı olarak sunulmadı. Genel kişisel memory, hook veya skill değişikliği yapılmadı.
