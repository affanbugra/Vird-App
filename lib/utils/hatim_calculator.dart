import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/reading_log_model.dart';

class HatimCalculator {
  /// Bir hatime ait tüm logları okur ve hatimin `currentPage`, `lastReadPage`,
  /// `isCompleted` durumunu baştan hesaplar.
  /// - `currentPage`: Okunan benzersiz sayfa sayısı (Set boyutu)
  /// - `lastReadPage`: En yüksek okunan sayfa numarası (Devam sekmesi için)
  /// - `isCompleted`: 1-604 arası TÜM sayfalar okunmuşsa true
  static Future<void> recalculate(String uid, String hatimId) async {
    final db = FirebaseFirestore.instance;
    
    // 1. Hatime ait tüm logları çek
    final logsSnap = await db
        .collection('users')
        .doc(uid)
        .collection('logs')
        .where('hatimId', isEqualTo: hatimId)
        .get();

    // 2. Okunan sayfaları bir Set'te topla ve en yüksek sayfayı bul
    final Set<int> readPages = {};
    int lastReadPage = 0;

    for (var doc in logsSnap.docs) {
      final log = ReadingLog.fromFirestore(doc);
      final start = log.startPage;
      final end = log.endPage;
      if (start != null && end != null) {
        for (int p = start; p <= end && p <= 604; p++) {
          if (p >= 1) readPages.add(p);
        }
        lastReadPage = math.max(lastReadPage, end.clamp(0, 604));
      }
    }

    // 3. Toplam okunan benzersiz sayfa sayısı
    final int calculatedPage = readPages.length.clamp(0, 604);

    // 4. Hatim tamamlanması için 1-604 arası tüm sayfalar okunmuş olmalı
    final bool isCompleted = readPages.length >= 604 &&
        List.generate(604, (i) => i + 1).every((p) => readPages.contains(p));

    // 5. Transaction ile Hatim ve User dokümanlarını güncelle
    final hatimRef = db.collection('users').doc(uid).collection('hatims').doc(hatimId);
    final userRef = db.collection('users').doc(uid);

    await db.runTransaction((tx) async {
      final hatimDoc = await tx.get(hatimRef);
      if (!hatimDoc.exists) return;
      
      final hatimData = hatimDoc.data()!;
      final bool wasCompleted = hatimData['isCompleted'] == true;

      final updateData = <String, dynamic>{
        'currentPage': calculatedPage,
        'lastReadPage': lastReadPage,
        'isCompleted': isCompleted,
      };

      if (isCompleted && !wasCompleted) {
        updateData['completedAt'] = FieldValue.serverTimestamp();
        tx.update(userRef, {'hatimCount': FieldValue.increment(1)});
      } else if (!isCompleted && wasCompleted) {
        updateData['completedAt'] = null;
        tx.update(userRef, {'hatimCount': FieldValue.increment(-1)});
      }

      tx.update(hatimRef, updateData);
    });
  }
}
