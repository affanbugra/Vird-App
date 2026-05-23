import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import '../app_colors.dart';
import '../models/hatim_model.dart';
import 'duolingo_button.dart';
import '../models/reading_log_model.dart';
import '../data/quran_cuz.dart';
import '../utils/text_utils.dart';
import '../data/tilavet_secde.dart';
import '../utils/hatim_calculator.dart';
import '../utils/seri_calculator.dart';
import 'log_history_sheet.dart';
import '../screens/streak_animation_screen.dart';
import '../screens/streak_freeze_reward_screen.dart';
import '../services/streak_freeze_service.dart';

class LogEntryBottomSheet extends StatefulWidget {
  final Hatim? initialHatim;

  const LogEntryBottomSheet({super.key, this.initialHatim});

  static Future<void> show(BuildContext context, {Hatim? initialHatim}) async {
    final justCompleted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: LogEntryBottomSheet(initialHatim: initialHatim),
      ),
    );
    if (justCompleted == true && context.mounted) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🎉', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 12),
              const Text(
                'Hatim Tamamlandı',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              const Text(
                'Mâşallah! Bir hatmi tamamladınız. Allah kabul eylesin.',
                style: TextStyle(fontSize: 15, color: AppColors.textMid),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.teal,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(
                    'Âmin',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  @override
  State<LogEntryBottomSheet> createState() => _LogEntryBottomSheetState();
}

class _LogEntryBottomSheetState extends State<LogEntryBottomSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<Hatim> _hatims = [];
  bool _loadingHatims = true;
  bool _isLoading = false;

  // ── Devam ──────────────────────────────────────────────────────────
  Hatim? _devamHatim;
  final _devamPagesCtrl = TextEditingController();

  // ── Sayfa ──────────────────────────────────────────────────────────
  final _startPageCtrl = TextEditingController();
  final _endPageCtrl = TextEditingController();
  Hatim? _sayfaHatim;

  // ── Cüz ────────────────────────────────────────────────────────────
  CuzInfo? _selectedCuz;
  Hatim? _cuzHatim;

  // ── Sure ───────────────────────────────────────────────────────────
  SurahInfo? _selectedSurah;

  // ── Ortak tür seçici ───────────────────────────────────────────────
  HatimType _globalType = HatimType.arapca;

  bool get _lockedToHatim => widget.initialHatim != null;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _lockedToHatim ? 3 : 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
    if (_lockedToHatim) {
      _devamHatim = widget.initialHatim;
      _sayfaHatim = widget.initialHatim;
      _cuzHatim = widget.initialHatim;
      _globalType = widget.initialHatim!.type;
    }
    _fetchHatims();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _devamPagesCtrl.dispose();
    _startPageCtrl.dispose();
    _endPageCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchHatims() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _loadingHatims = false);
      return;
    }
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('hatims')
        .orderBy('updatedAt', descending: true)
        .get();
    if (!mounted) return;
    setState(() {
      _hatims = snap.docs
          .map((d) => Hatim.fromFirestore(d))
          .where((h) => !h.isCompleted)
          .toList();
      _loadingHatims = false;
      // Devam sekmesinde tek hatim varsa otomatik seç
      if (widget.initialHatim == null && _hatims.length == 1) {
        _devamHatim = _hatims.first;
      }
    });
  }

  // ── Yardımcı ───────────────────────────────────────────────────────

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.errorRed),
    );
  }

  // ── Kaydet ─────────────────────────────────────────────────────────

  Future<void> _saveLog() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    int pagesRead;
    LogMethod method;
    int? startPage;
    int? endPage;
    int? surahId;
    String? hatimId;
    HatimType type;
    Hatim? linkedHatim;
    int? devamEnteredPages; // kullanıcının girdiği sayfa — overflow tespiti için

    switch (_tabController.index) {
      case 0: // Devam
        if (_devamHatim == null) {
          _showError('Lütfen bir hatim seçin.');
          return;
        }
        final entered = int.tryParse(_devamPagesCtrl.text) ?? 0;
        if (entered <= 0) {
          _showError('Kaç sayfa okuduğunu gir.');
          return;
        }
        method = LogMethod.hatim;
        type = _devamHatim!.type;
        startPage = _devamHatim!.lastReadPage >= 604
            ? _devamHatim!.firstUnreadPage
            : (_devamHatim!.lastReadPage + 1).clamp(1, 604);
        endPage = (startPage + entered - 1).clamp(1, 604);
        pagesRead = endPage - startPage + 1; // gerçek sayfa adedi (clamped)
        devamEnteredPages = entered;
        hatimId = _devamHatim!.id;
        linkedHatim = _devamHatim;

      case 1: // Sayfa
        final s = int.tryParse(_startPageCtrl.text) ?? 0;
        final e = int.tryParse(_endPageCtrl.text) ?? 0;
        if (s <= 0) { _showError('Başlangıç sayfasını gir.'); return; }
        if (e <= 0) { _showError('Bitiş sayfasını gir.'); return; }
        if (e > 604) { _showError('Bitiş sayfası 604\'ten büyük olamaz.'); return; }
        if (s > e) { _showError('Başlangıç sayfası bitiş sayfasından büyük olamaz.'); return; }
        method = LogMethod.pages;
        type = _sayfaHatim?.type ?? _globalType;
        startPage = s;
        endPage = e;
        pagesRead = e - s + 1;
        hatimId = _sayfaHatim?.id;
        linkedHatim = _sayfaHatim;

      case 2: // Cüz
        if (_selectedCuz == null) { _showError('Lütfen bir cüz seç.'); return; }
        method = LogMethod.cuz;
        type = _cuzHatim?.type ?? _globalType;
        startPage = _selectedCuz!.startPage;
        endPage = _selectedCuz!.endPage;
        pagesRead = _selectedCuz!.pageCount;
        hatimId = _cuzHatim?.id;
        linkedHatim = _cuzHatim;

      default: // Sure
        if (_selectedSurah == null) { _showError('Lütfen bir sure seç.'); return; }
        method = LogMethod.surah;
        type = _globalType;
        surahId = _selectedSurah!.id;
        startPage = _selectedSurah!.startPage;
        endPage = _selectedSurah!.endPage;
        pagesRead = _selectedSurah!.startPage == 0
            ? 1
            : (_selectedSurah!.endPage - _selectedSurah!.startPage + 1);
        hatimId = null;
        linkedHatim = null;
    }

    if (pagesRead <= 0) return;

    // Devam sekmesinde kullanıcı kalan sayfadan fazla girdiyse uyar
    if (devamEnteredPages != null &&
        devamEnteredPages > pagesRead &&
        linkedHatim != null &&
        !linkedHatim.isCompleted) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Hatim bitiyor',
              style: TextStyle(fontWeight: FontWeight.bold)),
          content: Text(
            'Hatimini bitirmene $pagesRead sayfa kaldı.\n\n'
            '$pagesRead sayfa okundu işaretlenecek ve ${pagesRead * 10} hasanat eklenecek.',
            style: const TextStyle(color: AppColors.textMid),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('İptal', style: TextStyle(color: AppColors.textMid)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.teal,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Tamam',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ) ?? false;
      if (!confirmed) return;
    }

    setState(() => _isLoading = true);

    try {
      // Race condition önleme: ekran açılışındaki auto-freeze henüz
      // tamamlanmamış olabilir; log kaydından önce bir kez daha çalıştır.
      try {
        await StreakFreezeService.autoApplyFreezes(user.uid);
      } catch (_) {}

      final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);

      // ── Seri hesabı ──────────────────────────────────────────────────
      final userDocSnap = await userRef.get();
      final userData = userDocSnap.data();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final lastLogTs = userData?['lastLogDate'] as Timestamp?;
      final lastLogDate = lastLogTs?.toDate();
      final currentSeri = (userData?['seri'] as int?) ?? 0;
      // Bug 1: Animasyon için gerçek görüntülenen seri (Firestore'daki ham değer değil)
      final displayedSeri = seriDisplayState(currentSeri, lastLogTs).value;

      final Map<String, dynamic> seriUpdate;
      bool needsSeriRecalculate = false;

      if (lastLogDate != null && !lastLogDate.isBefore(today)) {
        // Bugün zaten okundu — seri değişmez
        seriUpdate = {'lastLogDate': FieldValue.serverTimestamp()};
      } else if (lastLogDate != null && !lastLogDate.isBefore(yesterday)) {
        // lastLogDate dün — seri uzuyor
        seriUpdate = {'seri': currentSeri + 1, 'lastLogDate': FieldValue.serverTimestamp()};
      } else {
        // lastLogDate null — dünkü loglara bak (migration / veri bozulması)
        final hadLogYesterday = lastLogDate == null
            ? await userRef.collection('logs')
                .where('type', whereIn: ['arapca', 'meal'])
                .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(yesterday))
                .where('createdAt', isLessThan: Timestamp.fromDate(today))
                .limit(1)
                .get()
                .then((s) => s.docs.isNotEmpty)
            : false;
        if (hadLogYesterday) {
          // Gerçek zincir uzunluğunu bilmiyoruz; commit sonrası recalculate hesaplar
          needsSeriRecalculate = true;
          seriUpdate = {'lastLogDate': FieldValue.serverTimestamp()};
        } else {
          seriUpdate = {'seri': 1, 'lastLogDate': FieldValue.serverTimestamp()};
        }
      }
      // ─────────────────────────────────────────────────────────────────

      final batch = FirebaseFirestore.instance.batch();

      final logRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('logs')
          .doc();

      batch.set(logRef, ReadingLog(
        id: '',
        type: type,
        method: method,
        pagesRead: pagesRead,
        surahId: surahId,
        startPage: startPage,
        endPage: endPage,
        hatimId: hatimId,
        createdAt: DateTime.now(),
      ).toMap());

      // weeklyHasanat: mevcut haftaysa increment, yeni haftaysa prev'e taşı ve sıfırla
      final weekMonday = today.subtract(Duration(days: today.weekday - 1));
      final weekStartStr = '${weekMonday.year}-${weekMonday.month.toString().padLeft(2, '0')}-${weekMonday.day.toString().padLeft(2, '0')}';
      final existingWeekStr = userData?['weeklyStartDate'] as String?;
      final Map<String, dynamic> weeklyUpdate;
      if (existingWeekStr == weekStartStr) {
        weeklyUpdate = {
          'weeklyHasanat': FieldValue.increment(pagesRead * 10),
          'weeklyStartDate': weekStartStr,
        };
      } else if (existingWeekStr == null) {
        // Migration: weeklyStartDate hiç set edilmemiş — bu haftaki mevcut logları topla
        final weekStartTs = Timestamp.fromDate(weekMonday);
        final existingSnap = await userRef.collection('logs')
            .where('createdAt', isGreaterThanOrEqualTo: weekStartTs)
            .get();
        int existingWeekPages = 0;
        for (final doc in existingSnap.docs) {
          final logType = doc.data()['type'] as String?;
          if (logType != 'arapca' && logType != 'meal') continue;
          existingWeekPages += (doc.data()['pagesRead'] as int?) ?? 0;
        }
        weeklyUpdate = {
          'weeklyHasanat': (existingWeekPages + pagesRead) * 10,
          'weeklyStartDate': weekStartStr,
        };
      } else {
        // Yeni hafta — önceki haftanın değerini arşiv için prevWeekly* alanlarına taşı
        weeklyUpdate = {
          'weeklyHasanat': pagesRead * 10,
          'weeklyStartDate': weekStartStr,
          'prevWeeklyStartDate': existingWeekStr,
          'prevWeeklyHasanat': (userData?['weeklyHasanat'] as int?) ?? 0,
        };
      }

      batch.set(userRef, {
        'hasanat': FieldValue.increment(pagesRead * 10),
        'totalPages': FieldValue.increment(pagesRead),
        ...seriUpdate,
        ...weeklyUpdate,
      }, SetOptions(merge: true));

      if (linkedHatim != null && hatimId != null) {
        final hatimRef = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('hatims')
            .doc(hatimId);

        // Sadece updatedAt güncelle — tamamlanma kontrolü recalculate'e bırakılıyor
        batch.update(hatimRef, {
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      // lastLogDate null iken dünkü log bulunduysa — gerçek seri uzunluğunu hesapla
      if (needsSeriRecalculate) {
        await SeriCalculator.recalculate(user.uid);
      }

      bool justCompleted = false;
      if (hatimId != null) {
        justCompleted = await HatimCalculator.recalculate(user.uid, hatimId);
      }

      // ── Tilavet Secdesi kontrolü ─────────────────────────────────────
      if (mounted) {
        final secdePages = TilavetSecdeData.secdesInRange(startPage, endPage);
        for (final sPage in secdePages) {
          if (!mounted) break;
          await _showSecdePrompt(user.uid, hatimId, sPage);
        }
      }
      // ─────────────────────────────────────────────────────────────────

      // ── Seri animasyonu ──────────────────────────────────────────────
      // Bug 8: needsSeriRecalculate durumunda da animasyon göster
      int newSeri;
      if (seriUpdate.containsKey('seri')) {
        newSeri = (seriUpdate['seri'] as int);
      } else if (needsSeriRecalculate) {
        // recalculate yaptı — Firestore'dan güncel seriyi oku
        final refreshed = await userRef.get();
        newSeri = (refreshed.data()?['seri'] as int?) ?? 1;
      } else {
        newSeri = displayedSeri; // Bugün zaten okunmuş, değişmedi
      }

      // Bug 1: prevCount olarak Firestore ham değeri değil, görüntülenen değer kullanılıyor
      final shouldShowAnimation = newSeri > displayedSeri;

      ({List<bool> filled, List<String> labels})? weekData;
      if (shouldShowAnimation && mounted) {
        try {
          weekData = await _getWeekFilled(user.uid);
        } catch (e) {
          debugPrint('Seri animasyonu yüklenemedi: $e');
        }
      }
      // ─────────────────────────────────────────────────────────────────

      if (!mounted) return;

      // Milestone kontrolü — animasyondan bağımsız her log sonrası çalışır.
      // Transaction ile idempotent; aynı milestone iki kez claim edilemez.
      final milestoneResult = await StreakFreezeService.claimMilestones(
          uid: user.uid, newSeri: newSeri);

      final overlayCtx = Navigator.of(context, rootNavigator: true).context;
      Navigator.pop(context, justCompleted);

      if (shouldShowAnimation && weekData != null) {
        final wd = weekData;
        final milestone = milestoneResult;
        final ctx = overlayCtx;
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!ctx.mounted) return;
          await StreakAnimationScreen.show(
            ctx,
            count: newSeri,
            prevCount: displayedSeri,
            filled: wd.filled,
            dayLabels: wd.labels,
            todayIndex: 6,
          );
          if (milestone.claimed.isNotEmpty && ctx.mounted) {
            await StreakFreezeRewardScreen.show(
              ctx,
              milestoneDays: milestone.claimed.last,
              freezesGranted: milestone.totalGranted,
            );
          }
        });
      }
    } catch (e, st) {
      debugPrint('LOG KAYDETME HATASI: $e\n$st');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kaydetme hatası: $e'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    }
  }

  // ── Son 7 günlük doluluk verisi (seri animasyonu için) ──────────────
  // Bug 2: .toLocal() eklendi — gece yarısı UTC/yerel fark sorunu giderildi
  // Bug 3: whereIn filtresi — namaz/alışkanlık logları sayılmıyor
  // Bug 5: Hafta sınırı yerine son 7 gün — hafta geçişi görsel kopukluğu giderildi

  static const _dayAbbr = ['Pt', 'Sa', 'Ça', 'Pe', 'Cu', 'Ct', 'Pa'];

  Future<({List<bool> filled, List<String> labels})> _getWeekFilled(String uid) async {
    final now     = DateTime.now();
    final today   = DateTime(now.year, now.month, now.day);
    final startDay = today.subtract(const Duration(days: 6));

    final results = await Future.wait([
      FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('logs')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDay))
          .get(),
      FirebaseFirestore.instance.collection('users').doc(uid).get(),
    ]);

    final logsSnap = results[0] as QuerySnapshot;
    final userSnap = results[1] as DocumentSnapshot;
    final frozenDates = Set<String>.from(
      ((userSnap.data() as Map<String, dynamic>?)?['frozenDates']
              as List<dynamic>?) ??
          [],
    );

    final loggedDays = <String>{...frozenDates};
    for (final doc in logsSnap.docs) {
      final docData = doc.data() as Map<String, dynamic>?;
      if (docData == null) continue;
      final type = docData['type'] as String?;
      if (type != 'arapca' && type != 'meal') continue;
      final d = (docData['createdAt'] as Timestamp?)?.toDate().toLocal();
      if (d != null) {
        loggedDays.add(seriDateKey(d));
      }
    }

    final filled = List.generate(7, (i) {
      final day = startDay.add(Duration(days: i));
      return loggedDays.contains(seriDateKey(day));
    });

    // Bug 5: Gün etiketleri dinamik — bugün daima index 6 (sağda)
    final labels = List.generate(7, (i) {
      final day = startDay.add(Duration(days: i));
      return _dayAbbr[day.weekday - 1];
    });

    return (filled: filled, labels: labels);
  }

  // ── Tilavet Secdesi Prompt ──────────────────────────────────────────

  Future<void> _showSecdePrompt(
      String uid, String? hatimId, int page) async {
    if (!mounted) return;
    final label = TilavetSecdeData.secdeLabel(page) ?? 'Tilavet Secdesi';

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🕌', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 12),
            Text(
              'Tilavet Secdesi',
              style: GoogleFonts.nunito(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '$label  (Sayfa $page) içeren bir bölüm okudunuz.\nTilavet secdesini yaptınız mı?',
              style: GoogleFonts.nunito(fontSize: 13, color: AppColors.textMid),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.check_circle_outline,
                    color: Colors.white, size: 18),
                label: Text(
                  'Yaptım',
                  style: GoogleFonts.nunito(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.pop(ctx, 'done'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.access_time,
                    color: AppColors.errorRed, size: 18),
                label: Text(
                  'Henüz Yapmadım',
                  style: GoogleFonts.nunito(
                    color: AppColors.errorRed,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: const BorderSide(color: AppColors.errorRed),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.pop(ctx, 'pending'),
              ),
            ),
          ],
        ),
      ),
    );

    if (result == null) return;

    // Firestore'a kaydet
    try {
      final docId = hatimId != null
          ? 'tilavet_secde_$hatimId'
          : 'tilavet_secde_free';
      final ref = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('logs')
          .doc(docId);
      await ref.set({
        'hatimId': hatimId,
        'type': 'tilavet_secde',
        'pages': {page.toString(): result},
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Secde prompt save error: \$e');
    }
  }

  // ── Yardımcı ───────────────────────────────────────────────────────

  String _hatimPositionText(Hatim hatim) {
    if (hatim.currentPage == 0) return 'Henüz başlanmadı';
    return '${hatim.currentPage}/604 sayfa okundu';
  }

  String _hatimSurahText(Hatim hatim) {
    if (hatim.lastReadPage == 0) return 'Fâtiha';
    return QuranData.surahsOnPage(hatim.lastReadPage);
  }

  // ── Tab: Devam ──────────────────────────────────────────────────────

  Widget _buildDevamTab() {
    if (_loadingHatims && _devamHatim == null) {
      return const Center(child: CircularProgressIndicator(color: AppColors.teal));
    }

    // Eğer initialHatim ile gelindiyse hatim zaten seçili — direk input göster
    if (_devamHatim != null) {
      final nextPage = _devamHatim!.lastReadPage >= 604
          ? _devamHatim!.firstUnreadPage
          : (_devamHatim!.lastReadPage + 1).clamp(1, 604);
      final nextCuz = QuranData.cuzForPage(nextPage);
      final nextSurah = QuranData.surahsOnPage(nextPage);

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Seçili hatim bilgi kartı
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.tealLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.teal.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.teal,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _devamHatim!.type == HatimType.arapca ? Icons.menu_book : Icons.translate,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _devamHatim!.displayName,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.teal),
                      ),
                      Text(
                        _hatimPositionText(_devamHatim!),
                        style: const TextStyle(fontSize: 12, color: AppColors.teal),
                      ),
                      Text(
                        _hatimSurahText(_devamHatim!),
                        style: TextStyle(
                            fontSize: 11, color: AppColors.teal.withValues(alpha: 0.7)),
                      ),
                    ],
                  ),
                ),
                // Birden fazla hatim varsa ve kilitli değilse değiştir seçeneği
                if (_hatims.length > 1 && !_lockedToHatim)
                  GestureDetector(
                    onTap: () => setState(() => _devamHatim = null),
                    child: const Text('Değiştir',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppColors.teal,
                            fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.lightGrey,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.play_arrow_rounded, size: 18, color: AppColors.teal),
                const SizedBox(width: 8),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(fontSize: 12, color: AppColors.textMid),
                      children: [
                        const TextSpan(text: 'Devam: '),
                        TextSpan(
                          text: 'Sayfa $nextPage',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.teal),
                        ),
                        if (nextCuz != null)
                          TextSpan(text: ' · ${nextCuz.cuzNo}. cüz'),
                        if (nextSurah.isNotEmpty)
                          TextSpan(text: ' · $nextSurah'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _devamPagesCtrl,
            keyboardType: TextInputType.number,
            autofocus: widget.initialHatim != null,
            textInputAction: TextInputAction.done,
            maxLength: 4,
            onSubmitted: (_) => _saveLog(),
            decoration: InputDecoration(
              labelText: 'Kaç sayfa okudun?',
              prefixIcon: const Icon(Icons.add),
              counterText: '',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.teal),
              ),
            ),
          ),
        ],
      );
    }

    // Hatim seçim ekranı
    if (_hatims.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.info_outline, color: AppColors.textLight, size: 40),
            const SizedBox(height: 8),
            const Text('Aktif hatiminiz yok.',
                style: TextStyle(color: AppColors.textMid)),
            const SizedBox(height: 4),
            const Text('Sayfa, Cüz veya Sure sekmesinden serbest log girebilirsiniz.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textLight, fontSize: 12)),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Hangi hatim?',
            style: TextStyle(color: AppColors.textMid, fontSize: 13)),
        const SizedBox(height: 8),
        ..._hatims.map((h) => _HatimSelectCard(
              hatim: h,
              isSelected: false,
              positionText: _hatimPositionText(h),
              surahText: _hatimSurahText(h),
              onTap: () => setState(() => _devamHatim = h),
            )),
      ],
    );
  }

  // ── Tab: Sayfa ──────────────────────────────────────────────────────

  Widget _buildSayfaTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _startPageCtrl,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  maxLength: 4,
                  decoration: InputDecoration(
                    labelText: 'Başlangıç',
                    counterText: '',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.teal),
                    ),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text('–',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textMid)),
              ),
              Expanded(
                child: TextField(
                  controller: _endPageCtrl,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  maxLength: 4,
                  onSubmitted: (_) => _saveLog(),
                  decoration: InputDecoration(
                    labelText: 'Bitiş',
                    counterText: '',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.teal),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_lockedToHatim) ...[
            const SizedBox(height: 12),
            _LockedHatimBadge(hatim: widget.initialHatim!),
          ] else if (_hatims.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('Hatimle ilişkilendir (opsiyonel):',
                style: TextStyle(color: AppColors.textMid, fontSize: 13)),
            const SizedBox(height: 8),
            _OptionalHatimChips(
              hatims: _hatims.where((h) => h.type == _globalType).toList(),
              selected: _sayfaHatim,
              onChanged: (h) => setState(() => _sayfaHatim = h),
            ),
          ],
        ],
      ),
    );
  }

  // ── Tab: Cüz ────────────────────────────────────────────────────────

  Widget _buildCuzTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownSearch<CuzInfo>(
            items: (filter, _) => QuranData.cuzler,
            itemAsString: (c) => '${c.cuzNo}. Cüz  (${c.startPage}–${c.endPage}. sayfa)',
            compareFn: (a, b) => a.cuzNo == b.cuzNo,
            onSelected: (c) => setState(() => _selectedCuz = c),
            popupProps: const PopupProps.menu(showSearchBox: false),
            decoratorProps: DropDownDecoratorProps(
              decoration: InputDecoration(
                labelText: 'Cüz seç',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.teal),
                ),
              ),
            ),
          ),
          if (_selectedCuz != null) ...[
            const SizedBox(height: 6),
            Text(
              '${_selectedCuz!.pageCount} sayfa kaydedilecek  (${_selectedCuz!.startPage}–${_selectedCuz!.endPage})',
              style: const TextStyle(
                  color: AppColors.teal, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ],
          if (_lockedToHatim) ...[
            const SizedBox(height: 12),
            _LockedHatimBadge(hatim: widget.initialHatim!),
          ] else if (_hatims.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('Hatimle ilişkilendir (opsiyonel):',
                style: TextStyle(color: AppColors.textMid, fontSize: 13)),
            const SizedBox(height: 8),
            _OptionalHatimChips(
              hatims: _hatims.where((h) => h.type == _globalType).toList(),
              selected: _cuzHatim,
              onChanged: (h) => setState(() => _cuzHatim = h),
            ),
          ],
        ],
      ),
    );
  }

  // ── Tab: Sure ───────────────────────────────────────────────────────

  Widget _buildSureTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownSearch<SurahInfo>(
            items: (filter, _) => QuranData.surahlar,
            itemAsString: (s) => '${s.id}. ${s.name}',
            filterFn: (s, filter) => turkishContains('${s.id}. ${s.name}', filter),
            compareFn: (a, b) => a.id == b.id,
            onSelected: (s) => setState(() => _selectedSurah = s),
            popupProps: const PopupProps.menu(
              showSearchBox: true,
              searchFieldProps: TextFieldProps(
                decoration: InputDecoration(
                  hintText: 'Sure ara...',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
            decoratorProps: DropDownDecoratorProps(
              decoration: InputDecoration(
                labelText: 'Sure seç',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.teal),
                ),
              ),
            ),
          ),
          if (_selectedSurah != null) ...[
            const SizedBox(height: 6),
            Text(
              _selectedSurah!.startPage == 0
                  ? 'Fâtiha — 1 sayfa kaydedilecek'
                  : '${_selectedSurah!.endPage - _selectedSurah!.startPage + 1} sayfa kaydedilecek  (${_selectedSurah!.startPage}–${_selectedSurah!.endPage})',
              style: const TextStyle(
                  color: AppColors.teal, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline, size: 13, color: AppColors.textLight),
              const SizedBox(width: 4),
              const Expanded(
                child: Text(
                  'Sure logları serbest kaydedilir — hatimle ilişkilendirilemez.',
                  style: TextStyle(color: AppColors.textLight, fontSize: 11),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Okuma Kaydet',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark)),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.history, color: AppColors.textMid),
                    onPressed: () => LogHistorySheet.show(context),
                    tooltip: 'Kayıt geçmişi',
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Builder(builder: (context) {
            final tabIndex = _tabController.index;
            final bool isDevam = tabIndex == 0;
            final bool hasSayfaHatim = tabIndex == 1 && _sayfaHatim != null;
            final bool hasCuzHatim = tabIndex == 2 && _cuzHatim != null;
            final bool locked = isDevam || hasSayfaHatim || hasCuzHatim;
            HatimType displayType = _globalType;
            if (isDevam && _devamHatim != null) displayType = _devamHatim!.type;
            if (hasSayfaHatim) displayType = _sayfaHatim!.type;
            if (hasCuzHatim) displayType = _cuzHatim!.type;
            return _TypeToggle(
              selected: displayType,
              enabled: !locked,
              onChanged: (t) => setState(() {
                _globalType = t;
                if (_sayfaHatim?.type != t) _sayfaHatim = null;
                if (_cuzHatim?.type != t) _cuzHatim = null;
              }),
            );
          }),
          const SizedBox(height: 4),
          TabBar(
            controller: _tabController,
            labelColor: AppColors.teal,
            unselectedLabelColor: AppColors.textLight,
            indicatorColor: AppColors.teal,
            labelPadding: EdgeInsets.zero,
            onTap: (_) => setState(() {}),
            tabs: [
              const Tab(text: 'Devam'),
              const Tab(text: 'Sayfa'),
              const Tab(text: 'Cüz'),
              if (!_lockedToHatim) const Tab(text: 'Sure'),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 260,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildDevamTab(),
                _buildSayfaTab(),
                _buildCuzTab(),
                if (!_lockedToHatim) _buildSureTab(),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SaveButton(isLoading: _isLoading, onPressed: _saveLog),
        ],
      ),
    );
  }
}

// ── Alt bileşenler ─────────────────────────────────────────────────────────────

class _HatimSelectCard extends StatelessWidget {
  final Hatim hatim;
  final bool isSelected;
  final String positionText;
  final String surahText;
  final VoidCallback onTap;

  const _HatimSelectCard({
    required this.hatim,
    required this.isSelected,
    required this.positionText,
    required this.surahText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isArapca = hatim.type == HatimType.arapca;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.tealLight : Colors.white,
          border: Border.all(
            color: isSelected ? AppColors.teal : AppColors.borderGrey,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.teal : AppColors.borderGrey,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isArapca ? Icons.menu_book : Icons.translate,
                color: isSelected ? Colors.white : AppColors.textMid,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hatim.displayName,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isSelected ? AppColors.teal : AppColors.textDark,
                    ),
                  ),
                  Text(positionText,
                      style: const TextStyle(color: AppColors.textMid, fontSize: 12)),
                  Text(surahText,
                      style: const TextStyle(color: AppColors.textLight, fontSize: 11)),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: AppColors.teal, size: 20),
          ],
        ),
      ),
    );
  }
}

class _LockedHatimBadge extends StatelessWidget {
  final Hatim hatim;
  const _LockedHatimBadge({required this.hatim});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.tealLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.teal.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.link, size: 14, color: AppColors.teal),
          const SizedBox(width: 6),
          Text(
            hatim.displayName,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.teal),
          ),
        ],
      ),
    );
  }
}

class _OptionalHatimChips extends StatelessWidget {
  final List<Hatim> hatims;
  final Hatim? selected;
  final ValueChanged<Hatim?> onChanged;

  const _OptionalHatimChips({
    required this.hatims,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        _Chip(
          label: 'Serbest Okuma',
          icon: Icons.lock_open,
          isSelected: selected == null,
          onTap: () => onChanged(null),
        ),
        ...hatims.map((h) => _Chip(
              label: h.displayName,
              icon: h.type == HatimType.arapca ? Icons.menu_book : Icons.translate,
              isSelected: selected?.id == h.id,
              onTap: () => onChanged(h),
            )),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.tealLight : Colors.white,
          border: Border.all(
            color: isSelected ? AppColors.teal : AppColors.borderGrey,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: isSelected ? AppColors.teal : AppColors.textMid),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? AppColors.teal : AppColors.textMid,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeToggle extends StatelessWidget {
  final HatimType selected;
  final bool enabled;
  final ValueChanged<HatimType> onChanged;

  const _TypeToggle({required this.selected, required this.onChanged, this.enabled = true});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.55,
      child: SegmentedButton<HatimType>(
        segments: const [
          ButtonSegment(value: HatimType.arapca, label: Text('Arapça'), icon: Icon(Icons.menu_book)),
          ButtonSegment(value: HatimType.meal, label: Text('Meal'), icon: Icon(Icons.translate)),
        ],
        selected: {selected},
        onSelectionChanged: enabled ? (s) => onChanged(s.first) : null,
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected) ? AppColors.teal : Colors.transparent),
          foregroundColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected) ? Colors.white : AppColors.teal),
        ),
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onPressed;

  const _SaveButton({required this.isLoading, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return DuolingoButton(
      height: 48, // Toplam 52px (48 + 4 depth)
      color: AppColors.teal,
      bottomColor: AppColors.tealDark,
      disabledColor: AppColors.borderGrey,
      onPressed: isLoading ? null : onPressed,
      isLoading: isLoading,
      child: const Text(
        'KAYDET',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 16,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
