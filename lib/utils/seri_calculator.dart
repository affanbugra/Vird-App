import 'package:cloud_firestore/cloud_firestore.dart';

class SeriCalculator {
  /// Log silindikten sonra çağrılır. Son 90 günlük loglara bakarak
  /// kullanıcının gerçek mevcut serisini hesaplar ve Firestore'u günceller.
  static Future<void> recalculate(String uid) async {
    final db = FirebaseFirestore.instance;
    final now = DateTime.now();
    final todayMidnight = DateTime(now.year, now.month, now.day);
    final cutoff = todayMidnight.subtract(const Duration(days: 90));

    final snap = await db
        .collection('users')
        .doc(uid)
        .collection('logs')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(cutoff))
        .get();

    final logDayKeys = <String>{};
    for (final doc in snap.docs) {
      final ts = doc.data()['createdAt'] as Timestamp?;
      if (ts != null) {
        final d = ts.toDate().toLocal();
        logDayKeys.add('${d.year}-${d.month}-${d.day}');
      }
    }

    // Bugünden geriye ardışık günleri say
    int seri = 0;
    DateTime? mostRecentLogDay;
    for (int i = 0; i <= 90; i++) {
      final d = todayMidnight.subtract(Duration(days: i));
      final key = '${d.year}-${d.month}-${d.day}';
      if (logDayKeys.contains(key)) {
        mostRecentLogDay ??= d;
        seri++;
      } else {
        break;
      }
    }

    await db.collection('users').doc(uid).update({
      'seri': seri,
      'lastLogDate': mostRecentLogDay != null
          ? Timestamp.fromDate(mostRecentLogDay)
          : null,
    });
  }
}
