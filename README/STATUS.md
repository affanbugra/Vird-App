# Vird — Proje Durumu

---

## Dosya Haritası

Adından anlaşılmayan veya kritik detay içeren dosyalar:

| Dosya | Not |
|---|---|
| `lib/providers/theme_provider.dart` | ChangeNotifier; SharedPreferences key `'isDarkMode'` ile tema kalıcılaştırma. `toggle()` light↔dark geçiş. |
| `lib/app_theme.dart` | `VirdColors` ThemeExtension (light/dark renk setleri) + `AppTheme.light/dark`. Tüm UI renkleri buradan alınır. |
| `lib/screens/ekip_profil_screen.dart` | Ekip profili + haftalık liderboard (client-side `periodStart`) |
| `lib/screens/profil_screen.dart` | Kendi profili — Kuran haritası + `_HafizSheet` (doğrulama başvurusu) bu ekranda |
| `lib/screens/kullanici_profil_screen.dart` | Başka kullanıcı profili — read-only |
| `lib/screens/dev_panel_screen.dart` | DevPanel — bug/plan/fikir/feedback + Hafız başvuruları + Yol Haritası yönetimi (sadece developer görür) |
| `lib/screens/vird_screen.dart` | Vird sekmesi — yol haritası (Firestore'dan dinamik) + öneri formu |
| `lib/data/roadmap_entry.dart` | Yol haritası kart modeli — `RoadmapEntry`, `fromDoc`, `toMap`, `copyWith` |
| `lib/widgets/log_entry_bottom_sheet.dart` | Log girişi — 4 tab, kilitleme modu, seri animasyon tetikleyici |
| `lib/widgets/duolingo_button.dart` | Primary buton bileşeni (3D depth) — adı yanıltıcı, aslında AppButton |
| `lib/utils/seri_calculator.dart` | Seri hesabı — anchor-day algoritması, `seriDisplayState()`. `atRisk` yalnızca saat 18:00+ aktif |
| `lib/utils/hatim_calculator.dart` | Hatim tamamlanma — `Set<int>` yaklaşımı, `Future<bool>` döndürür |
| `lib/data/quran_cuz.dart` | Kuran veri sistemi — tüm modüllerde kullanılır, dokunmadan önce oku |
| `lib/data/tilavet_secde.dart` | 14 tilavet secdesi sayfa verisi |
| `lib/providers/user_provider.dart` | `isDeveloper`, `developerTeamIds`, `isHafiz` — global developer/hafız state |
| `lib/config/team_limits.dart` | Ekip katılım/kurma limitleri (normal/pro/dev) + kullanıcıya gösterilecek hata metinleri |
| `lib/services/streak_freeze_service.dart` | Seri dondurma iş mantığı — `grantFreeze`, `applyFreeze`, `claimMilestones` |
| `lib/screens/streak_freeze_reward_screen.dart` | Milestone ödül ekranı — buz kristali animasyonu, dark navy tasarım |

---

## Firestore Şemaları

### `users/{uid}` (root doc)
```
hasanat:          int
totalPages:       int
seri:             int
lastLogDate:      Timestamp
hatimCount:       int (sayaç — profilde isCompleted query tercih edilir)
teamId:           string?
teamJoinedAt:     Timestamp? (retroaktif liderboard katılımını önler)
isPro:            bool? (Console'dan elle atanır, in-app değiştirilemez)
isDeveloper:      bool (Console'dan elle — DEV badge + çoklu ekip desteği)
developerTeamIds: List<String> (developer birden fazla ekibin liderboardunda görünür)
isHafiz:          bool? (Console veya DevPanel'den onaylanınca true — HAFIZ badge)
cinsiyet:         'bey' | 'hanim' | '' (profil kurulumunda seçilir; ekip gender filtresi için kullanılır)
username:         string
avatarSeed:       string? (20 önceden belirlenmiş DiceBear seed — Storage maliyeti yok)
name:             string
city:             string?
university:       string?
weeklyHasanat:     int? (bu haftaki birikmiş hasanat — liderboard hızlandırma için)
weeklyStartDate:   string? ("YYYY-MM-DD" formatında haftanın Pazartesisi)
prevWeeklyHasanat: int? (geçen haftanın dondurulmuş hasanatı — arşiv snapshot için)
prevWeeklyStartDate: string? (geçen haftanın Pazartesisi — arşiv eşleştirme için)
streakFreezes:     int? (mevcut dondurma hakkı — default 0; normal max 2, pro max 5)
frozenDates:       List<String>? ('YYYY-M-D' formatında dondurulan günler — seri hesabında okuma logu gibi sayılır)
claimedStreakMilestones: List<int>? (alınan milestone günleri: [7, 14, 21, 40] — tekrar claim'i önler)
```

### `users/{uid}/hatims/{hatimId}`
```
type:            'arapca' | 'meal'
name:            string? (opsiyonel)
currentPage:     int    (benzersiz okunan sayfa adedi — Set<int> ile hesaplanır)
lastReadPage:    int    (en yüksek okunan sayfa numarası — Devam sekmesi için)
firstUnreadPage: int    (1-604 arası ilk okunmamış — eski doc'larda null → 1 varsayılan)
totalPages:      604
isCompleted:     bool   (eski doc'larda alan yok → false varsayılan)
completedAt:     Timestamp? (sadece tamamlananlar)
createdAt:       Timestamp
updatedAt:       Timestamp  ← serverTimestamp! fromFirestore'da null-safe cast zorunlu
```
**Limit:** Arapça ≤ 3, Meal ≤ 1 (toplam max 4 aktif)

### `users/{uid}/logs/{logId}` (Kuran okuma)
```
type:      'arapca' | 'meal'
method:    'hatim' | 'surah' | 'pages' | 'cuz'
pagesRead: int
surahId:   int?
startPage: int?
endPage:   int?
hatimId:   string?
createdAt: Timestamp
```

### `users/{uid}/logs/prayer_YYYY-MM-DD` (Namaz)
```
type:    'prayer'
date:    'prayer_YYYY-MM-DD'
prayers: { sabah, ogle, ikindi, aksam, yatsi: 'none'|'onTime'|'kaza'|'cemaat' }
```

### `users/{uid}/logs/habit_defs` (Alışkanlık tanımları)
```
items: [{ id, title, color, createdAt }]
```

### `users/{uid}/logs/YYYY-MM-DD_{habitId}` (Alışkanlık logları)
```
completed: bool
date:      'YYYY-MM-DD'
habitId:   string
```

### `teams/{teamId}`
```
name:              string
description:       string
penaltyNote:       string
adminUid:          string
memberCount:       int
isPrivate:         bool (true → listede görünmez)
genderPolicy:      'men' | 'women' | 'all'
showCrossGenderNames: bool (false → karşı cins isimlerini sansürle)
inviteCode:        string (6 haneli, örn. "XK7P2Q")
createdAt:         Timestamp
```

### `users/{uid}/notifications/{notifId}`
```
type:      'team_invite' | 'team_join' | 'join_request' | 'join_approved' | 'join_rejected' | 'announcement' | 'message'
title:     string
body:      string
isRead:    bool
teamId:    string? (join_request tipinde — admin tıklayınca EkipProfilScreen açılır)
createdAt: Timestamp
```
`announcement` tipine tıklanınca `showRoadmapSheet()` açılır.

### `teams/{teamId}/requests/{uid}`
```
name:        string
username:    string
avatarSeed:  string?
requestedAt: Timestamp
```
⚠️ `orderBy` YOK — serverTimestamp pending write'da null döner → crash.

### `hafiz_requests/{uid}` (uid = doc key — kullanıcı başına 1 başvuru)
```
uid:         string
name:        string        (formdan girilen ad soyad)
username:    string
avatarSeed:  string?
driveLink:   string        (onay sonrası FieldValue.delete() ile siliniyor — gizlilik)
status:      'pending' | 'approved' | 'rejected'
note:        string?       (red mesajı — kullanıcıya gösterilir)
consentGiven: bool
consentAt:   Timestamp
requestedAt: Timestamp
reviewedAt:  Timestamp?
```
**Not:** Onaylanınca `users/{uid}.isHafiz = true` set edilir. Tekrar başvuruda doküman üzerine yazılır.

### `roadmap_entries/{entryId}`
```
type:      'released' | 'upcoming'
title:     string
version:   string?    // "v1.2"
date:      string?    // "2026-05-17" (released için)
eta:       string?    // "Yakında" | "Ramazan 2027" (upcoming için)
order:     int        // sıralama — batch update ile yönetilir
bullets:   List<string>
published: bool       // false = taslak, kullanıcılar göremez
```

### `feedback_labels/{labelId}`
```
name:     string
colorHex: string (örn. '#FF6B6B')
```

### `feature_requests/{requestId}`
```
folderId: string? (null veya empty = Gelen Kutusu)
```

---

## Kuran Veri Sistemi (`lib/data/quran_cuz.dart`)

Tüm modüllerde (log, hatim, seri, harita) kullanılır. Dokunmadan önce oku.

- **Türkiye Diyanet mushafı** baz alındı
- **Fatiha = page 0** (özel blok)
- **Sayfa 1–604:** Bakara = 1, Nâs = 604
- **Cüz 1–29:** 20'şer sayfa · **Cüz 30:** 24 sayfa (581–604)

```dart
QuranData.cuzForPage(int page)                       // CuzInfo?
QuranData.surahsOnPage(int page)                     // "Sure1 · Sure2"
QuranData.heatColor(int count)                       // Color — sabit eşikler
QuranData.heatColorRelative(int count, int maxCount) // Color — göreli skala, taban max(count,10)
QuranData.totalNumberedPages                         // 604
QuranData.surahlar                                   // List<SurahInfo> — 114 sure
QuranData.cuzler                                     // List<CuzInfo> — 30 cüz
```

**Kural:** `QuranData.surahsOnPage()` kullan, sure isimlerini hard-code yazma. Collaborator farklı sistem (JSON+Provider) getirirse reddet — iki paralel sistem bakım yükü ve bug kaynağıdır.

---

## Teknik Kararlar

- **Seri hesabı:** Anchor-day algoritması — önce en son log gününü bul, oradan geriye say. Bugünden geriye saymak, bugün log yokken seriyi yanlış sıfırlar. `seriDisplayState(rawSeri, lastLogTs)` donmuş Firestore değerini her render'da gerçek zamanlı düzeltir.
- **Liderboard reset:** Client-side, `periodStart` dinamik hesabı. Cloud Function yok (MVP ölçeği için kabul edilebilir; büyüyünce denormalized field + Cloud Function gerekir).
- **Liderboard hızlandırma:** `weeklyHasanat` + `weeklyStartDate` user doc'ta tutulur. Log kaydında güncellenir; hafta değişince `prevWeekly*` alanlarına taşınır. **Şu an:** liderboard mevcut hafta için her zaman log sorgusunu kullanır (fast path kaldırıldı — geçiş dönemi bug'ı nedeniyle). Arşiv de log sorgusundan oluşturulur; geçen hafta arşivi her açılışta yeniden hesaplanır. `weeklyHasanat` yazılmaya devam ediyor — sistem stabil hale gelince fast path geri eklenebilir. Ekip büyüyünce (100+ üye) `teams/{teamId}` doc'una deneşleme + Cloud Function gerekir.
- **teamJoinedAt:** Ekibe sonradan katılanlar geçmiş haftalara dahil edilmez — bu field olmazsa yeni üye tüm geçmiş puanlarla görünür.
- **isPro:** Firebase Console'dan elle atanır. In-app değiştirme yok.
- **isDeveloper:** Console'dan elle. DEV badge + `developerTeamIds` ile birden fazla ekipte görünebilir.
- **Bildirim:** `cancelForToday()` log kaydedilince çağrılır, bildirimi yarından itibaren resetler. `init()`'te auto-reschedule koyma — uygulama açılışında o gün okuyup okumadığı bilinmez.
- **Hatim ilerleme:** `currentPage` benzersiz sayfa adedi (Set<int>), `lastReadPage` en yüksek sayfa numarası — ikisi farklı amaçlara hizmet eder.
- **`recalculate()` dönüş tipi:** `Future<bool>` — `true` ise o çağrıda hatim ilk kez tamamlandı. Hatim tamamlama popup'ı bu değere göre açılır.
- **Firestore rules — logs okuma:** Liderboard cross-user okuma gerektirir → `isAuth()` yeterli, `isOwner()` değil.
- **Firestore rules — teamId güncelleme:** Başka kullanıcı sadece `teamId` alanını güncelleyebilmeli → `affectedKeys().hasOnly(['teamId'])`.
- **Feedback inbox:** `folderId == null || folderId.isEmpty` = Gelen Kutusu. Klasöre taşınınca Gelen Kutusu'ndan kalkar.
- **isHafiz atanma:** DevPanel → Hafız Başvuruları → Onayla butonu `users/{uid}.isHafiz = true` set eder. Console'dan da elle atanabilir. In-app değiştirilemez.
- **Yol haritası yönetimi:** `roadmap_entries` koleksiyonu; `published: false` = taslak (kullanıcı görmez). DevPanel → Neler Geldi ekranından CRUD + sürükle-bırak sıralama. VirdScreen sadece `published: true` olanları gösterir (client-side filtre). `order` alanı batch update ile yönetilir.
- **Dinamik versiyon string:** VirdScreen footer'ındaki versiyon (`YTÜ · İstanbul · 2026 · vX.X`) otomatik hesaplanır: `published == true && type == 'released'` olanlar içinde `order` en yüksek olanın `version` alanından alınır. `version` alanı boş bırakılan kartlar hesaba katılmaz; hiç kart yoksa `v 1.00` fallback.
- **Yol haritası bottom sheet sekmeler:** "Tüm sürüm geçmişini gör" sheet'i `_RoadmapSheet` stateful widget'ı — Neler Geldi / Neler Geliyor sekmeleri. Yayındakiler en yeniden eskiye (reversed), yakındakiler sırasıyla gösterilir. `order` alanı her iki grupta bağımsız, görüntüleme sırası type'a göre ayrılır.
- **Hafız doğrulama gizlilik:** Onay verilince `hafiz_requests/{uid}.driveLink` alanı `FieldValue.delete()` ile silinir. Belge verisi sistemde tutulmaz (KVKK uyumu).
- **seriDisplayState `atRisk`:** Yalnızca günün son 6 saatinde (`now.hour >= 18`) true döner. Sabah erken saatlerde "tehlikede" göstermek kullanıcı deneyimini bozduğu için bu eşik seçildi.
- **Ekip cinsiyet politikası (`genderPolicy`):** `men` | `women` | `all`. Herkese açık (`isPrivate: false`) ekip yalnızca `men` veya `women` olabilir; `genderPolicy == 'all'` ekipler daima `isPrivate: true`. Yanlış cinsiyetteki kullanıcılar ekip listesinde görmez, profil sayfasına girerlerse `_GenderBlockedTeamView` gösterilir. `isDeveloper` bu kuralı baypas etmez.
- **İsim sansürü (`showCrossGenderNames: false`):** `genderPolicy == 'all'` ekipte karşı cins üyeler için `isim.split(' ').map(w => w[0] + '*****').join(' ')`. Kendi profili asla sansürlenmez. Liderboard dışında (örn. admin üye yönetimi) tam isim gösterilir.
- **Liderboard profil tıklaması — karışık ekiplerde kapalı:** `_LeaderboardSection.onMemberTap` nullable. `genderPolicy == 'all'` ise `null` geçilir → tüm tıklamalar devre dışı. Böylece karışık ekipte üyeler birbirinin profilini açamaz.
- **Herkese açık ekip join akışı:** Üye olmayan kullanıcı herkese açık ekip profilini açarsa tam içerik değil `_PublicTeamJoinView` gösterilir (ekip adı, üye sayısı, cinsiyet rozeti, açıklama, katılım butonu). Leaderboard veya admin araçları gösterilmez.
- **Hata yönetimi:** `ErrorWidget.builder` → `_AppErrorWidget` (kırmızı ekran yerine kullanıcı dostu hata). `FlutterError.onError` → Firestore `app_errors` koleksiyonuna yazar (error, stack max 2000 karakter, library, platform, createdAt). DevPanel → Hata Kayıtları ekranından izlenir.
- **Bildirim sistemi:** `users/{uid}/notifications` subcollection. `announcement` tipine tıklanınca `showRoadmapSheet(context)` açılır — `vird_screen.dart`'ta top-level public fonksiyon. Toplu bildirim (broadcast) admin araçları ile Cloud Function üzerinden yapılır; in-app broadcast UI şu an aktif değil.
- **`showRoadmapSheet` erişilebilirliği:** `vird_screen.dart` içinde class dışı top-level fonksiyon olarak tanımlandı. Hem `VirdScreen` hem `BildirimlerScreen` bu fonksiyonu çağırabilir — içe aktarma yeterli.
- **Seri dondurma (Streak Freeze):** `frozenDates` user doc'ta `List<String>` ('YYYY-M-D') olarak tutulur. `SeriCalculator.recalculate()` bu günleri gerçek log gibi sayar → eski kullanıcı doc'ları alandaki yokluğu `[]` olarak varsayar, mevcut seri hesabı etkilenmez. Retroaktif onarım yalnızca "dün" için — `SeriCalendarSheet` repair banner + dialog gösterir. Milestone'lar (7/14/21/40 gün): `log_entry_bottom_sheet.dart`'ta log kaydı sonrası kontrol edilir, `claimedStreakMilestones` listesiyle tekrar claim önlenir. `StreakFreezeRewardScreen` seri animasyonunun ardından açılır. Hasanat ile satın alma butonu disabled "Yakında" badge'li — özellik henüz aktif değil (bot abuse riski önlenene kadar).
- **Seri dondurma limitleri:** `lib/services/streak_freeze_service.dart` → normal kullanıcı max 2, pro max 5. `clampToMax` mantığı: `grantFreeze` ve `claimMilestones` ikisi de `clamp(0, maxFreezes)` uygular.
- **Dark mode:** `VirdColors` ThemeExtension (`lib/app_theme.dart`) ile iki renk seti — `VirdColors.light` ve `VirdColors.dark`. Tüm widget'larda `context.colors.*` ile erişilir; hard-coded renk yasak (kural tablosu CLAUDE.md'de). `ThemeProvider` → SharedPreferences key `'isDarkMode'`. `BottomSheetThemeData` + `DialogThemeData` her iki ThemeData'ya eklenmiş → sheet/dialog otomatik tema rengi alır. `QuranData.heatColorRelative()` ek `isDark` parametresi: koyu modda okunmamış sayfa görünmez koyu, en çok okunan parlak teal. `DuolingoButton.disabledColor` nullable — null ise `context.colors.surfaceVariant` fallback.