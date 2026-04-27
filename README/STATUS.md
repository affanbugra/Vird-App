# Vird — Proje Durumu

> Neredeyiz? Ne öğrendik? Bu dosya her oturum başında okunur.

---

## Genel Durum (2026-04-27 — güncellendi)

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
| 4 | Hatimlerim + Tamamlanan Hatimler + Isı Haritası | ✅ Tamamlandı |
| 5 | Log girişi (kilitleme modu + fazla sayfa uyarısı) | ✅ Tamamlandı |
| 6 | Seri sistemi | ⬜ |
| 7 | Sure serii | ⬜ |
| 8 | Hasanat sistemi | ✅ Tamamlandı |
| 9 | Kuran Haritası (UI ✅, veri bağlantısı ✅) | ✅ Tamamlandı |
| 10 | Offline mode | ⬜ |
| 11 | Ekip sistemi | ⬜ |
| 12 | Liderboard | ⬜ |
| 13 | Profil (UI ✅, ısı haritası veri bağlantısı ✅) | ✅ Tamamlandı |
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

#### State (güncel)
```dart
enum HeatTypeFilter { arapca, meal }   // Tür filtresi — ARAPÇA/MEAL segmented badge
enum HeatTimeFilter { all, month, year } // Zaman filtresi — chip satırı
// _typeFilter: HeatTypeFilter — Firestore query'de where('type', ...) ile kullanılır
// _timeFilter: HeatTimeFilter — client-side filtreleme; composite index gerektirmez
// _readings: Map<int, int> — {sayfa: okumaSayısı}
// _selectedPage: int? — detay paneli için
```

#### Filtre Mimarisi (güncel)
- Tür ve zaman filtreleri **bağımsız** — önceki `HeatFilter` enum'u ikisini birleştiriyordu, hata yapıyordu
- `_buildLogsQuery`: yalnızca `.where('type', ...)` — tek alan filtresi, index gerekmez
- `_buildReadingsFromLogs`: zaman filtresi `createdAt` karşılaştırmasıyla client-side uygulanır
- Tür filtresi: ARAPÇA/MEAL badge'i başlık satırının sağında (segmented toggle görünümü)
- Zaman filtresi: Tüm zamanlar | Son 1 ay | Son 1 yıl — altta chip satırı olarak kalır

#### Metrikler (güncel)
- **Profil:** SAYFA (benzersiz) | OKUMA (toplam) | CÜZ (X/30 — tamamlanan cüz sayısı)
- **Hatim:** SAYFA | CÜZ | KALAN
- KAPSAM % metriği kaldırıldı — genel haritada yanıltıcıydı

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
QuranData.cuzForPage(int page)                      // CuzInfo? (page=0 → cüz 1)
QuranData.surahsOnPage(int page)                    // "Sure1 · Sure2" string
QuranData.heatColor(int count)                      // Color — sabit eşikler (6 seviye)
QuranData.heatColorRelative(int count, int maxCount) // Color — göreli skala, taban=10
QuranData.totalNumberedPages                        // 604
QuranData.surahlar                                  // List<SurahInfo> — 114 sure
QuranData.cuzler                                    // List<CuzInfo> — 30 cüz
```

**`heatColorRelative` notu:** `max(maxCount, 10)` taban kullanır. Max=1 olsa bile tek okunan sayfa açık renk kalır. Profil haritası bu metodu kullanır; lejant gösterimi `heatColor` ile kalır.

---

---

### Modül 16 — Vird Sekmesi (2026-04-25)

#### Dosyalar
- `lib/screens/vird_screen.dart` — Vird sekmesi tamamlandı
- `lib/app_assets.dart` — Merkezi logo sabiti (`AppAssets.logo`)
- `assets/images/vird_logo.jpeg` — Yeni logo

#### Ekran Yapısı
1. **Header** — Teal banner, Türkçe hadis (Âişe hadisi, Müslim M1828), Arapça metin yok
2. **Yakında Geliyor** — `_allUpdates` const listesi (9 kart); Ekipler ve Uygulama İçi Okuma eklendi. MVP kartı yeşil (`released: true`), kalanlar teal ve alta doğru şeffaflaşır
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
- `AppAssets.ricalIFarkLogo` — Ekipler sayfası için takım logosu
- Bağlı dosyalar: `main.dart`, `vird_screen.dart`, `login_screen.dart`, `splash_screen.dart`, `ekipler_screen.dart`
- **Not:** Nav bar'da `ColorFiltered(BlendMode.srcIn)` yerine `Opacity` kullanılır çünkü JPEG'de alpha kanalı yoktur

---

### Modül 11 (Başlangıç) — Ekipler Arayüzü (YENİ)
- `EkiplerScreen` sayfası eklendi. Şimdilik "Çok yakında" mesajı ve örnek bir takım (`Ricâl-i Fark`) butonu barındırıyor.
- `DuolingoButton` bileşenine `borderRadius` özelliği eklendi; böylece tam yuvarlak hap şeklinin yanında kare-yuvarlak formda takım/rozet butonları da yapılabiliyor.
- `assets/images/rical_i_fark_logo.png` eklendi ve `pubspec.yaml`'a dahil edildi.


---

### Modül 4 & 5 — Hatimlerim + Log Girişi (2026-04-25 başladı, 2026-04-27 son güncelleme)

#### Dosyalar
- `lib/screens/hatimlerim_screen.dart` — Aktif hatimler sekmesi
- `lib/screens/tamamlanan_hatimler_screen.dart` — Tamamlanan hatimler listesi (YENİ)
- `lib/widgets/hatim_heat_map_sheet.dart` — Per-hatim ısı haritası bottom sheet (YENİ)
- `lib/widgets/log_entry_bottom_sheet.dart` — 4 tab'lı okuma kaydı (kilitleme modu + uyarı)
- `lib/widgets/log_history_sheet.dart` — Kayıt geçmişi (düzenleme + silme)
- `lib/models/hatim_model.dart` — Hatim veri modeli (`isCompleted`, `completedAt` alanları eklendi)
- `lib/models/reading_log_model.dart` — Okuma log veri modeli

#### Hatim Model (`hatim_model.dart`)
```dart
isCompleted: (data['isCompleted'] as bool?) ?? false,   // geriye uyumlu — null → false
completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
```
- Eski Firestore dokümanlarında `isCompleted` alanı yok → `false` varsayılan
- Tamamlanma şartı: `newCurrentPage >= 604 && !linkedHatim.isCompleted`
- Tamamlanınca: `batch.update(hatimRef, {'isCompleted': true, 'completedAt': serverTimestamp()})`
- Aynı batch'te `users/{uid}` altında `hatimCount: increment(1)` eklenir

#### Hatimlerim Ekranı
1. **Seri & Hasanat kartları** — Firestore'dan `seri` ve `hasanat` alanları canlı
2. **Aktif Hatimler listesi** — StreamBuilder + `_deletingIds Set` (Dismissible/StreamBuilder çakışma önlemi)
3. **Yeni Hatim Başlat** — FAB; Arapça ≤ 3 / Meal ≤ 1 limit, sayaç badge'leri, opsiyonel isim alanı
4. **Hatim silme** — Sola swipe → kırmızı zemin → AlertDialog onayı → Firestore delete
5. **Hatim kartı** — Minimal: ikon + başlık + `XX/604 sayfa · X. cüz` + progress bar + sağda grid ikonu
6. **Kart tıklama** — Kartın herhangi yerine veya grid ikonuna basmak → `HatimHeatMapSheet.show()` açar
7. **Tamamlanan hatimler butonu** — Liste altında; tamamlanan sayısı varsa görünür, `TamamlananHatimlerScreen`'e yönlendirir
8. **DEVAM ET** — Kart'tan kaldırıldı; ısı haritası sayfasının üstünde yer alır

#### Tamamlanan Hatimler Ekranı (`tamamlanan_hatimler_screen.dart`)
- Firestore query: `.where('isCompleted', isEqualTo: true)` — composite index gerektirmesin diye `orderBy` YOK
- Client-side sort: `completedAt ?? updatedAt` desc
- Kart: yeşil border, "604/604 sayfa · tarih", TAMAM badge, grid ikonu
- Kart herhangi yerine tıklama → `HatimHeatMapSheet.show()` (onDevamEt: null, buton gösterilmez)
- Swipe-to-delete + AlertDialog onayı

#### Hatim Isı Haritası (`hatim_heat_map_sheet.dart`)
- Yalnızca o hatimin logları: `.where('hatimId', isEqualTo: hatim.id)`
- **Binary renk:** okundu = `Color(0xFF38A474)` (yeşil-teal), okunmadı = `AppColors.borderGrey`
- **Fatiha karesi:** `usePage1Color: true` → `readPages.contains(1)` ile renk belirlenir (page 1 ile aynı)
- **Tıklama → detay:** `ValueNotifier<int?> _selectedPage` state; `ValueListenableBuilder` ile lokal rebuild (tüm sayfa render'lanmaz, layout sıçraması/beyaz ekran önlenir). Sabit `_DetailPanel` profildeki gibi çalışır.
- **Metrikler:** SAYFA | CÜZ (tamamlanan cüz/30) | KALAN
- **DEVAM ET butonu:** `onDevamEt` callback varsa sayfanın en üstünde; `Navigator.pop` + `addPostFrameCallback` ile hatim log sheet açılır
- **Kilitleme:** `onDevamEt` ile açılınca `LogEntryBottomSheet` o hatim kilitli açılır
- **Tarih bilgileri (`_HatimDatesRow`):** başlangıç tarihi; tamamlananlar için bitiş + süre (`_fmtDuration`: <30 gün → "X gün", ≥30 gün → "X ay Y gün")
- **Son Okumalar:** son 3 log (client-side sort); dişli ikon + "Tümünü gör (N)" → `_AllLogsSheet`
- **`_AllLogsSheet`:** Tüm hatim logları StreamBuilder ile canlı; swipe-to-delete → `batch(doc.delete, hasanat -= pagesRead×10, totalPages -= pagesRead)` ve otomatik `HatimCalculator.recalculate`
- **Tüm Kayıtları Sil:** Geçmiş altındaki kırmızı buton. Logları 400'lük gruplar halinde (batch limit) güvenli şekilde siler, hasanat ve totalPages'i sıfırlar, etkilenen hatimleri `recalculate` ile günceller.

#### HatimCalculator & HatimRemover (`utils/`)
- **`HatimCalculator.recalculate`:** Bir hatimin tüm loglarını kronolojik olarak çeker. Okunan sayfaları bir `Set<int>` içine doldurur (benzersiz okunan sayfalar). Ayrıca `lastReadPage`'i (okunan en yüksek sayfa numarası) hesaplar. `Set.length >= 604` ise ve 1'den 604'e kadar tüm sayfalar okunmuşsa hatimi tamamlanmış sayar. Tamamlanma artık dinamiktir.
- **`HatimRemover`:** Firestore batch 500 limitine takılmamak için logları 400'erli gruplar halinde siler. Hatim silinince tüm ilgili okuma loglarını silip profildeki hasanat ve toplam sayfa puanlarını geriye doğru eksiksiz düzeltir. Isı haritalarından kayıtları otomatik temizlemiş olur.

#### Log Girişi Bottom Sheet — Güncellemeler
- **Kilitleme modu** (`_lockedToHatim = initialHatim != null`):
  - TabController length: 3 (Sure sekmesi gizlenir)
  - `_devamHatim`, `_sayfaHatim`, `_cuzHatim` hepsi `initialHatim` ile başlatılır
  - Devam tab'da "Değiştir" butonu gizlenir
  - Sayfa/Cüz tab'larında chip seçimi yerine `_LockedHatimBadge` gösterilir
- **Fazla sayfa uyarısı:** Devam tab'da `currentPage + pagesRead > 604` ise dialog:
  - "X sayfa kaldı ama Y sayfa girdin. Hatim tamamlandı olarak işaretlenecek."
  - İptal / Tamam; İptal → kayıt yapılmaz

#### Log Geçmişi Bottom Sheet (`log_history_sheet.dart`)
- Ekran yüksekliğinin %68'i, tüm loglar StreamBuilder ile (limit yok)
- Her satır: yöntem ikonu + başlık + tip badge + göreli zaman + düzenle/sil ikonları
- **Silme:** AlertDialog → batch(log sil, hasanat -= pagesRead×10, totalPages -= pagesRead) ve `HatimCalculator.recalculate`
- **Düzenleme (`_LogEditSheet`):** Metoda özel form; batch ile fark hesabı (Δhasanat, ΔtotalPages) ve otomatik `recalculate`.
- **Tüm Kayıtları Sil Butonu:** Batch limit sorunu çözülerek 400'lü chunk'lar halinde loglar silinir. Puanlar eksi olarak hesaplanarak güncellenir.
- **Tasarım:** Ana butonlar ("DEVAM ET", "KAYDET", "BAŞLAT") tutarlılık için `DuolingoButton` component'i yapıldı.

#### Firestore Şeması (güncel)
```
users/{uid}/hatims/{hatimId}
  type: 'arapca' | 'meal'
  name: string?
  currentPage: int           ← Benzersiz okunan sayfa adedi (0-604)
  lastReadPage: int          ← YENİ (Okunan en yüksek ardışık sayfa numarası)
  totalPages: 604
  isCompleted: bool          ← YENİ (eski dokümanlarda yok → false kabul edilir)
  completedAt: Timestamp?    ← YENİ (sadece tamamlanan hatimlerde)
  createdAt: Timestamp
  updatedAt: Timestamp       ← FieldValue.serverTimestamp()

users/{uid}/logs/{logId}
  type: 'arapca' | 'meal'
  method: 'hatim' | 'surah' | 'pages' | 'cuz'
  pagesRead: int
  surahId: int?
  startPage: int?
  endPage: int?
  hatimId: string?
  createdAt: Timestamp

users/{uid} (root doc)
  hasanat: int
  totalPages: int
  seri: int
  hatimCount: int            ← YENİ (tamamlanan hatim sayacı)
```

---

### Modül 8, 9 & 13 — Hasanat + Kuran Haritası Veri Bağlantısı + Profil (2026-04-25)

> Collaborator tarafından geliştirildi.

#### Hasanat Sistemi (Modül 8)
- **Formül:** 1 sayfa = 10 hasanat
- Log kaydında `FieldValue.increment(pagesRead * 10)` ile `hasanat` alanı güncellenir
- `totalPages` da aynı batch'te `FieldValue.increment(pagesRead)` ile güncellenir

#### Kuran Haritası Veri Bağlantısı (Modül 9)
- `profil_screen.dart`'taki `_readings` map'i artık Firestore'dan dolduruluyor
- `_buildReadingsFromLogs()` — log kayıtlarındaki `startPage`-`endPage` aralığını sayfa bazlı okuma sayısına çevirir
- `_buildLogsQuery()` — filtre bazlı Firestore query:
  - **Tüm zamanlar:** tüm loglar (filtre yok)
  - **Son 1 ay:** `createdAt >= 30 gün önce` + `type == 'arapca'`
  - **Son 1 yıl:** `createdAt >= 365 gün önce` + `type == 'arapca'`
  - **Meal:** `type == 'meal'`
- `StreamBuilder<QuerySnapshot>` ile gerçek zamanlı güncelleme

---

## Öğrenilen Dersler

- `withOpacity()` deprecated → `withValues(alpha: ...)` kullan
- Isı haritasında `GridView` kullanma — cüz etiketi zorlaşır; `Column` içinde 30 `Row` daha iyi
- Detay panelinde sureleri `QuranData.surahsOnPage()` ile çek, hard-code yazma
- `unnecessary_non_null_assertion` lint: `e!.isNotEmpty` yerine `e.isNotEmpty`
- JPEG'de alpha kanalı yok → `ColorFiltered(BlendMode.srcIn)` boş/siyah kutu gösterir; logo tinting için `Opacity` kullan
- Yeni asset eklenince hot reload yetmez → `flutter clean` + tam `flutter run` gerekir
- UI metni (buton, açıklama, başlık) yazılmadan önce kullanıcıya öner ve onay al — direkt yazma
- Farklı Kuran veri sistemleri varsa (JSON+Provider vs Static Const) → ana projenin sistemini baz al, uyumluluk sağla
- Collaborator entegrasyonunda Firestore alan isimlerini ana projeyle eşle (ör: `currentStreak` → `seri`)
- `FieldValue.increment()` kullanarak batch içinde atomik güncelleme yap — race condition önlenir
- **`FieldValue.serverTimestamp()` crash:** Firestore'a `serverTimestamp()` yazınca istemci tarafında kısa süre `null` döner. `fromFirestore`'da `(data['updatedAt'] as Timestamp)` cast'i çöker → `(data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now()` kullan
- **`Dismissible` + `StreamBuilder` çakışması:** Silme işlemi Firestore'a gidip dönene kadar item listede kalır; silme animasyonu biter ama item tekrar görünür → `_deletingIds Set` ile client-side filtreleme çözer
- **Göreli ısı haritası taban:** Saf `count/maxCount` oranı — max=1 iken tek okuma en koyu rengi alır, saçma görünür. Taban `max(maxCount, 10)` ile hem göreli hem gerçekçi dağılım sağlanır
- **Paylaşımlı toggle + başlangıç tipi:** `LogEntryBottomSheet` dışarıdan `initialHatim` ile açılırsa `_globalType = initialHatim.type` ile başlatmak gerekir; aksi hâlde sekme değiştirince tip sıfırlanır
- **Chip filtresi:** Arapça/Meal toggle'ı değişince hatim chip listesi de filtrelenmeli — aksi hâlde yanlış tipteki hatimler gösterilir ve yanlış log yazılır
- **Firestore composite index tuzağı:** `orderBy + where` birden fazla alan içerince composite index oluşturmak gerekir; `orderBy` kaldırılıp sıralama client-side yapılırsa index gerekmez ve query basitleşir
- **Geriye uyumlu model alanı:** Yeni bool alan eklenince `(data['isCompleted'] as bool?) ?? false` — null-safe default olmadan eski dokümanlar crash yapar
- **`Dismissible` + `StreamBuilder` çakışması (tamamlanan):** `_deletingIds Set` ile client-side filtreleme; hem `hatimlerim_screen.dart` hem `tamamlanan_hatimler_screen.dart` hem `_AllLogsSheet`'te aynı pattern kullanılır
- **Log silme sınırı:** `_AllLogsSheet`'te log silinince `hasanat` ve `totalPages` güncellenir ama hatim `currentPage` güncellenmez (geriye dönük hesap karmaşık); kullanıcı yeni doğru log ekleyebilir
- **Fazla sayfa kontrolü:** `pagesRead <= 0` kontrolünden sonra, `setState` öncesinde; dialog await'i öncesinde hiç `async` olmadığından `context` güvenli kullanılır
- **TabController length dinamik:** `_lockedToHatim` true iken `length: 3` (Sure sekmesi yok); `initState`'te `widget.initialHatim != null` kontrolüyle belirlenir — `initState`'te `widget` erişilebilir
- **Dinamik Hatim Tamamlanma (Set Kontrolü):** Sadece "30. cüzü okudum" demekle veya son sayfa 604 olunca hatim tamamlanmamalıdır. `Set<int>` kullanılarak tüm sayfalar (1-604) tek tek okunmuş mu kontrol edilmelidir.
- **Sıralı Okuma vs Benzersiz Sayfa Sayısı:** `currentPage` benzersiz okunan sayfa adedini, `lastReadPage` ise Devam sekmesindeki sıralı okumada en son nerede kalındığını (en yüksek sayfa numarası) tutmak üzere iki ayrı metrik olarak tasarlanmalıdır.
- **Kullanıcı Kayıt Akışı Uyumluluğu:** Profil düzenleme gibi ekranlarda istenen bilgiler, onboarding/kayıt aşamasındaki zorunluluklarla tutarlı olmalıdır (Örn: Username girişte zorunlu değildi, bu yüzden profil düzenlemede de opsiyonel olmalıdır).
