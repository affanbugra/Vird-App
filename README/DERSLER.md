# Vird — Tuzaklar & Dersler

> Hata çıkınca veya kritik bir adım öncesinde bu dosyayı oku.
> Yeni bir hata düzeltilince buraya ekle.

---

### Flutter — Render

**`BoxDecoration` + `borderRadius` + farklı kenarlara farklı renkler → sessiz render crash**
`Border(left: renkA, top: renkB, ...)` + `borderRadius` → `A borderRadius can only be given on borders with uniform colors`. Widget listede görünür, `flutter analyze` hata vermez, ama ekranda hiç gösterilmez.
```dart
// ✅ Çözüm: uniform border + accent'i ayrı Container child olarak
Container(
  decoration: BoxDecoration(
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: AppColors.borderGrey),
  ),
  child: ClipRRect(
    borderRadius: BorderRadius.circular(11),
    child: IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(width: 3, color: accentColor), // sol accent
          // ... içerik
        ],
      ),
    ),
  ),
)
```

**`withOpacity()` deprecated → `withValues(alpha: 0.5)` kullan**

**Logo tinting:**
- JPEG'de alpha kanalı yok → `ColorFiltered(BlendMode.srcIn)` siyah/boş kutu. `Opacity` widget kullan.
- PNG'de `ColorFiltered` offscreen layer yaratır → beyaz arka plan görünür. Bunun yerine:
```dart
Image.asset('assets/v_logo.png', color: Colors.white, colorBlendMode: BlendMode.srcIn)
```

**Yeni asset → hot reload görmez.** `flutter clean` + `flutter run` gerekli.

---

### Flutter — State & Widget

**`NestedScrollView.body` olarak `Column` → scroll controller crash ("Promise hatası")**
`TabBar + Expanded(TabBarView)` kombinasyonunu `Column` içine koyup bunu `NestedScrollView.body`'ye vermek scroll controller çakışmasına yol açar. Flutter web'de "Promise hatası: Error" olarak görünür, `flutter analyze` hata vermez.
```dart
// ❌ YANLIŞ — Column body, crash
body: Column(children: [
  TabBar(...),
  Expanded(child: TabBarView(...)),
]),

// ✅ DOĞRU — TabBar header'da, TabBarView direkt body
headerSliverBuilder: (ctx, _) => [
  ...,
  SliverPersistentHeader(pinned: true, delegate: _TabBarDelegate(TabBar(...))),
],
body: TabBarView(...),
```
`_TabBarDelegate extends SliverPersistentHeaderDelegate` → `minExtent` / `maxExtent` = `tabBar.preferredSize.height`.

**`TabBarView` içindeki widget, tab değişiminde dispose → `setState() called after dispose()`**
`TabBarView` görünmeyen tab'ın widget'ını dispose eder. O widget'ın async işlemi (Firestore fetch, dialog await) bitince `setState` çağırır → crash.
İki katmanlı çözüm:
```dart
// 1. AutomaticKeepAliveClientMixin — widget tab değişiminde dispose olmaz
class _MyState extends State<MyWidget> with AutomaticKeepAliveClientMixin {
  @override bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // zorunlu!
    ...
  }
}

// 2. Async setState öncesi mounted kontrolü (güvenlik katmanı)
Future<void> _fetchData() async {
  ...
  await someFirestoreCall();
  if (!mounted) return; // ← zorunlu
  setState(() => _isLoading = false);
}
```



**`Dismissible` + `StreamBuilder` çakışması**
Silme animasyonu biter ama Firestore onayı gelmeden stream eski veriyi tekrar render eder → item "geri döner".
```dart
final Set<String> _deletingIds = {};
// Dismiss anında: _deletingIds.add(id)
// StreamBuilder'da: .where((item) => !_deletingIds.contains(item.id))
```

**`StreamBuilder` nested → local state sıfırlanır**
Dış stream güncellenince inner `StatefulWidget` yeniden oluşturulur, `_expanded: Set<String>` gibi state sıfırlanır.
```dart
// ✅ Çözüm: StreamSubscription + setState pattern
StreamSubscription<QuerySnapshot>? _sub;
void initState() {
  _sub = firestore.collection('col').snapshots().listen((s) {
    setState(() => _items = s.docs.map(Model.fromDoc).toList());
  });
}
void dispose() { _sub?.cancel(); super.dispose(); }
```

**`DraggableScrollableSheet` + setState → beyaz ekran/flash**
Karmaşık widget ağacında `setState` tüm sheet'i sıfırlatır. `ValueNotifier` + `ValueListenableBuilder` ile sadece güncellenmesi gereken kısmı sarmala.

**Switch case içi local variable:** Switch dışında kullanılacaksa, switch öncesinde nullable değişken tanımla, case içinde set et.

---

### Flutter — Navigation & Async

**Same-frame pop + push → crash**
`Navigator.pop()` hemen ardından `Navigator.push()` aynı frame'de → beyaz ekran, assertion hatası.
```dart
Navigator.pop(context);
WidgetsBinding.instance.addPostFrameCallback((_) => Navigator.push(...));
```

**Async öncesi Navigator/Messenger yakala**
```dart
final navigator = Navigator.of(context);   // await'ten ÖNCE
final messenger = ScaffoldMessenger.of(context);
await someAsyncOperation();
navigator.pop(); // güvenli
```

**Navigation engelleyen async → try-catch ile izole et**
```dart
// ❌ exception → Navigator.pop hiç çalışmaz
final data = await optionalAsyncOp();
Navigator.pop(context);

// ✅ hata animasyonu atlar, navigation her durumda çalışır
dynamic data;
try { data = await optionalAsyncOp(); } catch (e) { debugPrint(e.toString()); }
Navigator.pop(context);
```

**Auth + Firestore → ayrı try-catch**
Auth başarılı + Firestore hatalı → aynı try-catch'te olursa kullanıcı auth hatasıyla karşılaşır, tekrar denerse "e-posta zaten kullanımda" alır.
```dart
try { await auth.register(email, pass); } catch (e) { showError(e); return; }
try { await firestore.doc(uid).set({...}); } catch (e) { debugPrint(e.toString()); }
// devam et
```

**ModalBottomSheet'ten dialog göster**
Sheet kapandıktan sonra dialog için: `showModalBottomSheet<bool>` await et, `context.mounted` kontrol et, sonra `showDialog`.

---

### Firestore

**`context.colors.*` + `const` widget çakışması**
`context.colors.*` runtime değerdir (`Theme.of(context)` çağrısı), `const` constructor içinde kullanılamaz. Derleyici "Not a constant expression" verir.
```dart
// ❌ Hata: const BoxDecoration(color: context.colors.surface)
const Container(
  decoration: BoxDecoration(color: context.colors.surface),
)
// ✅ Çözüm: widget'tan const'u kaldır, içteki sabit alt widget'lar const kalabilir
Container(
  decoration: BoxDecoration(color: context.colors.surface),
  child: const SizedBox(width: 40),  // bu const kalabilir
)
```
Kural: `context.colors.*` kullanan her widget `const` olamaz. Sadece `AppColors.teal` gibi sabit semantic renkler `const` içinde kullanılabilir.

---

### Firestore

**Rules deploy edilmeden test → optimistik yazma yanıltır**
Firestore rules yeni bir koleksiyona izin vermeden önce `.set()` çağrısı lokalde başarılı görünür (SDK optimistik cache yazması). UI anında güncellenir, kullanıcı "işlem tamam" sanır. Sunucu birkaç saniye içinde `permission-denied` döndürünce SDK cache'i geri alır (rollback) → UI eski haline döner. Hata mesajı da gecikmeli gelir.
```
Semptom: pending state göründü → hata → form tekrar çıktı
Teşhis:  firestore.rules'ta koleksiyon kuralı eksik
Çözüm:   firebase deploy --only firestore:rules
Önlem:   snap.hasError kontrolü + permission-denied'ı ayrıca yakala
```

**Composite index tuzağı — sessiz boş sonuç**
`where('field1').orderBy('field2')` farklı alanlarda → index gerekir. Index yoksa **query sessizce boş döner, hata yazmaz.** Teşhis: veri var ama liste boş.
```dart
// ✅ Çözüm: orderBy kaldır, client-side sort
stream.map((snap) => snap.docs
  .map(Model.fromDoc)
  .where((m) => !m.archived)
  .toList()
  ..sort((a, b) => b.createdAt.compareTo(a.createdAt)));
```

**`whereIn` + range filter → composite index**
`whereIn('type', [...])` + `createdAt` range → `[cloud_firestore/failed-precondition]`. `whereIn`'i kaldır, client-side filtrele.

**`FieldValue.serverTimestamp()` → fromFirestore'da null**
Batch yazılınca StreamBuilder hemen tetiklenir, sunucu henüz yazmamıştır. Her Timestamp field'ı null-safe cast et:
```dart
updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
```

**Toplu silme — batch 500 limit**
```dart
for (int i = 0; i < docs.length; i += 400) {
  final batch = firestore.batch();
  for (final doc in docs.sublist(i, min(i + 400, docs.length))) {
    batch.delete(doc.reference);
  }
  await batch.commit();
}
```

**Orphaned foreign key → kayıt kaybolur**
Item'ın `milestoneId`'si silinmiş milestone'a işaret ediyorsa: aktif gruba girmez, unassigned koşulunu da sağlamaz → hiçbir yerde görünmez. `openCount` sayar ama listede yoktur.
```dart
final assignedToActive = milestones.map((m) => m.id).toSet();
final unassigned = items.where((i) =>
  i.milestoneId == null ||
  i.milestoneId!.isEmpty ||
  !assignedToActive.contains(i.milestoneId) // orphaned da buraya düşer
).toList();
```

**Firebase Console string tırnak sorunu**
Console'dan `"değer"` yazılırsa tırnaklar değerin parçası olur. Kod tarafında sanitize et:
```dart
final key = (field ?? '').replaceAll('"', '').trim();
```

**Göreli ısı haritası taban**
`count / maxCount` — max=1 iken tek okuma en koyu rengi alır. `max(maxCount, 10)` taban kullan:
```dart
final denom = maxCount < 10 ? 10.0 : maxCount.toDouble();
```

---

### Liderboard & Denormalize Veri

**Denormalize field + arşiv birlikte varsa geçiş haftası verileri bozulur**
`weeklyHasanat` field'ı sonradan eklendi. Öncesinde log atan kullanıcıların `weeklyStartDate`'i yoktu (`null`). Yeni log girilince `else` branch çalıştı → `weeklyHasanat` o haftanın toplamı değil sadece yeni logun puanına SET edildi. Liderboard fast path bu değeri doğrudan okuyunca geçmiş loglar yok sayıldı.

Ayrıca arşiv: `if (docSnap.exists) continue` koruması yanlış skorla oluşturulmuş arşivi sonraki açılışlarda atladı → kalıcı hatalı arşiv.

```
Semptom:  Liderboard'da o haftaki eski loglar görünmüyor, sadece son log puanı geliyor.
Root cause: weeklyHasanat ilk set edilişinde mevcut loglar sorgulanmadı.
Düzeltme: (1) ilk set edilişte bu haftanın loglarını sorgula ve topla;
           (2) liderboard mevcut hafta için her zaman log sorgusunu kullan;
           (3) arşiv oluştururken fast path değil log sorgusu kullan;
           (4) geçen hafta arşivi her açılışta silinip log sorgusundan yeniden oluşturulsun.
```

**Denormalize field eklerken kontrol listesi:**
- Yeni field'ı olmayan mevcut kullanıcılar için migration branch yaz (null → log sorgusundan hesapla)
- Arşiv/cache'ler varsa bunlar da log sorgusuyla oluşturulsun; fast path'e güvenme
- Önce liderboard görüntüleme doğruluğunu log sorgusundan onayla, sonra fast path ekle

---

### Mimari

**`initialHatim` ile açılan bottom sheet**
`_globalType` o hatimin tipine göre init edilmeli; aksi hâlde sekme değişince tip Arapça'ya sıfırlanır:
```dart
if (widget.initialHatim != null) {
  _devamHatim = widget.initialHatim;
  _globalType = widget.initialHatim!.type; // kritik
}
```

**Chip filtresi tip değişimini takip etmeli**
Toggle Arapça→Meal değişince önceki tip'e ait hatim chip'leri temizlenmeli:
```dart
onChanged: (t) => setState(() {
  _globalType = t;
  if (_sayfaHatim?.type != t) _sayfaHatim = null;
});
```

**Hatim ilerleme: `Set<int>` kullan**
`pagesRead` toplamı 604'ü geçebilir ve hatimi yanlış bitirir. `startPage`–`endPage` aralığını Set'e at — benzersiz sayfa adedi kesin olarak elde edilir.

---

### Ekip Sistemi

**Developer bypass → cinsiyet kurallarını kırar**
Ekip katılım/kurma limitlerinde `isDeveloper` bypass eklenince aynı pattern cinsiyet kontrolüne de yayılma eğilimi gösterir. Cinsiyet kuralı ayrı bir politikadır; limit bypass ile birlikte uygulanmamalı.
```
Semptom: Developer kullanıcı kısıtlı cinsiyetli ekibi görebiliyor / ekipte açılıyor.
Root cause: isDeveloper kontrolü cinsiyet check'ini de kısa devre etmiş.
Çözüm: Limit ve cinsiyet kontrollerini ayrı if blokları yaz; isDev bypass yalnızca limit bloğuna gir.
Önlem: CLAUDE.md → "Ekip Sistemi" bölümünü oku — developer ayrıcalıkları net tanımlanmış.
```

**`_CrossGenderNamesToggle` bottom sheet içinde görsel güncelleme yapmaz**
Bottom sheet, parent `StreamBuilder`'ın yeni snapshot'ını bekler. Toggle güncellenmesi gecikir veya hiç olmaz.
```dart
// ✅ Çözüm: Local optimistic state
late bool _localValue;
void initState() { super.initState(); _localValue = widget.value; }
// Toggle: önce _localValue'yu güncelle → Firestore yaz → hata varsa revert
```

---

### Web Deploy

**Beyaz ekran: `FormatException: Unexpected token '<'`**
Firebase Hosting rewrite kuralı `FontManifest.json` veya `AssetManifest.bin` bulamazsa HTML döndürür. Flutter HTML'i JSON olarak parse eder → crash. Çözüm: `flutter build web --release` (temiz build) + deploy.

**`flutter_service_worker.js` yoksa uygulama açılmaz**
Deploy öncesi `build/web/flutter_service_worker.js` varlığını kontrol et. Yoksa `flutter_bootstrap.js`'ten `serviceWorkerSettings`'i kaldır.
