# Vird — Teknik Dersler

> Aynı hatanın tekrarlanmaması için. STATUS.md'deki kısa derslerden daha fazla bağlam gerektirenler buraya gelir.

---

## Flutter

### `BoxDecoration` + `borderRadius` + karışık `Border` renkleri → paint crash
`Border(left: renkA, top: renkB, right: renkB, bottom: renkB)` ile birlikte `borderRadius` kullanmak Flutter'da paint aşamasında crash'e yol açar:
```
A borderRadius can only be given on borders with uniform colors
```
Widget listeye eklenir, `flutter analyze` hata vermez, ama **ekranda hiç görünmez** — sessiz render başarısızlığı.

**Çözüm:** `Border.all(color: tekRenk)` kullan. Sol accent şeridini `Border` olarak değil, `ClipRRect` + `IntrinsicHeight` içinde bir `Container` child olarak uygula:
```dart
Container(
  decoration: BoxDecoration(
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: AppColors.borderGrey), // uniform!
  ),
  child: ClipRRect(
    borderRadius: BorderRadius.circular(11),
    child: IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(width: 3, color: _priorityColor(priority)), // sol accent
          // ... diğer içerik
        ],
      ),
    ),
  ),
)
```

### `withOpacity()` kullanma
`withValues(alpha: 0.5)` kullan. `withOpacity` deprecated.

### `Dismissible` + `StreamBuilder` çakışması
Silme animasyonu biter ama Firestore onayı gelmeden önce StreamBuilder eski veriyi tekrar render eder → item "geri döner" gibi görünür.

**Çözüm:** `Set<String> _deletingIds` tut. Dismiss anında id'yi set'e ekle, StreamBuilder'da filtrele. Firestore sildikten sonra set'ten çıkarmana gerek yok — stream zaten güncel listeyi getirir.

```dart
final hatims = snap.data?.docs
    .map((d) => Hatim.fromFirestore(d))
    .where((h) => !_deletingIds.contains(h.id))
    .toList() ?? [];
```

### `FieldValue.serverTimestamp()` → null crash
`batch.update(ref, {'updatedAt': FieldValue.serverTimestamp()})` yazdıktan hemen sonra StreamBuilder tetiklenir. Sunucu henüz timestamp'i yazmadığı için `data['updatedAt']` null gelir. `(data['updatedAt'] as Timestamp).toDate()` → crash.

**Çözüm:** Her Firestore modelinin `fromFirestore`'unda Timestamp cast'ini null-safe yap:
```dart
updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
```

### JPEG'de alpha yok → logo tinting çalışmaz
`ColorFiltered(colorFilter: ColorFilter.mode(color, BlendMode.srcIn))` JPEG'de siyah/boş kutu döner çünkü alpha kanalı yok. Logo aktif/pasif görünümü için `Opacity` widget'ı kullan.

### PNG tinting: `ColorFiltered` yerine `Image.asset(color:)` kullan
Alpha kanallı PNG'de bile `ColorFiltered(BlendMode.srcIn)` offscreen kompozit layer oluşturur — bu layer beyaz arka planla birleşince logo arkasında beyaz görünür.

**Çözüm:** `Image.asset` parametrelerini kullan:
```dart
Image.asset(
  'assets/images/v_logo.png',
  height: 19, width: 19,
  color: Colors.white,
  colorBlendMode: BlendMode.srcIn,
)
```
Bu yöntem renk filtresini doğrudan image pipeline'da uygular, offscreen layer yaratmaz.

### Hot reload asset eklemez
Yeni asset (`pubspec.yaml` + dosya) eklenince hot reload görmez. `flutter clean` + `flutter run` gerekli.

### `SeriCalculator.recalculate()` — anchor-day algoritması
Bugünden geriye sayarak seri hesaplamak, bugün log yoksa seriyi yanlışlıkla sıfırlar (kullanıcı dünkü logunu bugün silerken bile seri kırılır).

**Doğru yaklaşım:** Önce en son log gününü bul (anchor), sonra anchor'dan geriye ardışık günleri say:
```dart
// 1. Anchor bul — bugünden geriye ilk log günü
DateTime? mostRecentLogDay;
for (int i = 0; i <= 90; i++) {
  final d = todayMidnight.subtract(Duration(days: i));
  if (logDayKeys.contains('${d.year}-${d.month}-${d.day}')) {
    mostRecentLogDay = d;
    break;
  }
}
// 2. Anchor'dan geriye ardışık günleri say
final anchorOffset = todayMidnight.difference(mostRecentLogDay!).inDays;
for (int i = anchorOffset; i <= 90; i++) { ... }
```
Bu sayede bugün log olmasa da dünkü log anchor alınır, seri doğru korunur. `seriDisplayState()` buna göre `atRisk:true` döndürür.

### DraggableScrollableSheet ve setState çakışması (Beyaz Ekran / Flash)
`DraggableScrollableSheet` içerisinde karmaşık bir widget ağacı ve `StreamBuilder` varken en üstte `setState` çağrıldığında tüm sheet sıfırdan hesaplanmaya çalışıp beyaz ekran / height jump sorunlarına sebep olur.
**Çözüm:** `ValueNotifier<T>` ve `ValueListenableBuilder` kullanarak sadece güncellenmesi gereken widget'ı sarmala. Böylece bottom sheet layout'u bozulmaz.

---

## Firestore

### Batch ile atomik yazma
Log + hatim ilerlemesi + hasanat/totalPages — üç farklı doküman, hepsi tek `batch.commit()` içinde. Bir parça başarısız olursa diğerleri de yazılmaz. Race condition önlenir.

### Göreli ısı haritası taban problemi
Saf `count / maxCount` oranı: kullanıcının maksimum değeri 1 ise o sayfa en koyu rengi alır — tek bir okuma, haritayı tamamen koyu gösterir.

**Çözüm:** `max(maxCount, 10)` taban kullan:
```dart
final denom = maxCount < 10 ? 10.0 : maxCount.toDouble();
final ratio = count / denom;
```
→ Az okuyan birinin haritası açık kalır; çok okuyan birinin haritası anlamlı şekilde koyulaşır.

### Toplu Veri Silme (Batch Limit)
Firestore batch işlemlerinde en fazla 500 işlem yapılabilir. Çok sayıda logu silerken hata almamak için:
**Çözüm:** Silinecek listeyi `.sublist` ile chunk'lara ayırıp (`(i, i+400)`) loop içerisinde `batch.commit()` atılmalı.

---

## Mimari / State

### `initialHatim` ile açılan bottom sheet'te global state init
`LogEntryBottomSheet` dışarıdan bir hatim ile açıldığında `_globalType` o hatimin tipine göre başlatılmalı. Aksi hâlde kullanıcı "Meal" hatiminden DEVAM ET'e basar, ama Sayfa sekmesine geçince toggle Arapça gösterir.

```dart
if (widget.initialHatim != null) {
  _devamHatim = widget.initialHatim;
  _globalType = widget.initialHatim!.type;  // ← kritik
}
```

### Chip filtresi tip değişimini takip etmeli
Toggle Arapça→Meal değiştiğinde önceden seçili Arapça hatim chip'i temizlenmeli ve chip listesi yeni tipe göre filtrelenmeli:

```dart
onChanged: (t) => setState(() {
  _globalType = t;
  if (_sayfaHatim?.type != t) _sayfaHatim = null;
  if (_cuzHatim?.type != t) _cuzHatim = null;
}),
// chip listesi:
hatims: _hatims.where((h) => h.type == _globalType).toList(),
```

### Hatim İlerleme Hesabı (Set Yaklaşımı)
Kullanıcının `pagesRead` (okuduğu sayfa) verilerini toplamak 604'ü geçmesine ve hatimin yanlışlıkla bitmesine sebep olabilir.
**Çözüm:** Her logdaki `startPage` ve `endPage` aralığını bir `Set<int>` içine at (benzersiz hale gelir). `Set.length` okunan sayfa sayısını, `Set.contains()` kontrolü ise spesifik bir sayfanın okunup okunmadığını kesin olarak verir.

---

## Kuran Veri Sistemi

### Farklı veri sistemleri varsa ana projenin sistemini kullan
Collaborator JSON+Provider sistemi getirirse reddet — proje `QuranData` static const kullanıyor. İki paralel sistem bakım maliyeti ve bug kaynağıdır.

### `QuranData.surahsOnPage()` kullan, hard-code yazma
Sure isimlerini ve sayfa aralıklarını Dart const'tan çek. Aynı veri iki yerde tutulursa biri güncellenince diğeri tutarsız kalır.

---

## Navigator & Async

### Async öncesi Navigator/Messenger yakala
`Navigator.of(context)` ve `ScaffoldMessenger.of(context)` async işlemden (await) önce değişkene atanmalı. Await sonrasında widget unmount olmuş olabilir; `context` stale olur ve hata verir ya da yanlış route'a atlar.

```dart
final navigator = Navigator.of(context);   // await'ten ÖNCE
final messenger = ScaffoldMessenger.of(context);
await someAsyncOperation();
navigator.pop();   // güvenli
```

### Same-frame pop + push yapmaktan kaçın
`Navigator.pop(context)` hemen ardından aynı frame içinde `Navigator.push(...)` çağrısı navigator'ı tutarsız duruma sokar (beyaz ekran, assertion hatası). Push'u bir sonraki frame'e ertele:
```dart
Navigator.pop(context);
WidgetsBinding.instance.addPostFrameCallback((_) => Navigator.push(...));
```

---

## Bildirim Sistemi

### Akıllı "o gün okumadıysa git" bildirimi
`matchDateTimeComponents: DateTimeComponents.time` ile kurulan günlük tekrarlayan bildirim, kullanıcı log kaydedince iptal edilip **yarından** itibaren yeniden kurulur. Böylece o gün okuyan biri bildirim almaz, okumayanlar alır.

```dart
// Log kaydedilince (fire-and-forget):
NotificationService.cancelForToday();

// cancelForToday içinde:
var scheduled = TZDateTime(local, now.year, now.month, now.day + 1, hour, minute);
// Her zaman yarından başlar — bugünkü bildirimi atlar
```

`init()`'te auto-reschedule tutma — uygulama yeniden açılınca "kullanıcı bugün okudu mu?" bilinmez, yanlışlıkla bugünkü bildirimi geri getirir.

---

## Flutter Web Deploy

### Beyaz Ekran: `FormatException: Unexpected token '<', "<!DOCTYPE "`
**Belirti:** Deploy sonrası uygulama tamamen beyaz ekran, konsolda şu hata:
```
FormatException: SyntaxError: Unexpected token '<', "<!DOCTYPE "... is not valid JSON
```

**Kök neden:** Flutter web başlangıçta `assets/FontManifest.json` ve `assets/AssetManifest.bin` dosyalarını HTTP ile çeker. Firebase Hosting'deki `"source": "**", "destination": "/index.html"` rewrite kuralı bu dosyalar yoksa HTML döndürür. Flutter HTML'i JSON olarak parse etmeye çalışır → crash.

**Teşhis:** `build/web/assets/` içinde `FontManifest.json` veya `AssetManifest.bin` yoksa sorun budur.

**Çözüm:** `flutter build web --release` komutu bu dosyaları her zaman üretir. Eksik görünüyorsa build tamamlanmamış veya bozuktur — temiz rebuild yap:
```
flutter build web --release
npx firebase deploy --only hosting
```

### `flutter_service_worker.js` varlığını kontrol et
`flutter build web --release` her zaman `flutter_service_worker.js` üretmeyebilir. `flutter_bootstrap.js`'in son satırı `serviceWorkerSettings` içeriyorsa ama `build/web/flutter_service_worker.js` yoksa uygulama açılmaz (Firebase HTML döndürür, Dart JSON parse eder → crash).

**Kural:** Deploy öncesi `build/web/flutter_service_worker.js` var mı kontrol et. Varsa bootstrap'e dokunma. Yoksa `_flutter.loader.load({})` yap (serviceWorkerSettings'i kaldır).

---

## Firestore Güvenlik Kuralları

### Alan bazlı güncelleme istisnası
Bir kullanıcının belgesini yalnızca belirli bir alanı değiştirmek için başka bir kullanıcının güncellemesine izin vermek gerekiyorsa (ör. admin üye ekleme/çıkarma — `teamId` alanı), `affectedKeys().hasOnly([...])` ile kısıtla:

```javascript
allow update: if isOwner(userId)
              || (isAuth() && request.resource.data.diff(resource.data)
                  .affectedKeys().hasOnly(['teamId']));
```

Bu sayede diğer kullanıcılar yalnızca `teamId` alanını değiştirebilir, diğer alanlara dokunamaz.

### Firebase Console'dan string değer girerken tırnak sorunu
Firebase Console'da bir string field'a değer yazarken tırnakla yazılırsa (`"rical_i_fark_logo"`) tırnaklar değerin parçası olur. `team.logoAsset == 'rical_i_fark_logo'` koşulu başarısız olur.

**Teşhis:** `debugPrint('field: "${value}"')` çıktısında çift tırnak görünüyorsa (`field: ""value""`) değer tırnak içeriyor demektir.

**Çözüm:** Kod tarafında sanitize et — hard-coded string eşitliği yerine:
```dart
final key = (field ?? '').replaceAll('"', '').trim();
if (key.startsWith('rical_i_fark')) { ... }
```

### `where() + orderBy()` farklı alanlarda → composite index zorunluluğu (sessiz hata)
`where('archived', isEqualTo: false).orderBy('createdAt')` gibi iki farklı alanda filtre + sıralama Firestore composite index gerektirir. **Index yoksa query sessizce boş döner — konsola hata yazmaz.**

**Teşhis:** Veri Firestore'da var ama listede görünmüyor. Firebase Console'da Index sekmesini kontrol et.

**Çözüm:** Server-side `where()` + `orderBy()` yerine `.snapshots()` al, filtrelemeyi ve sıralamayı client-side yap:
```dart
stream: FirebaseFirestore.instance.collection('col').snapshots(),
builder: (ctx, snap) {
  final items = (snap.data?.docs ?? [])
      .map((d) => Model.fromDoc(d))
      .where((m) => !m.archived)        // client-side filtre
      .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt)); // client-side sort
```
Bu yaklaşım aynı zamanda `archived` alanı olmayan eski dokümanları da kapsar.

### `whereIn` + range filter → composite index zorunluluğu
`whereIn('type', ['arapca', 'meal'])` ile birlikte `createdAt` range filter kullanmak Firestore'da composite index gerektirir. Index oluşturulmamışsa `[cloud_firestore/failed-precondition]` hatası alınır ve query çalışmaz.

**Çözüm:** `whereIn`'i Firestore'dan kaldır, filtrele:
```dart
final snap = await FirebaseFirestore.instance
    .collection('users').doc(uid).collection('logs')
    .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDay))
    .get();
for (final doc in snap.docs) {
  final type = doc.data()['type'] as String?;
  if (type != 'arapca' && type != 'meal') continue;
  // ...
}
```
Bu yaklaşım hem index gerektirmez hem de ekstra network çağrısı yapmaz — küçük koleksiyonlarda tercih edilir.

### Navigation engelleyen async işlemi try-catch ile izole et
`await` çağrısı `Navigator.pop(context)`'ten önce geliyorsa, exception olduğunda navigation hiç çalışmaz ve ekran (veya sheet) açık kalır.

**Kural:** Navigation'ı engelleyebilecek her opsiyonel async işlemi kendi try-catch bloğuna al:
```dart
// ❌ Yanlış — exception Navigator.pop'u atlatır
final weekData = await _getWeekFilled(uid);
Navigator.pop(context);

// ✅ Doğru — hata sadece animasyonu atlar
dynamic weekData;
try {
  weekData = await _getWeekFilled(uid);
} catch (e) {
  debugPrint('animasyon yüklenemedi: $e');
}
Navigator.pop(context);  // her durumda çalışır
```

### Auth ve Firestore yazısını ayrı try-catch bloklarına ayır
Kayıt akışında auth ve profil Firestore yazısı aynı try-catch içindeyse, Firestore başarısız olduğunda kullanıcı kayıt hatasıyla karşılaşır — oysa auth zaten başarılıdır. Kullanıcı tekrar denerse "e-posta zaten kullanımda" hatası alır.

**Kural:** Auth ve Firestore yazısını her zaman ayrı try-catch bloklarına al:
```dart
// Auth bloğu
try {
  await authProvider.registerWithEmail(email, password);
} catch (e) {
  showSnackBar(_parseAuthError(e));
  return;  // burada dur
}

// Profil yazısı — auth başarılı, hata olsa bile devam et
try {
  await firestore.collection('users').doc(uid).set({...});
} catch (e) {
  debugPrint('Profil yazma hatası: $e');
}
// ProfileSetupScreen'e geç
```

### Silinmiş/arşivlenmiş foreign key'e sahip kayıtlar listelerde kaybolur
Bir item `milestoneId: "abc"` taşıyor ama o milestone silinmiş/arşivlenmişse: aktif milestone listesinde bulunmaz, "unassigned" koşulu (`milestoneId == null || milestoneId.isEmpty`) da sağlanmaz → item **hiçbir gruba girmez, görünmez.**

**Belirti:** Header "12 açık" gösterir ama section açılınca boş gelir. `openCount` tüm items'ı sayar, `_buildRows` ise sadece aktif milestone'ların items'larını ekler.

**Çözüm:** "unassigned" filtresi aktif milestone ID setini de kontrol etmeli:
```dart
final assignedToActive = _milestones.map((m) => m.id).toSet();
final unassigned = items.where((i) =>
  i.milestoneId == null ||
  i.milestoneId!.isEmpty ||
  !assignedToActive.contains(i.milestoneId)  // ← orphaned items de buraya düşer
).toList();
```
**Genel kural:** Foreign key kontrolü sadece null/empty değil, referansın hâlâ geçerli/aktif olup olmadığını da kapsamalı.

### `StreamBuilder` nested kullanımı widget state'ini sıfırlar
`StreamBuilder` içinde başka bir `StreamBuilder` veya `StatefulWidget` varsa, dış stream her güncellendiğinde inner widget yeniden oluşturulur. `Set<String> _expanded` gibi local state sıfırlanır.

**Belirti:** Milestone toggle açılıyor, Firestore güncelleniyor (başka bir item tamamlandı), `_expanded` sıfırlanıyor → section kapanıyor.

**Çözüm:** `StreamBuilder` yerine `initState()` içinde `StreamSubscription` kullan, veriyi yerel `List` değişkenlerine `setState()` ile al:
```dart
StreamSubscription<QuerySnapshot>? _sub;

@override
void initState() {
  super.initState();
  _sub = FirebaseFirestore.instance.collection('col').snapshots().listen((s) {
    setState(() => _items = s.docs.map(Model.fromDoc).toList());
  });
}

@override
void dispose() { _sub?.cancel(); super.dispose(); }
```
Toggle state (`_expanded: Set<String>`) artık parent StatefulWidget'ta yaşar, stream update'lerinden etkilenmez.

### `logs` subcollection okuma kuralı ve liderboard
`users/{uid}/logs` subcollection'ını yalnızca `isOwner()` ile kısıtlarsan liderboard için başka kullanıcıların loglarını okumak `Permission Denied` hatası verir ve kullanıcı 0 puan görünür. Liderboard gibi cross-user okuma gerektiren senaryolarda `isAuth()` yeterli:
```javascript
match /logs/{logId} {
  allow read: if isAuth();
  allow write: if isOwner(userId);
}
```
