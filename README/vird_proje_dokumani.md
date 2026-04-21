# Vird — Proje Dokümanı
*Sadece netleşmiş kararlar. Konuşulmamış hiçbir şey eklenmedi.*

---

## 1. Kimlik

| | |
|---|---|
| **Uygulama Adı** | Vird |
| **Anlam** | Günlük düzenli ibadet/okuma |
| **Hedef Kitle** | YTÜ Fark Kulübü (40 kişi) — ilk kullanıcı grubu |
| **Platform** | iOS + Android |

---

## 2. Tasarım

| | |
|---|---|
| **Ana Renk** | `#2A7F8C` (mavi-eflatun-yeşil arası) |
| **Streak Rengi** | Turuncu |
| **Zemin** | Beyaz |
| **Palet Sistemi** | 5-6 temel renk. Streak gibi sabit anlam taşıyanların rengi sabittir, diğerleri bu paletten seçilir |
| **Estetik** | Duolingo ve Quranly benzeri his. Beyaz zemin, ferah, minimal |
| **Logo** | Henüz tasarlanıyor |

---

## 3. Teknik Stack

| | |
|---|---|
| **Mobil Framework** | Flutter |
| **Backend** | Firebase |
| **Geliştirme** | Claude Code (terminal + VS Code) |
| **Kuran Verisi** | Quran.com API'den geliştirme aşamasında bir kere çekilir, JSON olarak projeye gömülür |
| **Test** | Windows bilgisayar, Android emülatör |
| **iOS Build** | Zamanı gelince Mac erişimi sağlanacak |
| **Offline Mode** | Log girişleri internet yokken cihaza kaydedilir, bağlantı gelince otomatik senkronize olur |

---

## 4. Uygulama Navigasyonu

**Alt sekme yapısı (4 sekme):**

| Sekme | İçerik |
|---|---|
| **Hatimlerim** | Ana giriş ekranı. Aktif hatimler, yeni hatim ekleme. Üstte streak ve hasanat özeti. |
| **Ekipler** | Ekip listesi ve haftalık liderboard |
| **Profil** | İstatistikler, rozetler, gizlilik ayarları, Kuran Haritası |
| **Vird** | Marka sayfası: görüş/öneri formu, gelecek güncellemelerin duyuruları, uygulama hakkında bilgi |

---

## 5. MVP Özellikleri

### 5.1 Hesap & Profil

**Kayıt bilgileri:**
- Zorunlu: isim, kullanıcı adı, email (Google veya email ile giriş)
- İsteğe bağlı: profil fotoğrafı, şehir, üniversite

**Profilde görünenler:**
- Kimlik: profil fotoğrafı, isim, kullanıcı adı, şehir, üniversite
- İstatistikler: mevcut streak, en uzun streak, toplam sayfa, toplam hasanat, tamamlanan hatim sayısı, son 1 aylık istatistikler
- Kuran Haritası (kişisel toplam ısı haritası)
- Rozetler — iki sekme:
  - Başarılar: streak rozetleri, hatim tamamlama rozetleri, okuma rozetleri
  - Ekip rozetleri: haftalık ilk 3 madalyaları

**Gizlilik ayarı:** Tek ayar, tüm profil için — Sadece ben / Ekip arkadaşları / Herkes. Streak ve rozetler her zaman herkese açık.

**Pro kullanıcı:** MVP'de ücretsiz, pro yetki geliştirici tarafından manuel atanır. Pro kullanıcılar ekip açıp yönetebilir.

**Hafızlık rozeti:**
- Hafız olan kullanıcı belgesini sisteme yükler, geliştirici onaylar
- Profilinde "Hafız" yazar, özel sarı çerçeve görünür
- Otomatik pro yetkisi verilir

---

### 5.2 Günlük Okuma Hedefi
- Kullanıcı kendi hedefini belirler: günlük X sayfa veya X cüz (tam sayı)
- Üç log girişi yöntemi:
  - Sure seçerek
  - Sayfa aralığı girerek
  - Hatim devam: +X sayfa, kaldığı yerden otomatik ilerler
- Log girerken üstte Arapça / Meal sekmesi
- Okumalar birbirine sayılır: sure streaki ve ana hedef aynı anda düşer

---

### 5.3 Hatim Sistemi
- Aynı anda max 2 aktif hatim: Arapça + Meal
- Her hatim ayrı şema
- Hatim sıralı ilerler

---

### 5.4 Serbest Okuma
- Hatim olmadan da log girilebilir
- Kişisel Kuran Haritasına işlenir, streak ve hedefe sayılır

---

### 5.5 Sure Streaki
- Kişi bir veya birkaç sure seçer, her gün o sureyi okuyunca log girer
- Her sureye özel ayrı streak
- Ana streakten bağımsız ama okuma ana hedefe de sayılır

---

### 5.6 Streak Sistemi
- Günlük hedef tamamlanırsa streak +1, kaçırılırsa sıfırlanır
- Freeze: önceden kazanılır, kaçırılan günü korur, max 2 adet
- Repair: kaçırdıktan sonra kısa süre içinde ekstra okuyarak geri kazanılır
- Turuncu alev ikonu, tehlikedeyse animasyon ve bildirim
- Perfect Streak: freeze kullanmadan devam edince streak altın olur
- Cuma günü tamamlayınca ekstra hasanat

---

### 5.7 Hasanat Puanı
- 1 sayfa = 10 hasanat
- Görsel sayaç

---

### 5.8 Kuran Haritası (Görsel Takip)

**Hatim Şeması:**
- Hatim başlatınca özel şema açılır
- Okunan sayfalar renklenir
- Cüzler gradyan ilerler: tamamlanan cüz tam yeşil, okuma oranına göre yeşile yaklaşır

**Kişisel Toplam Kuran Haritası:**
- GitHub ısı haritası mantığı
- Tüm zamanların birikimi, çok okunan bölgeler koyu, az okunan açık
- Arapça ve Meal için ayrı görüntüleme
- Profil sekmesinde yer alır

---

### 5.9 Ekip Sistemi

**Ekip oluşturma:**
- Pro kullanıcı açar
- Ekip adı ve açıklaması yazılır
- Herkese açık veya özel seçilir

**Katılım:**
- Herkese açık ekip: direkt katılınır
- Özel ekip: davet linki ile veya istek gönderip onay beklenir

**Ekipler sekmesi:**
- Tüm açık ekipler listelenir, açıklamaları görünür
- İstek gönderilebilir

**Ekip yöneticisi yetkileri:**
- Üye kabul etme, üye çıkarma, ekibi silme

**Bir kişi birden fazla ekipte olabilir.**

**Ceza sistemi:**
- Ekip bazlı, yönetici belirler
- Haftalık sıralama altında yönetici bir ceza metni girer (baklava, çay gibi gerçek hayat cezası)
- Son 3 kişiye uygulanır
- Normalde sabit kalır, yönetici isterse o hafta değiştirebilir

---

### 5.10 Liderboard
- Haftalık hasanat puanına göre sıralama
- Her Cuma saat 13:00'de hafta tamamlanır, yeni hafta başlar
- Listede: sıra numarası, profil fotoğrafı, isim, bu haftaki hasanat puanı
- İlk 3'te madalya ikonu
- Bir kişiye tıklayınca profili açılır

---

### 5.11 Başarılar & Rozetler

**Streak rozetleri:** 7 gün, 30 gün, 100 gün, 365 gün

**Hatim rozetleri:** İlk hatim, 3. hatim, 10. hatim

**Okuma rozetleri:** İlk 100 sayfa, 500 sayfa, 1000 sayfa

**Ekip rozetleri:** Haftalık ilk 3 madalyaları

---

### 5.12 Bildirimler
- Günlük hatırlatma: kişi kendi saatini seçer
- Streak tehlike: gün bitmeden 2-3 saat kala okumamışsa uyarı
- Streak kırıldı: repair hakkı olduğu bildirimi
- Cuma bildirimi: hafta bitiyor, sıralamana bak
- Ekip bildirimi: biri seni geçince veya ilk 3'e girince

---

### 5.13 Vird Sekmesi
- Görüş ve öneri formu
- Gelecek güncellemelerin duyuruları
- Uygulama hakkında bilgi

---

## 6. Claude Code Modül Sırası

1. Proje kurulumu — Flutter + Firebase, klasör yapısı, 4 sekme iskeleti
2. Auth — kayıt, giriş (Google + email), profil oluşturma
3. Kuran verisi — JSON dosyası projeye gömme, sure/sayfa/cüz yapısı
4. Hatimlerim ekranı — aktif hatimler, yeni hatim ekleme, üstte özet
5. Log girişi — sure seçimi, sayfa aralığı, hatim devam, Arapça/Meal sekmesi
6. Streak sistemi — sayaç, freeze, repair, perfect streak, Cuma bonusu
7. Sure streaki — sure seçme, günlük log, sure bazlı sayaç
8. Hasanat sistemi — sayfa bazlı hesaplama, görsel sayaç
9. Kuran Haritası — ısı haritası, hatim şeması, gradyan sistem
10. Offline mode — cihaza kayıt, senkronizasyon
11. Ekip sistemi — oluşturma, katılım, yönetim, ceza sistemi
12. Liderboard — haftalık sıralama, Cuma 13:00 sıfırlama, madalyalar
13. Profil — istatistikler, rozetler, gizlilik, hafızlık rozeti
14. Bildirimler — tüm bildirim tipleri
15. Başarılar & Rozetler — streak, hatim, okuma, ekip rozetleri
16. Vird sekmesi — öneri formu, duyurular

---

## 7. Yayınlama

- Google Play ve App Store hesapları şahıs şirketi adına açılacak
- Google Play: $25 tek seferlik
- Apple App Store: $99/yıl, build için Mac gerekiyor

---

## 8. Gelecek Güncellemeler

### 8.1 Sistemi Olgunlaştırma
- İçerik filtreleme (uygunsuz metin engeli — kullanıcı adı, grup adı, açıklama vb.)
- Pro mode (ödemeli sistem)
- Hafızlık belge doğrulama sistemi
- Ölçekleme ve performans iyileştirmeleri

### 8.2 Yeni Özellikler
- Namaz takibi
- İslami oyun/quiz (Zip benzeri)
- Kuran ve Meal uygulama içi okuma entegrasyonu
- Tefsir takibi
- Kuran Arapçası öğrenme (Duolingo tarzı)
- Ramazan güncellemesi (oruç, teravih takip)
- Günlük ayet ve hadis
- Önemli günler hatırlatması (Kadir Gecesi, Mevlid, Regaib vb.)
- Yıllık özet (Spotify Wrapped tarzı)
- Hatim sertifikası (tamamlayınca indirilebilir dijital sertifika)
- Favori camiler profilde gösterme gibi topluluk özellikleri

---

## 9. Açık Kararlar (Henüz Konuşulmadı)

- 5-6 renk paletinin tamamı
- Logo
