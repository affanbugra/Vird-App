# Vird — Proje Durumu

---

## Dosya Haritası

Adından anlaşılmayan veya kritik detay içeren dosyalar:

| Dosya | Not |
|---|---|
| `lib/screens/ekip_profil_screen.dart` | Ekip profili + haftalık liderboard (client-side `periodStart`) |
| `lib/screens/profil_screen.dart` | Kendi profili — Kuran haritası + `_HafizSheet` (doğrulama başvurusu) bu ekranda |
| `lib/screens/kullanici_profil_screen.dart` | Başka kullanıcı profili — read-only |
| `lib/screens/dev_panel_screen.dart` | DevPanel — bug/plan/fikir/feedback + Hafız başvuruları yönetimi (sadece developer görür) |
| `lib/screens/vird_screen.dart` | Vird sekmesi — yol haritası + öneri formu |
| `lib/widgets/log_entry_bottom_sheet.dart` | Log girişi — 4 tab, kilitleme modu, seri animasyon tetikleyici |
| `lib/widgets/duolingo_button.dart` | Primary buton bileşeni (3D depth) — adı yanıltıcı, aslında AppButton |
| `lib/utils/seri_calculator.dart` | Seri hesabı — anchor-day algoritması, `seriDisplayState()`. `atRisk` yalnızca saat 18:00+ aktif |
| `lib/utils/hatim_calculator.dart` | Hatim tamamlanma — `Set<int>` yaklaşımı, `Future<bool>` döndürür |
| `lib/data/quran_cuz.dart` | Kuran veri sistemi — tüm modüllerde kullanılır, dokunmadan önce oku |
| `lib/data/tilavet_secde.dart` | 14 tilavet secdesi sayfa verisi |
| `lib/providers/user_provider.dart` | `isDeveloper`, `developerTeamIds`, `isHafiz` — global developer/hafız state |

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
username:         string
avatarSeed:       string? (20 önceden belirlenmiş DiceBear seed — Storage maliyeti yok)
name:             string
city:             string?
university:       string?
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
name:        string
description: string
penaltyNote: string
adminUid:    string
memberCount: int
isPrivate:   bool (true → listede görünmez)
inviteCode:  string (6 haneli, örn. "XK7P2Q")
createdAt:   Timestamp
```

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
- **Hafız doğrulama gizlilik:** Onay verilince `hafiz_requests/{uid}.driveLink` alanı `FieldValue.delete()` ile silinir. Belge verisi sistemde tutulmaz (KVKK uyumu).
- **seriDisplayState `atRisk`:** Yalnızca günün son 6 saatinde (`now.hour >= 18`) true döner. Sabah erken saatlerde "tehlikede" göstermek kullanıcı deneyimini bozduğu için bu eşik seçildi.