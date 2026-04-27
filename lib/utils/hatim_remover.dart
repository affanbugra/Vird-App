import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/hatim_model.dart';
import '../models/reading_log_model.dart';

class HatimRemover {
  /// Bir hatimi ve ona ait tüm okuma kayıtlarını (logları) temizler.
  /// Kullanıcının hasanat, toplam okunan sayfa ve tamamlanan hatim sayısı
  /// gibi istatistiklerini de silinen loglara göre geriye doğru günceller.
  static Future<void> deleteHatim(String uid, Hatim hatim) async {
    final db = FirebaseFirestore.instance;

    // 1. Hatime ait TÜM logları çek
    final logsSnap = await db
        .collection('users')
        .doc(uid)
        .collection('logs')
        .where('hatimId', isEqualTo: hatim.id)
        .get();

    int totalPagesFromLogs = 0;
    for (var doc in logsSnap.docs) {
      totalPagesFromLogs += (doc.data()['pagesRead'] as int?) ?? 0;
    }

    // 2. Firestore batch limiti 500 — birden fazla batch gerekebilir
    // Önce logları sil (birden fazla batch ile)
    final logDocs = logsSnap.docs;
    for (int i = 0; i < logDocs.length; i += 400) {
      final chunk = logDocs.sublist(i, (i + 400).clamp(0, logDocs.length));
      final batch = db.batch();
      for (var doc in chunk) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }

    // 3. Hatim dokümanını sil + kullanıcı istatistiklerini güncelle (tek batch)
    final finalBatch = db.batch();
    
    final hatimRef = db.collection('users').doc(uid).collection('hatims').doc(hatim.id);
    finalBatch.delete(hatimRef);

    final userRef = db.collection('users').doc(uid);
    final userUpdates = <String, dynamic>{};
    
    if (totalPagesFromLogs > 0) {
      userUpdates['hasanat'] = FieldValue.increment(-(totalPagesFromLogs * 10));
      userUpdates['totalPages'] = FieldValue.increment(-totalPagesFromLogs);
    }
    
    if (hatim.isCompleted) {
      userUpdates['hatimCount'] = FieldValue.increment(-1);
    }

    if (userUpdates.isNotEmpty) {
      finalBatch.update(userRef, userUpdates);
    }

    await finalBatch.commit();
  }
}
