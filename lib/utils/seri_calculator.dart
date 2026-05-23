import 'package:cloud_firestore/cloud_firestore.dart';

/// Seri/freeze tarih anahtarı formatı: 'YYYY-M-D' (tek haneli ay ve gün).
/// frozenDates listesi ve log günü karşılaştırmalarında bu format kullanılır.
/// Tüm seri hesabı ve takvim kodunda bu fonksiyon üzerinden üret.
String seriDateKey(DateTime d) => '${d.year}-${d.month}-${d.day}';

/// Firestore'daki donmuş seri değerini lastLogDate'e göre gerçek duruma çevirir.
/// value  : gösterilecek seri sayısı
/// atRisk : true ise dün okundu, bugün henüz okuma yok
({int value, bool atRisk}) seriDisplayState(int stored, Timestamp? lastLogTs) {
  // lastLogDate hiç yazılmamışsa (migration / veri bozulması) —
  // serinin ne zaman kırıldığını bilemeyiz; stored > 0 ise tehlikede say.
  if (lastLogTs == null) return (value: stored, atRisk: stored > 0);
  if (stored == 0) return (value: 0, atRisk: false);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  final ld = lastLogTs.toDate().toLocal();
  final lastDay = DateTime(ld.year, ld.month, ld.day);
  if (!lastDay.isBefore(today)) return (value: stored, atRisk: false);  // bugün ok
  if (lastDay == yesterday) return (value: stored, atRisk: now.hour >= 18); // son 6 saat: tehlikede
  return (value: 0, atRisk: false);                                      // eski, kırıldı
}

class SeriCalculator {
  /// Belirtilen log silinirse serisinin ne olacağını simüle eder.
  /// Gerçek silme yapmaz — sadece hesaplar.
  static Future<int> simulateWithoutLog(String uid, String logId) async {
    final db = FirebaseFirestore.instance;
    final now = DateTime.now();
    final todayMidnight = DateTime(now.year, now.month, now.day);
    final cutoff = todayMidnight.subtract(const Duration(days: 365));

    final snap = await db
        .collection('users')
        .doc(uid)
        .collection('logs')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(cutoff))
        .get();

    final userSnap = await db.collection('users').doc(uid).get();
    final frozenDates = Set<String>.from(
      ((userSnap.data())?['frozenDates'] as List<dynamic>?) ?? [],
    );

    final logDayKeys = <String>{...frozenDates};
    for (final doc in snap.docs) {
      if (doc.id == logId) continue; // bu logu dışla
      final type = doc.data()['type'] as String?;
      if (type != 'arapca' && type != 'meal') continue;
      final ts = doc.data()['createdAt'] as Timestamp?;
      if (ts != null) {
        final d = ts.toDate().toLocal();
        logDayKeys.add(seriDateKey(d));
      }
    }

    DateTime? mostRecentLogDay;
    for (int i = 0; i <= 365; i++) {
      final d = todayMidnight.subtract(Duration(days: i));
      if (logDayKeys.contains(seriDateKey(d))) {
        mostRecentLogDay = d;
        break;
      }
    }

    if (mostRecentLogDay == null) return 0;

    int seri = 0;
    final anchorOffset = todayMidnight.difference(mostRecentLogDay).inDays;
    for (int i = anchorOffset; i <= 365; i++) {
      final d = todayMidnight.subtract(Duration(days: i));
      if (logDayKeys.contains(seriDateKey(d))) {
        seri++;
      } else {
        break;
      }
    }
    return seri;
  }

  /// Log silindikten sonra çağrılır. Son 365 günlük loglara ve donmuş
  /// günlere bakarak kullanıcının gerçek mevcut serisini hesaplar ve Firestore'u günceller.
  static Future<void> recalculate(String uid) async {
    final db = FirebaseFirestore.instance;
    final now = DateTime.now();
    final todayMidnight = DateTime(now.year, now.month, now.day);
    final cutoff = todayMidnight.subtract(const Duration(days: 365));

    final snap = await db
        .collection('users')
        .doc(uid)
        .collection('logs')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(cutoff))
        .get();

    final userSnap = await db.collection('users').doc(uid).get();
    final frozenDates = Set<String>.from(
      ((userSnap.data())?['frozenDates'] as List<dynamic>?) ?? [],
    );

    // Donmuş günler de ardışık sayım için aktif gün sayılır
    final logDayKeys = <String>{...frozenDates};
    for (final doc in snap.docs) {
      final type = doc.data()['type'] as String?;
      if (type != 'arapca' && type != 'meal') continue;
      final ts = doc.data()['createdAt'] as Timestamp?;
      if (ts != null) {
        final d = ts.toDate().toLocal();
        logDayKeys.add(seriDateKey(d));
      }
    }

    // Önce en son log gününü bul (bugünden geriye)
    DateTime? mostRecentLogDay;
    for (int i = 0; i <= 365; i++) {
      final d = todayMidnight.subtract(Duration(days: i));
      final key = seriDateKey(d);
      if (logDayKeys.contains(key)) {
        mostRecentLogDay = d;
        break;
      }
    }

    if (mostRecentLogDay == null) {
      await db.collection('users').doc(uid).update({
        'seri': 0,
        'lastLogDate': null,
      });
      return;
    }

    // En son log gününden geriye ardışık günleri say
    int seri = 0;
    final anchorOffset = todayMidnight.difference(mostRecentLogDay).inDays;
    for (int i = anchorOffset; i <= 365; i++) {
      final d = todayMidnight.subtract(Duration(days: i));
      final key = seriDateKey(d);
      if (logDayKeys.contains(key)) {
        seri++;
      } else {
        break;
      }
    }

    await db.collection('users').doc(uid).update({
      'seri': seri,
      'lastLogDate': Timestamp.fromDate(mostRecentLogDay),
    });
  }
}
