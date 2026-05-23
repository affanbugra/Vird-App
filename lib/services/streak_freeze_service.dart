import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/seri_calculator.dart';

class StreakFreezeService {
  static const int maxFreezesNormal = 2;
  static const int maxFreezesPro = 5;

  /// Milestone günleri ve her birinde kazanılan hak sayısı
  static const Map<int, int> milestoneFreezes = {
    7: 1,
    14: 1,
    21: 1,
    40: 2,
  };

  static FirebaseFirestore get _db => FirebaseFirestore.instance;

  /// Kullanıcıya freeze hakkı ekle (milestone veya DevPanel üzerinden).
  static Future<void> grantFreeze(String uid, int count) async {
    final userRef = _db.collection('users').doc(uid);
    final snap = await userRef.get();
    final data = snap.data() ?? {};
    final isPro = (data['isPro'] as bool?) ?? false;
    final maxFreezes = isPro ? maxFreezesPro : maxFreezesNormal;
    final current = (data['streakFreezes'] as int?) ?? 0;
    final newCount = (current + count).clamp(0, maxFreezes);
    await userRef.update({'streakFreezes': newCount});
  }

  /// Belirli bir güne freeze uygula ('YYYY-M-D' formatında dateKey).
  /// Başarılıysa true döner; hak yoksa veya gün zaten donmuşsa false.
  static Future<bool> applyFreeze(String uid, String dateKey) async {
    final userRef = _db.collection('users').doc(uid);
    final snap = await userRef.get();
    final data = snap.data() ?? {};
    final freezes = (data['streakFreezes'] as int?) ?? 0;
    if (freezes <= 0) return false;

    final frozenDates = List<String>.from(
      (data['frozenDates'] as List<dynamic>?) ?? [],
    );
    if (frozenDates.contains(dateKey)) return false;

    frozenDates.add(dateKey);
    await userRef.update({
      'streakFreezes': freezes - 1,
      'frozenDates': frozenDates,
    });

    // Seriyi yeniden hesapla — donmuş gün artık aktif gün olarak sayılır
    await SeriCalculator.recalculate(uid);
    return true;
  }

  /// Uygulama açılışında veya log kaydı öncesinde çağrılır.
  /// lastLogDate ile bugün arasındaki eksik günleri tespit eder;
  /// tümünü karşılayacak kadar hak varsa otomatik dondurur ve bildirim yazar.
  /// Döndürür: dondurulan gün sayısı (0 = işlem yapılmadı).
  static Future<int> autoApplyFreezes(String uid) async {
    final userRef = _db.collection('users').doc(uid);
    final snap = await userRef.get();
    final data = snap.data() ?? {};

    final storedSeri = (data['seri'] as int?) ?? 0;
    if (storedSeri == 0) return 0;

    final lastLogTs = data['lastLogDate'] as Timestamp?;
    if (lastLogTs == null) return 0;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final lastLogRaw = lastLogTs.toDate().toLocal();
    final lastDay =
        DateTime(lastLogRaw.year, lastLogRaw.month, lastLogRaw.day);

    if (!lastDay.isBefore(today)) return 0; // bugün zaten aktif

    final frozenDates = Set<String>.from(
      (data['frozenDates'] as List<dynamic>?) ?? [],
    );

    // lastLogDate+1 ile dün arasındaki korunmamış günler
    final gapDays = <String>[];
    var cursor = lastDay.add(const Duration(days: 1));
    while (!cursor.isAfter(yesterday)) {
      final key = seriDateKey(cursor);
      if (!frozenDates.contains(key)) gapDays.add(key);
      cursor = cursor.add(const Duration(days: 1));
    }

    if (gapDays.isEmpty) return 0;

    final streakFreezes = (data['streakFreezes'] as int?) ?? 0;

    // Dondurulacak günleri belirle.
    // Hak yetersizse en yeni günleri dondur — yesterday'e yakın günler seri
    // zincirinin devam etmesini sağlar; eski günler boşluk olarak kalır.
    final List<String> daysToFreeze;
    if (streakFreezes >= gapDays.length) {
      daysToFreeze = gapDays;
    } else if (streakFreezes > 0) {
      daysToFreeze = gapDays.sublist(gapDays.length - streakFreezes);
    } else {
      // Hak yok — seri kırıldı. Firestore'daki ham değeri düzelt (liderboard tutarlılığı).
      await SeriCalculator.recalculate(uid);
      return 0;
    }

    // Freeze uygula
    final newFrozen = [...frozenDates, ...daysToFreeze];
    await userRef.update({
      'streakFreezes': streakFreezes - daysToFreeze.length,
      'frozenDates': newFrozen,
    });

    await SeriCalculator.recalculate(uid);

    // Bildirim yaz
    final frozenCount = daysToFreeze.length;
    final skippedCount = gapDays.length - frozenCount;
    final String title;
    final String body;

    if (skippedCount == 0) {
      title = frozenCount == 1
          ? 'Serin otomatik korundu 🛡️'
          : '$frozenCount günlük serin otomatik korundu 🛡️';
      body = frozenCount == 1
          ? '${_dayLabel(daysToFreeze.first)} için 1 dondurma hakkın kullanıldı. Serin kaldığı yerden devam ediyor.'
          : '$frozenCount eksik gün için $frozenCount dondurma hakkın kullanıldı. Serin kaldığı yerden devam ediyor.';
    } else {
      title = 'Serin kısmen korundu 🛡️';
      body = '$frozenCount gün donduruldu, $skippedCount gün korunamadı. Serin yeniden başlıyor.';
    }

    await _db
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .add({
      'type': 'streak_freeze',
      'title': title,
      'body': body,
      'isRead': false,
      'frozenCount': frozenCount,
      'skippedCount': skippedCount,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return frozenCount;
  }

  static String _dayLabel(String dateKey) {
    final parts = dateKey.split('-');
    if (parts.length != 3) return dateKey;
    final month = int.tryParse(parts[1]) ?? 0;
    const monthNames = [
      '', 'Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz',
      'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara'
    ];
    return '${parts[2]} ${month < monthNames.length ? monthNames[month] : ''}';
  }

  /// Yeni seri değerine göre claim edilmemiş milestone'ları kontrol et ve claim et.
  /// Döndürür: kazanılan toplam hak + hangi milestone'lar claim edildi.
  /// Transaction kullanılır — aynı hesap iki cihazda eş zamanlı log atsa da double-claim olmaz.
  static Future<({int totalGranted, List<int> claimed})> claimMilestones({
    required String uid,
    required int newSeri,
  }) async {
    final userRef = _db.collection('users').doc(uid);

    return _db.runTransaction<({int totalGranted, List<int> claimed})>((tx) async {
      final snap = await tx.get(userRef);
      final data = snap.data() ?? {};

      final claimedList = List<int>.from(
        (data['claimedStreakMilestones'] as List<dynamic>?) ?? [],
      );
      final isPro = (data['isPro'] as bool?) ?? false;
      final maxFreezes = isPro ? maxFreezesPro : maxFreezesNormal;
      final currentFreezes = (data['streakFreezes'] as int?) ?? 0;

      final newlyClaimed = <int>[];
      for (final m in milestoneFreezes.keys) {
        if (newSeri >= m && !claimedList.contains(m)) {
          newlyClaimed.add(m);
        }
      }

      if (newlyClaimed.isEmpty) return (totalGranted: 0, claimed: <int>[]);

      newlyClaimed.sort();
      final totalGrant = newlyClaimed.fold(0, (s, m) => s + (milestoneFreezes[m] ?? 0));
      final newFreezeCount = (currentFreezes + totalGrant).clamp(0, maxFreezes);

      tx.update(userRef, {
        'streakFreezes': newFreezeCount,
        'claimedStreakMilestones': [...claimedList, ...newlyClaimed],
      });

      return (totalGranted: totalGrant, claimed: newlyClaimed);
    });
  }
}
