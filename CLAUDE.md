# Vird — Claude Çalışma Kuralları

> Bu dosya projenin çalışma protokolüdür. Herhangi bir AI bu dosyayı okuyarak projeye katkı verebilir.

---

## Proje Nedir

**Vird**, Müslümanların Kuran okuma alışkanlığını takip ettiği bir mobil uygulamadır. Flutter + Firebase ile geliştirilmektedir.

**Temel kavramlar:**
- **Hatim:** Kuranı baştan sona okuma (604 sayfa). Kullanıcı birden fazla aktif hatim yürütebilir.
- **Seri:** Kaç gün üst üste okundu. Anchor-day algoritmasıyla hesaplanır.
- **Hasanat:** Okuma karşılığı biriken puan. Altın renkle gösterilir.
- **Cüz:** Kuranın 30 eşit bölümünden biri (her biri ~20 sayfa).
- **Sure:** Kuranın 114 bölümünden biri.
- **Log:** Kullanıcının bir okuma kaydı — hangi yöntemle (hatim/sure/sayfa/cüz), kaç sayfa.
- **DevPanel:** Geliştiriciye özel ekran — bug, plan, fikir, feedback ve yol haritası yönetimi.

**Kullanıcı akışı:** Giriş → Hatim başlat → Günlük okuma logla → Seri/hasanat birik → Ekiple liderboard'da yarış.

---

## İŞE BAŞLARKEN — Şunu yap

1. `README/STATUS.md` oku — dosya haritası, Firestore şemaları, teknik kararlar burada
2. UI işi varsa `README/vird_tasarim.md` oku — renkler, spacing, bileşenler, yazı tonu
3. Hata veya kritik adım varsa `README/DERSLER.md` oku — geçmiş tuzaklar ve çözümleri
4. Kullanıcıya sor: **"Bugün ne yapacağız? Yeni bir branch açayım mı, adı ne olsun?"** — branch, hata durumunda geri dönüşü sağlar

---

## İŞ BİTİNCE — Şunu yap

Kullanıcı söylemese de kontrol et. **Her değişiklik belgelenmez — sadece aşağıdaki koşullar sağlanıyorsa güncelle:**

**`README/STATUS.md` → Dosya Haritası:** Yeni dosya eklendi VE adından ne yaptığı anlaşılmıyor.

**`README/STATUS.md` → Firestore Şemaları:** Şemada alan eklendi, silindi veya yeniden adlandırıldı.

**`README/STATUS.md` → Teknik Kararlar:** Gelecekteki kod kararlarını etkileyecek bir tercih yapıldı.

**`README/DERSLER.md`:** Bug bulmak beklenenden uzun sürdü VEYA root cause sürpriz/sezgisel değildi VEYA aynı hata farklı yerde kolayca tekrarlanabilir.

**`README/vird_tasarim.md`:** Tasarım sistemine yeni kural veya bileşen eklendi.

Rutin fix, bilinen bileşen güncellemesi, küçük UI ayarı → belgeleme.

**Commit/push zamanı:** Her işlemden sonra sorma. Kullanıcı sohbeti kapatmadan önce "bitti" sinyali verdiğinde (örn. "başka bir şey yok", "tamam", vb.) sor: **"Değişiklikleri commitleyip pushlayayım mı?"**

Commit/push bittikten sonra sor: **"Web için son sürümü derleyip yayınlayayım mı?"**

---

## Stack

Flutter + Firebase. Test: `flutter run -d chrome` (emülatör RAM sorunu).
Firestore deploy: `firebase deploy --only firestore:rules --project vird-fc834`

---

## Mimari Kararlar

Tüm kararlar `README/STATUS.md` → Teknik Kararlar bölümünde. Yeniden tartışmaya açma.

---

## Çalışma Kuralları

1. **Plan önce:** 3+ adım veya mimari karar içeren görevde önce plan yaz
2. **Doğrula:** Çalıştığını kanıtlamadan tamamlandı sayma — logları kontrol et
3. **Bug'da otonom:** Root cause bul, geçici fix koyma, el tutma isteme

---

## Commit

Türkçe · `tip: kısa açıklama` · max 50 karakter
Tipler: `feat` `fix` `style` `refactor` `docs`
**Sormadan commit atma.**

---

## Prensipler

- **Tasarıma sadık:** Her UI kararı `vird_tasarim.md`'e uygun — uygunsuzsa geri dön
- **UI metni:** Önce öneri sun, onay al, sonra yaz
- **Dini hassasiyet:** Ton ve metin `vird_tasarim.md` yazı dili bölümüne göre
- **Basitlik:** Minimal değişiklik, root cause, geçici fix yok

---

## Skill Kullanım (Claude Code)

| Durum | Skill |
|---|---|
| Yeni büyük özellik | `/grill-me` |
| Nedeni bilinmeyen hata | `/systematic-debugging` |
| Kritik iş mantığı (seri, hasanat) | `/tdd` |
| Flutter widget tasarımı | `/frontend-design` |

---

## Antigravity

- **Onay al:** Metinler, tasarımlar, sloganlar için önce öneri sun, onay bekle
- **Hot reload:** Kod değişince otomatik `r` gönder
