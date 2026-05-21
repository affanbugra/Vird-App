import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:home_widget/home_widget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Ana ekran widget'ına veri gönderen servis.
///
/// Android: SharedPreferences → VirdWidgetProvider (RemoteViews)
/// iOS:     UserDefaults (App Group) → WidgetKit (SwiftUI)
class HomeWidgetService {
  // iOS App Group — Xcode'da Runner ve VirdWidget targetlarında aynı olmalı
  static const _appGroupId = 'group.com.example.virdApp';

  // Android widget provider sınıf adı
  static const _androidWidgetName = 'VirdWidgetProvider';

  // iOS widget adı
  static const _iOSWidgetName = 'VirdWidget';

  /// Uygulama başlarken çağrılır.
  static Future<void> init() async {
    if (kIsWeb) return;
    try {
      await HomeWidget.setAppGroupId(_appGroupId);

      // Widget'a tıklanınca deep-link ile gelen URI'yi dinle
      HomeWidget.widgetClicked.listen((_) {
        // Uygulama zaten açılır — ekstra navigasyon gerekirse burada yapılır
      });
    } catch (e) {
      debugPrintHomeWidget('HomeWidget init hatası: $e');
    }
  }

  /// Firestore'dan güncel verileri çekip widget'a yazar.
  /// [main.dart] ve [log_entry_bottom_sheet.dart] tarafından çağrılır.
  static Future<void> updateWidgetData() async {
    if (kIsWeb) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // ── Kullanıcı dökümanından seri + hasanat ────────────────────────
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = userDoc.data() ?? {};
      final seri = data['seri'] ?? 0;
      final hasanat = data['hasanat'] ?? 0;

      // ── Bugün log var mı? ───────────────────────────────────────────
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final todayEnd = todayStart.add(const Duration(days: 1));
      final todayLogs = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('logs')
          .where('createdAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
          .where('createdAt', isLessThan: Timestamp.fromDate(todayEnd))
          .limit(1)
          .get();
      final todayLogged = todayLogs.docs.isNotEmpty;

      // ── Aktif hatim (en son güncellenen) ────────────────────────────
      // Not: isCompleted alanı Firestore'da set edilmemiş olabilir,
      // bu yüzden tüm hatimleri çekip Dart tarafında filtreliyoruz.
      final hatimsSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('hatims')
          .orderBy('updatedAt', descending: true)
          .limit(5)
          .get();

      String hatimName = '';
      int hatimCurrent = 0;
      int hatimTotal = 604;

      // İlk aktif (tamamlanmamış) hatimi bul
      for (final doc in hatimsSnap.docs) {
        final hDoc = doc.data();
        final completed = (hDoc['isCompleted'] as bool?) ?? false;
        if (!completed) {
          final type = hDoc['type'] == 'arapca' ? 'Arapça Hatim' : 'Meal Hatimi';
          hatimName = (hDoc['name'] as String?)?.isNotEmpty == true
              ? hDoc['name'] as String
              : type;
          hatimCurrent = hDoc['currentPage'] ?? 0;
          hatimTotal = hDoc['totalPages'] ?? 604;
          break;
        }
      }

      // ── Widget'a yaz ────────────────────────────────────────────────
      await Future.wait([
        HomeWidget.saveWidgetData<int>('seri', seri),
        HomeWidget.saveWidgetData<int>('hasanat', hasanat),
        HomeWidget.saveWidgetData<String>('hatim_name', hatimName),
        HomeWidget.saveWidgetData<int>('hatim_current', hatimCurrent),
        HomeWidget.saveWidgetData<int>('hatim_total', hatimTotal),
        HomeWidget.saveWidgetData<bool>('today_logged', todayLogged),
      ]);

      // Her iki platform widget'ını da güncelle
      await HomeWidget.updateWidget(
        name: _androidWidgetName,
        iOSName: _iOSWidgetName,
      );
    } catch (e) {
      debugPrintHomeWidget('Widget veri güncelleme hatası: $e');
    }
  }

  /// Log kaydedildikten sonra widget'ı anında günceller.
  static Future<void> syncOnLogSave() => updateWidgetData();
}

void debugPrintHomeWidget(String message) {
  // Release build'de print göz ardı edilir
  assert(() {
    // ignore: avoid_print
    print('[HomeWidget] $message');
    return true;
  }());
}
