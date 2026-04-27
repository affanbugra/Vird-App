# Vird — Teknik Dersler

> Aynı hatanın tekrarlanmaması için. STATUS.md'deki kısa derslerden daha fazla bağlam gerektirenler buraya gelir.

---

## Flutter

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

### Hot reload asset eklemez
Yeni asset (`pubspec.yaml` + dosya) eklenince hot reload görmez. `flutter clean` + `flutter run` gerekli.

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
