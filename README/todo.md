# Vird — Yapılacaklar

> Tamamlanan modüllerin detayları `README/STATUS.md`'de.

---

## Aktif

*(Şu an aktif görev yok — MVP backlog'dan sıradaki modüle geçilecek)*

---

## MVP Backlog (sırayla)

- [x] 4 — Hatimlerim ekranı (aktif hatimler, yeni hatim ekleme, üstte özet) ✅
- [x] 5 — Log girişi (sure seçimi, sayfa aralığı, hatim devam, Arapça/Meal sekmesi) ✅
- [ ] 6 — Seri sistemi (sayaç, freeze, repair, perfect seri, Cuma bonusu)
- [ ] 7 — Sure serii (sure seçme, günlük log, sure bazlı sayaç)
- [x] 8 — Hasanat sistemi (sayfa bazlı hesaplama, görsel sayaç) ✅
- [x] 9 — Kuran Haritası veri bağlantısı (Firestore loglarından gerçek zamanlı ısı haritası) ✅
- [ ] 10 — Offline mode (cihaza kayıt, bağlantı gelince senkronizasyon)
- [ ] 11 — Ekip sistemi (oluşturma, katılım, yönetim, ceza sistemi)
- [ ] 12 — Liderboard (haftalık sıralama, Cuma 13:00 sıfırlama, madalyalar)
- [x] 13 — Profil veri bağlantısı (ısı haritası Firestore loglarına bağlandı) ✅
- [ ] 14 — Bildirimler (tüm bildirim tipleri)
- [ ] 15 — Rozetler (seri, hatim, okuma, ekip rozetleri)
- [x] 16 — Vird sekmesi (öneri formu, yol haritası, hakkında) ✅
- [ ] QA & Yayın öncesi test — tüm modüller bitince her akış için bug testi; `/systematic-debugging` ve `/tdd` skill'leri kullanılacak

---

## MVP Sonrası

### Admin Paneli (Uygulama İçi İçerik Yönetimi)
- [ ] Firestore'da `isAdmin: true` ile admin yetkisi sistemi
- [ ] Profil ekranında sadece admin'e görünen "İçerik Yönetimi" butonu
- [ ] Yakında geliyor kartları → ekle / düzenle / sil
- [ ] Duyurular → yaz / yayınla
- [ ] Özellik önerileri → gelen istekleri listele / okundu işaretle

### Sistemi Olgunlaştırma
- [ ] İçerik filtreleme (kullanıcı adı, grup adı, açıklama vb.)
- [ ] Pro mode (ödemeli sistem)
- [ ] Hafızlık belge doğrulama sistemi
- [ ] Ölçekleme ve performans iyileştirmeleri

### Sosyal Katman
- [ ] Takip / takipçi sistemi
- [ ] Arkadaş ekleme (kullanıcı adıyla arama)
- [ ] Telefon rehberinden kullanıcı bulma
- [ ] Takip edilen kişilerin okuma aktivitesi akışı
- [ ] Kullanıcı profili herkese açık görüntüleme

### Kişiselleştirme
- [ ] Tema rengi seçimi — 3-5 renk tonu seçeneği, kullanıcıya özel uygulama rengi
- [ ] Kuran Haritası renk seçimi — ısı haritası için farklı palet seçenekleri
- [ ] Profil unvan sistemi — hatim sayısına göre futbol yıldızı / LinkedIn etiketi tarzı rozet veya unvan (örn. "Hafız Adayı", "Hatim Ustası")

### Hesap & Ayarlar
- [ ] Google ile giren kullanıcılar için şifre oluşturma (Ayarlar ekranından e-posta + yeni şifre belirleme)
- [ ] Profil avatarı — fotoğraf yükleme veya avatar oluşturma/seçme
- [ ] Ayarlar sekmesi — gizlilik ayarları (kim neyi görebilir: sadece ben / arkadaşlar / herkes)
- [ ] Profil düzenleme ekranı — isim, kullanıcı adı, şehir, üniversite/meslek bilgisi güncelleme
- [ ] Üniversite okumayanlar için profil alanı — meslek bilgisi veya lise öğrencisi seçeneği

### Ayet & Hadis
- [ ] Günlük ayet ve hadis bildirimi
- [ ] Favori ayet/hadis seçme ve kategorize etme (koleksiyonlar, etiketler)
- [ ] Ayet/Hadis keşif sayfası

### İslami Kulüpler & Topluluk
- [ ] Öğrenci kulüplerini takip etme (YTÜ Fark ve benzeri İslami kulüpler)
- [ ] Kulüp etkinlikleri listeleme ve takvim görünümü
- [ ] Kulüp duyuru bildirimleri
- [ ] Lise grupları — lise öğrencileri kendi okullarında grup kurup uygulamayı yayabilir
- [ ] Üniversiteler ligi — üniversiteler arası haftalık okuma rekabeti ve sıralama

### Yeni Özellikler
- [ ] Namaz takibi
- [ ] İslami oyun/quiz (Zip benzeri)
- [ ] Kuran ve Meal uygulama içi okuma entegrasyonu
- [ ] Tefsir takibi
- [ ] Kuran Arapçası öğrenme (Duolingo tarzı)
- [ ] Ramazan güncellemesi (oruç, teravih takip)
- [ ] Önemli günler hatırlatması (Kadir Gecesi, Mevlid, Regaib vb.)
- [ ] Yıllık özet (Spotify Wrapped tarzı)
- [ ] Hatim sertifikası (tamamlayınca indirilebilir dijital sertifika)
- [ ] Favori camiler profilde gösterme gibi topluluk özellikleri

---

## Açık Kararlar

- [ ] 5-6 renk paletinin tüm rolleri netleştirilecek
