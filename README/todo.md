# Vird — Yapılacaklar

> Tamamlanan modüllerin detayları `README/STATUS.md`'de.

---

## Aktif — MVP Öncesi (tek kalan)

- [ ] **Liderboard dönemini günlük → haftalık çevir** — `ekip_profil_screen.dart`'ta `_LeaderboardPeriod.daily` → `weekly`. Dönem sonu: Cuma 13:00. Geri sayım sayacı ve `periodStart` hesabı buna göre güncellenmeli.
- [ ] **Son hata testleri & QA** — tüm akışlar manuel test; `/systematic-debugging` skill'i kullanılacak

### Tamamlanan (2026-05-09)
- [x] **Seri animasyonu ekranı** — StreakAnimationScreen (CustomPainter alev, whip arkleri, haftalık takvim, motivasyon mesajları, elastic pill, parabolic arc token) ✅
- [x] DevPanel arşiv görünümü — `_ArchiveView` StatefulWidget, BUGS/TO-DO sekmeleri, unarchive ✅
- [x] Web deploy — `flutter build web --release` + `firebase deploy --only hosting` → https://vird-fc834.web.app ✅
- [x] isDeveloper sistemi: UserProvider, DEV badge, developerTeamIds liderboard desteği ✅
- [x] Seri 5 bug düzeltmesi: recalculate anchor-day, deleteAllLogs filtresi, seriDisplayState guard, migration path, liderboard seriDisplayState ✅
- [x] Profil header: Vird logosu + ayarlar butonu banner sağ altına taşındı (v_logo.png) ✅

### Tamamlanan (2026-05-08)
- [x] Nav yeniden yapılandırma: Alışkanlıklar tab eklendi, VİRD Ayarlar'a taşındı ✅
- [x] Hatim ısı haritası secde tap düzeltmesi ✅
- [x] Seri "tehlikede" göstergesi (Profil + Hatimlerim) ✅
- [x] Liderboard geçmiş görünürlük: herkes son hafta, admin tümü ✅
- [x] `teamJoinedAt` — retroaktif liderboard katılım önlendi ✅
- [x] Liderboard Puan/Seri filtre chips + satırda seri gösterimi ✅
- [x] Ricâl-i FARK ekip logosu ✅

---

## MVP Backlog (sırayla)

- [x] 4 — Hatimlerim ekranı (aktif hatimler, yeni hatim ekleme, üstte özet) ✅
- [x] 5 — Log girişi (sure seçimi, sayfa aralığı, hatim devam, Arapça/Meal sekmesi) ✅
- [x] 6 — Seri sistemi — sayaç + seri takvimi + dinamik yeniden hesap ✅; eksikler MVP sonrasına: freeze/repair, perfect seri, Cuma bonusu, seri animasyonu
- [ ] 7 — Sure serii (sure seçme, günlük log, sure bazlı sayaç)
- [x] 8 — Hasanat sistemi (sayfa bazlı hesaplama, görsel sayaç) ✅
- [x] 9 — Kuran Haritası veri bağlantısı (Firestore loglarından gerçek zamanlı ısı haritası) ✅
- [x] 10 — Offline mode (Firestore persistence — cihaz cache, bağlantı gelince sync) ✅
- [x] 11 — Ekip sistemi (liste, gizlilik, davet kodu, istek/onay, admin paneli, liderboard, admin grup silme) ✅
- [x] 12 — Haftalık ekip sıralaması (ekip içi, 0 puanlı üyeler dahil, ilk 3 yeşil/son 3 kırmızı, Puan/Seri filtresi) ✅
- [x] 13 — Profil veri bağlantısı (ısı haritası Firestore loglarına bağlandı) ✅
- [x] 14 — Bildirimler — günlük akıllı bildirim ✅ (log kaydedilince o gün iptal); diğer tipler MVP sonrası
- [ ] 15 — Rozetler (seri, hatim, okuma, ekip rozetleri) — MVP sonrası
- [x] 16 — Vird sekmesi (öneri formu, yol haritası, hakkında) ✅

---

## MVP Öncesi UI / Test Görevleri

- [ ] **Isı haritası stres testi** — profil ekranında geçici "test verisi yükle" butonu ekle; rastgele sayfa değerleri (0–50 okuma arası) ile haritanın uç değerlerde nasıl göründüğünü test et; renk dağılımı, Fatiha karesi, 30. cüz kırık satır dahil kontrol edilecek
- [ ] **Sure bazlı ısı haritası düşün** — bir kullanıcı her gün aynı sure'yi okursa o sayfalar çok yüksek count alacak, çevresindeki sayfalar hep gri kalacak; bu görsel dengesizliğin harita için ne anlama geldiğine bakılacak (heatColorRelative zaten yardımcı oluyor ama özellikle sure seviyesinde test edilmeli)
- [x] **Hatimler ekranı UI sadeleştirme** — kart boyutları küçültüldü, DEVAM ET ısı haritasına taşındı ✅

---

## MVP Sonrası

### Seri Sistemi (Tamamlama)
- [x] **Seri Animasyonu** — seri sayısı artınca alev animasyonu; tehlikedeyse titreme/renk değişimi ✅
- [ ] Seri freeze — önceden kazanılır, kaçırılan günü korur, max 2 adet
- [ ] Seri repair — kaçırdıktan sonra kısa süre içinde ekstra okuyarak geri kazanma
- [ ] Perfect Seri — freeze kullanmadan devam edince seri altın olur
- [ ] Cuma bonusu — Cuma günü tamamlayınca ekstra hasanat

### Oyunlaştırma & UX
- [ ] **Günlük Görevler** — günlük mini hedef sistemi (ör. "Bugün 10 sayfa oku", "Bir cüz tamamla"); tamamlanınca rozetlenir
- [ ] **Motivasyonel Yazılar** — ironik ve samimi "hadi aslanım" tarzı yazılar; boş durum ekranlarında, yükleme anında, seri kırılınca, uzun süredir giriş yapılmayınca gösterilir
- [ ] **Rozetler & Başarılar** — seri rozetleri (7/30/100/365 gün), hatim rozetleri (1./3./10. hatim), okuma rozetleri (100/500/1000 sayfa), liderboard madalyaları
- [ ] **Hatim Tamamlanma UX** — tamamlanan hatimi geri alma yok uyarısı ("Hatim bitiyor, geri alınamaz, devam et?"); tamamlanan hatimlerde log ekleme/düzenleme kilitleme

### İslami İçerik
- [x] **Namaz Takibi** — vakinde / kaza / cemaat durumlarıyla haftalık namaz takibi ✅ (`gunluk_takipler_screen.dart`)
- [x] **Alışkanlık Takibi** — özel alışkanlık oluşturma, günlük işaretleme, seri ve ısı haritası ✅ (`habit_tracker_widget.dart`)
- [ ] **Zikir Entegrasyonu** — zikir çekme takip ekranı; tesbih sayacı, günlük zikir hedefi
- [ ] **Nafile Namaz Bilgisi** — vakit ekranlarında veya ayrı sekmede: vakitlere göre hangi nafile namazların tavsiye edildiği bilgisi (kuşluk, teheccüd, evvabin vb.)
- [ ] **Oruç Tavsiye Günleri** — Pazartesi-Perşembe, Eyam-ı Biyz (ayın 13-14-15'i), 3 Aylar yaklaşınca bildirim; Ramazan öncesi sayaç
- [ ] **Vakitlerde Tavsiye Edilen Sure & Dualar** — sabah/akşam duaları, Kehf (Cuma), Mülk (gece), vb.; ilgili vakitte bildirim veya ana ekran kartı
- [ ] **Ezan Vakitleri + Ezan Duası** — konum/şehir ile namaz vakitleri; ezan vaktinde isteğe bağlı ezan duası bildirimi

### Admin Paneli (Uygulama İçi İçerik Yönetimi)
- [ ] Firestore'da `isAdmin: true` ile admin yetkisi sistemi
- [ ] Profil ekranında sadece admin'e görünen "İçerik Yönetimi" butonu
- [ ] Yakında geliyor kartları → ekle / düzenle / sil
- [ ] Duyurular → yaz / yayınla
- [ ] Özellik önerileri → gelen istekleri listele / okundu işaretle

### Ekip Sistemi (MVP Sonrası Eklemeler)
- [ ] Admin devri — admin başka bir üyeyi admin yaparak ayrılabilsin
- [ ] Üye çıkarma — admin üyeleri ekipten çıkarabilsin
- [ ] Davet kodu yenileme — admin mevcut kodu değiştirebilsin
- [ ] Haftalık yarışma sistemi ve geçmiş haftaların özet tabloları (Cloud Function ile)

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
- [x] Google ile giren kullanıcılar için şifre oluşturma (Ayarlar ekranından e-posta + yeni şifre belirleme) ✅
- [ ] Profil avatarı — fotoğraf yükleme veya avatar oluşturma/seçme
- [x] Ayarlar sekmesi — gizlilik ayarları (kim neyi görebilir: sadece ben / arkadaşlar / herkes) (Kısmen: Şifre ve Profil Ayarları eklendi) ✅
- [x] Profil düzenleme ekranı — isim, kullanıcı adı, şehir, üniversite/meslek bilgisi güncelleme ✅
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
- [x] Namaz takibi ✅
- [ ] İslami oyun/quiz (Zip benzeri)
- [ ] Kuran ve Meal uygulama içi okuma entegrasyonu (Vird sekmesinde "Yakında Geliyor" listesine eklendi)
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
