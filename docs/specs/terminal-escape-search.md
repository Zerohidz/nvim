# Spec — ToggleTerm normal modda Escape ile arama vurgusunu temizleme

Durum: DOĞRULANDI · Tarih: 2026-10-19

## İş gereksinimi ve tasarım

Düz shell çıktısı olan ToggleTerm buffer'ında Ctrl+n ile normal moda geçip arama yapıldığında Esc vurguyu temizlemeli. TermOpen tarafından kurulan buffer-local Esc mapping, LazyVim global mapping'ini gölgeliyor; noremap fallback yalnız native Escape gönderiyor. Normal mod callback'inde `vim.v.hlsearch = 0` ile LazyVim'in global Escape mapping'indeki `noh` komutuyla aynı nohlsearch etkisi uygulanır. Arama register'ı ve hlsearch option korunur. Terminal input modunun Escape aktarımı ve Codex search kapatma sözleşmesi korunur.

## Kararlar

- Değişiklik yalnız terminal buffer'ının normal-mode Escape callback'inde yapılır.
- Global fallback remap edilmez: buffer-local mapping'e tekrar girme riski yaratılmaz.
- Agent tespiti, terminal input modunun mapping'leri ve mevcut kullanıcı değişiklikleri korunur.

## Kabul kriterleri ve kanıt

| Kriter | Kanıt |
|---|---|
| Gerçek ToggleTerm echo çıktısında Ctrl+n, arama, Esc vurguyu temizler | `tests/terminal_escape.lua`; önceki mapping ile “Escape clears terminal search highlights” assertion fail, düzeltmeyle 18 kontrol pass |
| Escape normal modda kalır; pattern ve hlsearch option korunur | Aynı full-config event-loop testi |
| n yeniden highlight gösterir, sonraki Esc temizler | Aynı test |
| Yeni açılmış ikinci terminalde de çalışır | Aynı test, terminal 3 |
| Codex search kapatma ve terminal input akışı korunur | `tests/run-terminal-agent.sh`: 132 + 41 kontrol geçti |

## Dosyalar ve risk

`lua/config/keymaps.lua` normal Escape callback'ine iki satır eklenir. `tests/terminal_escape.lua` gerçek full-config ToggleTerm regression testi eklenir. `tests/run-terminal-agent.sh` regression suite'i mevcut sözleşmeleri doğrular. Global hlsearch state'i temizlenir; bu LazyVim'in normal Escape davranışıyla aynıdır. Native GUI ekranı üzerinde görsel inceleme yapılmadı; doğrulama gerçek terminal job, input dispatch ve highlight state üzerindedir.

## QA ve retro

Code-reviewer full-config testi bağımsız çalıştırdı: 18 kontrol geçti, correctness/regression bulgusu yok. Architect-review API ve global state sözleşmesinde sorun bulmadı; LazyVim uygulama ayrıntısını açıklayan metin düzeltildi.

Olay analizi: Buffer-local Escape, global nohlsearch davranışını atlıyordu. Sistem analizi: Önceki agent testleri normal shell highlight state’ini kapsamıyordu; yeni gerçek ToggleTerm echo regression testi bu boşluğu kapatır. Ek kalıcı davranış kuralı veya kişisel bellek gerekmiyor.
