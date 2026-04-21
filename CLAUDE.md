# Vird — Claude Çalışma Kuralları

Proje dokümanı: `vird_proje_dokumani.md`
Tasarım sistemi: `Tasarım Dosyaları/vird_tasarim.md`
Stack: Flutter + Firebase

## Hangi Durumda Hangi Dosya

| Durum | Oku |
|---|---|
| Yeni özellik / genel soru | `vird_proje_dokumani.md` |
| UI, widget, ekran tasarımı | `Tasarım Dosyaları/vird_tasarim.md` |
| Renk, tipografi, animasyon | `Tasarım Dosyaları/vird_tasarim.md` |
| Hata ayıklama, bug fix | `tasks/lessons.md` (varsa) |
| Ne yapılacak belirsiz | İkisini de oku |

---

## 1. Plan Önce, Kod Sonra

- 3+ adım veya mimari karar içeren HER görev için önce plan yaz
- Belirsizlik varsa spec netleşmeden koda girme
- Bir şeyler ters giderse DUR, yeniden planla — ilerlemeye devam etme
- Doğrulama adımları da plana dahil edilir

## 2. Bitmeden Doğrula

- Çalıştığını kanıtlamadan görevi tamamlandı sayma
- Kendine sor: "Kıdemli bir Flutter geliştirici bunu onaylar mıydı?"
- Streak hesaplama, hasanat, offline sync gibi kritik modüllerde test koş
- Logları kontrol et, doğruluğu kanıtla

## 3. Zarafet — Dengeli

- Önemsiz olmayan değişikliklerde: "Daha temiz bir yol var mı?" diye sor
- Hacky hissettiren bir fix varsa: şu an bildiklerinle zarif çözümü uygula
- Basit fixlerde bunu atlat — aşırı mühendislik yapma

## 4. Bug Düzeltme — Otonom

- Bug geldiğinde: düzelt, el tutma isteme
- Log, hata, failing test — bak ve çöz
- Root cause bul, geçici fix koyma

## 5. Öz-İyileştirme

- Herhangi bir düzeltme sonrası `tasks/lessons.md` güncelle
- Aynı hatanın tekrarını önleyecek kural yaz
- Session başında `tasks/lessons.md` gözden geçir

---

## Görev Yönetimi

1. `tasks/todo.md`'ye checkable maddeler olarak plan yaz
2. Uygulamaya başlamadan önce planı doğrula
3. Giderken tamamlananları işaretle
4. Her adımda kısa özet ver
5. Düzeltmelerden sonra `tasks/lessons.md` güncelle

---

## Commit Kuralları

- Commit mesajı Türkçe yaz
- Format: `tip: kısa açıklama` — örn: `feat: streak freeze sistemi eklendi`
- Tipler: `feat` (yeni özellik), `fix` (hata), `style` (UI), `refactor`, `docs`
- Mesaj 50 karakteri geçmesin
- Sen sormadan commit atma — sadece "commit at" deyince at

---

## Temel Prensipler

- **Önce basitlik:** Her değişikliği minimal tut
- **Root cause:** Geçici fix yok, gerçek sebebi bul
- **Tasarıma sadık:** Her UI kararı `vird_tasarim.md`'e uygun olmalı
- **Dinî hassasiyet:** Metin ve ton her zaman `vird_tasarim.md` Bölüm 13'e göre

---

## Skill Kullanım Rehberi

| Durum | Skill |
|---|---|
| Yeni büyük özellik başlamadan önce | `/grill-me` |
| Bir şey bozuldu, neden bilinmiyor | `/systematic-debugging` |
| Kritik iş mantığı (streak, hasanat) | `/tdd` |
| Flutter widget tasarımı | `/frontend-design` |
