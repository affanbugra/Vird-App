# Vird — Proje Durumu

> Neredeyiz? Ne öğrendik? Bu dosya her oturum başında okunur.

---

## Genel Durum (2026-04-25 — güncellendi)

- **Uygulama:** Günlük Kuran okuma takip uygulaması. Flutter + Firebase.
- **İlk kullanıcı grubu:** YTÜ Fark Kulübü (~40 kişi)
- **Test ortamı:** Her zaman `flutter run -d chrome` — emülatör RAM sorunu nedeniyle kullanılmıyor
- **Git:** Ortak repo, herkes push yapıyor

---

## Modül Tablosu

| # | Modül | Durum |
|---|-------|-------|
| 1 | Kurulum | ✅ Tamamlandı |
| 2 | Auth (Google + email, Firebase) | ✅ Tamamlandı |
| 3 | Kuran verisi entegrasyonu | ✅ Tamamlandı |
| 4 | Hatimlerim ekranı | ⬜ |
| 5 | Log girişi | ⬜ |
| 6 | Seri sistemi | ⬜ |
| 7 | Sure serii | ⬜ |
| 8 | Hasanat sistemi | ⬜ |
| 9 | Kuran Haritası (UI ✅, veri bağlantısı ⬜) | 🔶 Kısmen |
| 10 | Offline mode | ⬜ |
| 11 | Ekip sistemi | ⬜ |
| 12 | Liderboard | ⬜ |
| 13 | Profil (UI ✅) | 🔶 Kısmen |
| 14 | Bildirimler | ⬜ |
| 15 | Rozetler | ⬜ |
| 16 | Vird sekmesi (UI + Firestore form) | ✅ Tamamlandı |

---

## Tamamlanan Modüller

### Modül 1 — Kurulum (2026-04-21)

- Flutter SDK, Android Studio, NDK kurulumu
- Chrome'da `flutter run` çalışıyor
- 4 sekmeli BottomNavigationBar iskeleti
- AppColors paleti, Nunito font entegrasyonu
- **Not:** adb her oturumda manuel PATH'e ekleniyor: `$env:PATH += ";D:\Android\Sdk\platform-tools\platform-tools"`

---

### Modül 2 — Auth (2026-04-22)

- Firebase Authentication + Firestore (Test Modu)
- Onboarding ekranı `SharedPreferences` ile — sadece ilk açılışta gösterilir
- E-posta/şifre kayıt ve giriş ekranları
- `signInWithPopup` ile Web için Google ile Giriş
- `AuthWrapper`: giriş durumuna göre MainScreen / LoginScreen yönlendirmesi
- Profil sekmesi Firestore'a bağlı (isim, şehir, üniversite canlı çekiliyor)
- BottomSheet ile profil güncelleme (sayfa değiştirmeden)
- `dropdown_search` ile şehir/üniversite arama (Türkçe karakter filtresi dahil)
- 20 adet premium DiceBear avatar — Firebase Storage maliyeti yok

---

### Modül 9 & 13 (Kısmen) — Profil UI + Kuran Haritası (2026-04-25)

#### Dosyalar
- `lib/screens/profil_screen.dart` — Profil sekmesi UI tamamlandı
- `lib/data/quran_cuz.dart` — Kuran veri dosyası oluşturuldu

#### Profil Ekranı Yapısı
1. **`_ProfileHeader`** — 96dp teal banner, overlap avatar (radius 39, hafız ise gold border), dişli ikon, ad / PRO badge / username / şehir·üniversite
2. **`_StatGrid`** — `IntrinsicHeight` + `Row` + 4× `Expanded _StatCard` (Seri / Hasanat / Hatim / Sayfa)
3. **`_KuranHaritasiCard`** — filtre chips (`HeatFilter` enum), stat şeridi, `_HeatGrid`, lejant, detay paneli

#### Isı Haritası (_HeatGrid) Kararları
- `_maxPages = 20` — kare boyutu 20 sütuna göre hesaplanır
- `LayoutBuilder` ile responsive kare boyutu — hard-coded px yok
- **Fatiha satırı:** 1 kare + "Fâtiha" etiketi sağda dışarıda (`page = 0`)
- **Cüz 1–29:** 20'şer kare, standart satır
- **Cüz 30:** 2 satıra bölünür — satır 1: sayfa 581–600, satır 2: sayfa 601–604 + "İhlâs · Felak · Nâs" etiketi

#### State
```dart
enum HeatFilter { month, year, all, meal }
// _readings: Map<int, int> — {sayfa: okumaSayısı}
// MVP: boş harita. Firestore log modülünde doldurulacak.
// _selectedPage: int? — detay paneli için
```

---

### Modül 3 — Kuran Verisi (2026-04-25)

**Dosya:** `lib/data/quran_cuz.dart` — static Dart const (JSON değil; Dart const daha verimli, runtime yükü yok)

- 114 sure: id, Türkçe isim, startPage, endPage
- 30 cüz: cuzNo, startPage, endPage — Cüz 1–29: 20'şer sayfa, Cüz 30: 24 sayfa (581–604)
- Fatiha = page 0 (özel blok)
- Tüm QuranData API metodları hazır

**Not:** Ayet bazlı veri yok — MVP için gerekmiyor. Uygulama içi okuma özelliği gelirse eklenecek.

---

## Kuran Veri Sistemi (`lib/data/quran_cuz.dart`)

> Bu dosya tüm modüllerde (log, hatim takip, seri, harita) kullanılır. Dokunmadan önce oku.

### Sayfa Sistemi
- **Türkiye Diyanet mushafı** baz alındı
- **Fatiha = page 0** (özel blok, sayfalı sisteme dahil değil)
- **Sayfa 1–604:** Bakara 1. ayet = sayfa 1, Nâs = sayfa 604
- **Cüz 1–29:** Tam 20'şer sayfa (1–20, 21–40, …, 561–580)
- **Cüz 30:** 24 sayfa (581–604)

### Cüz 30 Sure→Sayfa Haritası

| Sayfa | Sureler |
|-------|---------|
| 581–582 | Nebe' |
| 582–583 | Nâziât |
| 584–585 | Abese |
| 585–586 | Tekvîr |
| 586 | İnfitâr |
| 587–588 | Mutaffifîn |
| 588–589 | İnşikâk |
| 589–590 | Bürûc |
| 590 | Târık · A'lâ |
| 591–592 | Gâşiye |
| 592–593 | Fecr |
| 593–594 | Beled |
| 594 | Şems |
| 595 | Leyl · Duhâ |
| 596 | İnşirâh · Tîn |
| 597 | Alak |
| 598 | Kadr · Beyyine |
| 599 | Zilzâl · Âdiyât |
| 600 | Kâria · Tekâsür |
| 601 | Asr · Hümeze · Fîl |
| 602 | Kureyş · Mâûn · Kevser |
| 603 | Kâfirûn · Nasr · Tebbet |
| 604 | İhlâs · Felak · Nâs |

### QuranData API

```dart
QuranData.cuzForPage(int page)      // CuzInfo? (page=0 → cüz 1)
QuranData.surahsOnPage(int page)    // "Sure1 · Sure2" string
QuranData.heatColor(int count)      // Color (6 seviye skala)
QuranData.totalNumberedPages        // 604
QuranData.surahlar                  // List<SurahInfo> — 114 sure
QuranData.cuzler                    // List<CuzInfo> — 30 cüz
```

---

---

### Modül 16 — Vird Sekmesi (2026-04-25)

#### Dosyalar
- `lib/screens/vird_screen.dart` — Vird sekmesi tamamlandı
- `lib/app_assets.dart` — Merkezi logo sabiti (`AppAssets.logo`)
- `assets/images/vird_logo.jpeg` — Yeni logo

#### Ekran Yapısı
1. **Header** — Teal banner, Türkçe hadis (Âişe hadisi, Müslim M1828), Arapça metin yok
2. **Yakında Geliyor** — `_allUpdates` const listesi (7 kart); MVP kartı yeşil (`released: true`), kalanlar teal ve alta doğru şeffaflaşır
3. **"Tüm sürüm geçmişini gör →"** — `showModalBottomSheet` + `DraggableScrollableSheet`, alt kısımda beyaz gradient sonsuzluk hissi
4. **Bir özellik öner** — `TextField` + Firestore `feature_requests` write, `_PrimaryButton` 3D depth
5. **Hakkında** — Vird'in tasavvuf terimi tanımı + açıklama
6. **Footer** — Logo (96dp, ortalı) + "YTÜ · İstanbul · 2026 · v 1.00"

#### Teknik Kararlar
- `coming_soon` Firestore StreamBuilder → hardcoded `_allUpdates` (Admin paneli MVP sonrasına alındı)
- `_Feature` → `_Update` (`released: bool` alanı eklendi); `_FeatureCard` → `_UpdateCard` (yeşil/teal renk ayrımı)
- `feature_requests` Firestore write korundu — kullanıcı önerileri Firebase'e yazılıyor
- Nav bar: "VİRD" yazısı kaldırıldı, logo 38dp `Opacity` ile aktif/pasif

#### Logo Sistemi (`lib/app_assets.dart`)
- `AppAssets.logo` tek merkezi sabit — logo değişirse sadece bu satır güncellenir
- Bağlı dosyalar: `main.dart`, `vird_screen.dart`, `login_screen.dart`, `splash_screen.dart`
- **Not:** Nav bar'da `ColorFiltered(BlendMode.srcIn)` yerine `Opacity` kullanılır çünkü JPEG'de alpha kanalı yoktur

---

## Öğrenilen Dersler

- `withOpacity()` deprecated → `withValues(alpha: ...)` kullan
- Isı haritasında `GridView` kullanma — cüz etiketi zorlaşır; `Column` içinde 30 `Row` daha iyi
- Detay panelinde sureleri `QuranData.surahsOnPage()` ile çek, hard-code yazma
- `unnecessary_non_null_assertion` lint: `e!.isNotEmpty` yerine `e.isNotEmpty`
- JPEG'de alpha kanalı yok → `ColorFiltered(BlendMode.srcIn)` boş/siyah kutu gösterir; logo tinting için `Opacity` kullan
- Yeni asset eklenince hot reload yetmez → `flutter clean` + tam `flutter run` gerekir
- UI metni (buton, açıklama, başlık) yazılmadan önce kullanıcıya öner ve onay al — direkt yazma
