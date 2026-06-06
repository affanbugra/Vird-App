import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../app_colors.dart';
import '../models/vird_model.dart';
import '../utils/seri_calculator.dart';
import 'vird_library_screen.dart';
import '../widgets/zikirmatik_modal.dart';
import '../widgets/habit_tracker_widget.dart';
import '../widgets/habit_heat_map_sheet.dart';
import '../screens/streak_animation_screen.dart';
import '../services/streak_freeze_service.dart';

class VirdlerimContentWidget extends StatefulWidget {
  const VirdlerimContentWidget({super.key});

  @override
  State<VirdlerimContentWidget> createState() => _VirdlerimContentWidgetState();
}

class _VirdlerimContentWidgetState extends State<VirdlerimContentWidget>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  final _uid = FirebaseAuth.instance.currentUser?.uid;
  late DateTime _selectedDate;
  
  // dateStr -> { virdId: count }
  final Map<String, Map<String, int>> _selectedWeekLogs = {};

  List<VirdItem> _activeVirds = [];
  // Kullanıcının kategori bazlı özel sıralaması — boşsa zaman sırasına düşer
  Map<String, List<String>> _virdOrder = {};
  VirdLog? _currentLog;
  bool _loadingPreferences = true;
  // Sure log: "son istek kazanır" kuyruğu — race condition önleme
  // virdId → true=oluştur, false=sil
  final _sureLogPendingIntent = <String, bool>{};
  final _sureLogProcessing = <String>{};
  StreamSubscription? _prefsSub;
  StreamSubscription? _logSub;
  DateTime? _userCreatedAt;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    _fetchSelectedWeekLogs();
    
    _listenPreferences();
    _listenLog();
  }

  @override
  void dispose() {
    _prefsSub?.cancel();
    _logSub?.cancel();
    super.dispose();
  }

  void _listenPreferences() {
    if (_uid == null) {
      if (mounted) setState(() => _loadingPreferences = false);
      return;
    }
    _prefsSub?.cancel();
    _prefsSub = FirebaseFirestore.instance
        .collection('users')
        .doc(_uid)
        .snapshots()
        .listen((userSnap) {
      if (!mounted) return;
      
      // Yeni kullanıcılar için varsayılan olarak hepsi kapalı; kullanıcı prefsMap'te aktif etmediyse gösterilmez
      final List<VirdItem> allVirds = VirdItem.defaultVirds.map((e) => e.copyWith(active: false)).toList();
      final userData = userSnap.data() ?? {};
      final prefsMap = userData['virdPreferences'] as Map<String, dynamic>? ?? {};
      final createdAtTs = userData['createdAt'] as Timestamp?;
      final userCreatedAt = createdAtTs?.toDate();

      prefsMap.forEach((id, val) {
        final map = Map<String, dynamic>.from(val as Map);
        final isCustom = map['isCustom'] ?? false;

        if (isCustom) {
          allVirds.add(VirdItem.fromMap({...map, 'id': id}));
        } else {
          final idx = allVirds.indexWhere((e) => e.id == id);
          if (idx != -1) {
            final defaultMap = allVirds[idx].toMap();
            allVirds[idx] = VirdItem.fromMap({
              ...defaultMap,
              ...map,
              // İçerik alanları her zaman koddan gelir — Firestore'daki eskiler geçersiz
              'hadith': defaultMap['hadith'],
              'description': defaultMap['description'],
              'arabicTitle': defaultMap['arabicTitle'],
              'recommendedTime': defaultMap['recommendedTime'],
            });
          }
        }
      });

      // Sadece aktif virdleri filtrele
      final activeVirds = allVirds.where((e) => e.active).toList();

      // Kullanıcı özel kategori sıralaması
      final orderRaw = userData['virdOrder'] as Map<String, dynamic>? ?? {};
      final Map<String, List<String>> parsedOrder = {};
      orderRaw.forEach((k, v) {
        if (v is List) parsedOrder[k] = v.map((e) => e.toString()).toList();
      });

      setState(() {
        _activeVirds = activeVirds;
        _virdOrder = parsedOrder;
        _userCreatedAt = userCreatedAt;
        _loadingPreferences = false;
      });
    }, onError: (e) {
      debugPrint("Error listening to preferences: $e");
      if (mounted) setState(() => _loadingPreferences = false);
    });
  }

  Future<void> _saveCategoryOrder(String categoryKey, List<String> orderedIds) async {
    // Optimistic local update; snapshot listener doğrulayacak
    setState(() {
      _virdOrder = {..._virdOrder, categoryKey: orderedIds};
    });
    if (_uid == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .set({
        'virdOrder': {categoryKey: orderedIds},
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error saving vird order: $e');
    }
  }

  void _listenLog() {
    if (_uid == null) return;
    _logSub?.cancel();
    final dateKey = _todayDateStr();
    _logSub = FirebaseFirestore.instance
        .collection('users')
        .doc(_uid)
        .collection('logs')
        .doc(dateKey)
        .snapshots()
        .listen((logSnap) {
      if (!mounted) return;
      final log = VirdLog.fromDoc(logSnap);
      setState(() {
        _currentLog = log;
      });
    }, onError: (e) {
      debugPrint("Error listening to log: $e");
    });
  }

  Future<void> _fetchSelectedWeekLogs() async {
    if (_uid == null) return;
    try {
      final monday = _selectedDate.subtract(Duration(days: _selectedDate.weekday - 1));
      final List<String> dateKeys = [];
      for (int i = 0; i < 7; i++) {
        final d = monday.add(Duration(days: i));
        dateKeys.add("vird_${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}");
      }
      
      final snaps = await Future.wait(
        dateKeys.map((key) => FirebaseFirestore.instance
            .collection('users')
            .doc(_uid)
            .collection('logs')
            .doc(key)
            .get()
        )
      );
      
      final Map<String, Map<String, int>> newLogs = {};
      for (var snap in snaps) {
        if (snap.exists) {
          final data = snap.data() ?? {};
          final comps = data['completions'] as Map<String, dynamic>? ?? {};
          final dateKey = snap.id;
          newLogs[dateKey] = comps.map((k, v) => MapEntry(k, v as int));
        }
      }
      
      if (mounted) {
        setState(() {
          _selectedWeekLogs.addAll(newLogs);
        });
      }
    } catch (e) {
      debugPrint("Error fetching selected week logs: $e");
    }
  }


  String _todayDateStr() {
    return "vird_${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}";
  }

  // Cuma günü kontrolü — seçili tarihe göre
  bool _isFriday() {
    return _selectedDate.weekday == DateTime.friday;
  }

  // Seçili tarih bugün mü?
  bool _isToday() {
    final now = DateTime.now();
    return _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;
  }

  Future<void> _updateVirdProgress(String virdId, int newCount) async {
    if (_uid == null) return;

    final dateKey = _todayDateStr();
    // Mevcut completions'ı optimistic update öncesinde snapshotla
    final mergedCompletions = <String, dynamic>{
      ...?_currentLog?.completions,
      virdId: newCount,
    };

    setState(() {
      if (_selectedWeekLogs[dateKey] == null) {
        _selectedWeekLogs[dateKey] = {};
      }
      _selectedWeekLogs[dateKey]![virdId] = newCount;
      if (_currentLog != null) {
        _currentLog!.completions[virdId] = newCount;
      }
    });

    try {
      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .collection('logs')
          .doc(dateKey);

      // runTransaction yerine direkt set — server round-trip okuma yok, flicker önlendi
      // SetOptions(merge: true): sureLogIds/sureLogPages gibi diğer alanlar korunur
      await docRef.set({
        'type': 'vird',
        'date': dateKey,
        'completions': mergedCompletions,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error saving progress: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_loadingPreferences) {
      return const Material(
        color: Colors.white,
        child: Center(
          child: CircularProgressIndicator(color: AppColors.teal),
        ),
      );
    }

    // Cuma değilse Kehf'i gizle — seçili tarihe göre kontrol edilir
    final activeVirds = _isFriday()
        ? _activeVirds
        : _activeVirds.where((e) => e.id != 'kehf').toList();
    final log = _currentLog ?? VirdLog(date: _todayDateStr(), completions: {});

    if (activeVirds.isEmpty) {
      return Material(
        color: Colors.white,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          children: [
            _buildLibraryShowcaseCard(const []),
            const SizedBox(height: 12),
            _buildProgressCard(0, 0, 0.0, VirdLog(date: _todayDateStr(), completions: {})),
            const SizedBox(height: 24),
            _buildEmptyStateExploreNotice(),
            const SizedBox(height: 48),
          ],
        ),
      );
    }

    final List<VirdItem> uncompleted = [];
    final List<VirdItem> completed = [];

    for (final item in activeVirds) {
      final count = log.completions[item.id] ?? 0;
      if (count >= item.targetCount) {
        completed.add(item);
      } else {
        uncompleted.add(item);
      }
    }

    final double totalProgress = activeVirds.isNotEmpty
        ? ((completed.length) / activeVirds.length)
        : 0.0;

    // Helper function to build a categorized box — tek liste, tamamlanan kendi yerinde renklenir
    Widget buildCategoryGroup(
      String title,
      Color color,
      List<VirdItem> allItems,
      String categoryKey,
    ) {
      if (allItems.isEmpty) return const SizedBox.shrink();

      int completedCount = 0;
      for (final item in allItems) {
        final count = log.completions[item.id] ?? 0;
        if (count >= item.targetCount) completedCount++;
      }
      final total = allItems.length;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Kategori Başlığı + Sayaç
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 6, left: 4),
            child: Row(
              children: [
                Text(
                  title,
                  style: GoogleFonts.nunito(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: color,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '$completedCount/$total',
                    style: GoogleFonts.outfit(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Tek liste — tamamlanan satır kendi konumunda renklenir; uzun bas-sürükle ile sıralanabilir
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            proxyDecorator: (child, index, animation) {
              return AnimatedBuilder(
                animation: animation,
                builder: (context, child) {
                  final t = Curves.easeInOut.transform(animation.value);
                  return Material(
                    color: Colors.transparent,
                    elevation: t * 8,
                    shadowColor: Colors.black.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(12),
                    child: child,
                  );
                },
                child: child,
              );
            },
            itemCount: allItems.length,
            itemBuilder: (context, idx) {
              final item = allItems[idx];
              final count = log.completions[item.id] ?? 0;
              final isDone = count >= item.targetCount;
              return RepaintBoundary(
                key: ValueKey(item.id),
                child: ReorderableDelayedDragStartListener(
                  index: idx,
                  child: _buildVirdCard(
                    item,
                    count,
                    isDone: isDone,
                    isLast: idx == allItems.length - 1,
                  ),
                ),
              );
            },
            onReorder: (oldIdx, newIdx) {
              if (newIdx > oldIdx) newIdx -= 1;
              if (oldIdx == newIdx) return;
              final newList = List<VirdItem>.from(allItems);
              final moved = newList.removeAt(oldIdx);
              newList.insert(newIdx, moved);
              _saveCategoryOrder(categoryKey, newList.map((e) => e.id).toList());
            },
          ),
        ],
      );
    }

    final suresAll = activeVirds.where((e) => e.category == 'sure').toList();
    final zikirsAll = activeVirds.where((e) => e.category == 'zikir').toList();
    final duasAll = activeVirds.where((e) => e.category == 'dua').toList();
    final othersAll = activeVirds.where((e) => e.category != 'sure' && e.category != 'zikir' && e.category != 'dua').toList();

    // Namaz vakti sırasına göre sıralama haritası
    const timeOrder = {
      'Sabah Namazı Sonrası': 1,
      'Öğle Namazı Sonrası': 2,
      'İkindi Namazı Sonrası': 3,
      'Akşam Namazı Sonrası': 4,
      'Yatsı Namazı Sonrası': 5,
      'Cuma Gününe Özel': 6,
    };

    int getTimeSortOrder(VirdItem item) {
      return timeOrder[item.recommendedTime] ?? 99;
    }

    // Önce zaman sırasına göre dizilim; sonra kullanıcı özel sırası uygulanır
    suresAll.sort((a, b) => getTimeSortOrder(a).compareTo(getTimeSortOrder(b)));
    zikirsAll.sort((a, b) => getTimeSortOrder(a).compareTo(getTimeSortOrder(b)));
    duasAll.sort((a, b) => getTimeSortOrder(a).compareTo(getTimeSortOrder(b)));
    othersAll.sort((a, b) => getTimeSortOrder(a).compareTo(getTimeSortOrder(b)));

    List<VirdItem> applyCustomOrder(List<VirdItem> items, String categoryKey) {
      final saved = _virdOrder[categoryKey];
      if (saved == null || saved.isEmpty) return items;
      final byId = {for (final it in items) it.id: it};
      final ordered = <VirdItem>[];
      for (final id in saved) {
        final item = byId.remove(id);
        if (item != null) ordered.add(item);
      }
      // Kayıtlı sırada olmayan yeni virdleri sona ekle (zaman sırası korunur)
      ordered.addAll(items.where((it) => byId.containsKey(it.id)));
      return ordered;
    }

    final sures = applyCustomOrder(suresAll, 'sure');
    final zikirs = applyCustomOrder(zikirsAll, 'zikir');
    final duas = applyCustomOrder(duasAll, 'dua');
    final others = applyCustomOrder(othersAll, 'other');

    return Material(
      color: Colors.white,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        children: [
          _buildLibraryShowcaseCard(activeVirds),
          const SizedBox(height: 12),
          _buildDateSelector(),
          const SizedBox(height: 10),
          _buildProgressCard(completed.length, activeVirds.length, totalProgress, log),
          const SizedBox(height: 6),

          if (_isFriday()) _buildFridayBanner(),

          buildCategoryGroup('SURELER', AppColors.teal, sures, 'sure'),
          buildCategoryGroup('ZİKİRLER', AppColors.orange, zikirs, 'zikir'),
          buildCategoryGroup('DUALAR', AppColors.infoBlue, duas, 'dua'),
          buildCategoryGroup('DİĞER', AppColors.textMid, others, 'other'),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                const Icon(Icons.bookmark_border_rounded, size: 13, color: AppColors.textLight),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Tüm kaynaklar Profil > Ayarlar > Kaynakça bölümündedir.',
                    style: GoogleFonts.nunito(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textLight,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 36),
        ],
      ),
    );
  }

  Widget _buildProgressCard(int done, int total, double progress, VirdLog todayLog) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16, top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderGrey),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 50, height: 50,
            child: Stack(
              fit: StackFit.expand,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: progress),
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOutCubic,
                  builder: (context, animVal, _) => CircularProgressIndicator(
                    value: animVal,
                    strokeWidth: 6,
                    backgroundColor: AppColors.lightGrey,
                    color: progress == 1.0 ? AppColors.successGreen : AppColors.gold,
                  ),
                ),
                Center(
                  child: Text(
                    "$done/$total",
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                )
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  total == 0
                      ? 'Bu tarih için aktif vird yok'
                      : (progress == 1.0
                          ? 'Harika! Hepsini tamamladın 🎉'
                          : _isToday() ? 'Günlük Rutinim' : 'Geçmiş Gün'),
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
                Text(
                  '"Allah katında amellerin en sevimlisi, az da olsa devamlı olanıdır." (Buhârî, Teheccüd 18; Müslim, Müsâfirîn 216)',
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    color: AppColors.textMid,
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildFridayBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.successBg.withValues(alpha: 0.7),
        border: Border.all(color: AppColors.successGreen.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          const Text('🕌', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hayırlı Cumalar',
                  style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.emeraldGreen),
                ),
                Text(
                  'Bugün Kehf suresi okumak sünnettir ve büyük bir nurdur.',
                  style: GoogleFonts.nunito(fontSize: 11.5, color: AppColors.textDark, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelector() {
    final today = DateTime.now();
    final todayClean = DateTime(today.year, today.month, today.day);
    final monthNames = ["Ocak", "Şubat", "Mart", "Nisan", "Mayıs", "Haziran", "Temmuz", "Ağustos", "Eylül", "Ekim", "Kasım", "Aralık"];
    final dateDisplay = "${_selectedDate.day} ${monthNames[_selectedDate.month - 1]}";

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragEnd: (details) {
        final v = details.primaryVelocity ?? 0;
        if (v > 250) {
          setState(() {
            _selectedDate = _selectedDate.subtract(const Duration(days: 1));
            _currentLog = VirdLog(date: _todayDateStr(), completions: {});
          });
          _listenLog();
          _fetchSelectedWeekLogs();
        } else if (v < -250) {
          final next = _selectedDate.add(const Duration(days: 1));
          if (!next.isAfter(todayClean)) {
            setState(() {
              _selectedDate = next;
              _currentLog = VirdLog(date: _todayDateStr(), completions: {});
            });
            _listenLog();
            _fetchSelectedWeekLogs();
          }
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.lightGrey,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderGrey),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left_rounded, color: AppColors.textDark, size: 22),
              onPressed: () {
                setState(() {
                  _selectedDate = _selectedDate.subtract(const Duration(days: 1));
                  _currentLog = VirdLog(date: _todayDateStr(), completions: {});
                });
                _listenLog();
                _fetchSelectedWeekLogs();
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            Text(
              _selectedDate == todayClean ? "Bugün ($dateDisplay)" : dateDisplay,
              style: GoogleFonts.nunito(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.teal,
              ),
            ),
            if (_selectedDate.isBefore(todayClean))
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded, color: AppColors.textDark, size: 22),
                onPressed: () {
                  final next = _selectedDate.add(const Duration(days: 1));
                  if (!next.isAfter(todayClean)) {
                    setState(() {
                      _selectedDate = next;
                      _currentLog = VirdLog(date: _todayDateStr(), completions: {});
                    });
                    _listenLog();
                    _fetchSelectedWeekLogs();
                  }
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              )
            else
              const SizedBox(width: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildVirdCard(VirdItem item, int currentCount, {Key? key, bool isDone = false, bool isLast = false}) {
    final isZikir = item.category == 'zikir';

    // Kategoriye göre ikon ve soft renk seçimi
    IconData categoryIcon;
    Color categoryColor;
    
    switch (item.category) {
      case 'sure':
        categoryIcon = Icons.auto_stories_rounded;
        categoryColor = AppColors.teal;
        break;
      case 'zikir':
        categoryIcon = Icons.repeat_one_rounded;
        categoryColor = AppColors.orange;
        break;
      case 'dua':
        categoryIcon = Icons.volunteer_activism_rounded;
        categoryColor = AppColors.infoBlue;
        break;
      default:
        categoryIcon = Icons.bookmark_rounded;
        categoryColor = AppColors.textMid;
    }

    // Son 7 günlük haftalık gösterge
    final List<Widget> dotWidgets = [];
    final today = DateTime.now();
    final todayClean = DateTime(today.year, today.month, today.day);
    final monday = _selectedDate.subtract(Duration(days: _selectedDate.weekday - 1));
    
    for (int i = 0; i < 7; i++) {
      final d = monday.add(Duration(days: i));
      final dClean = DateTime(d.year, d.month, d.day);
      final dateKey = "vird_${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
      
      final comps = _selectedWeekLogs[dateKey] ?? {};
      final count = comps[item.id] ?? 0;
      
      final isSelectedDay = dClean.year == _selectedDate.year &&
                            dClean.month == _selectedDate.month &&
                            dClean.day == _selectedDate.day;
      
      Color dotColor;
      Border? dotBorder;

      if (dClean.isAfter(todayClean)) {
        dotColor = const Color(0xFFE5ECEE);
      } else if (count >= item.targetCount) {
        dotColor = categoryColor;
      } else if (count > 0) {
        dotColor = categoryColor.withValues(alpha: 0.6); // Kısmi ilerleme
      } else if (dClean == todayClean) {
        dotColor = Colors.white;
        dotBorder = Border.all(color: categoryColor, width: 1.0);
      } else {
        dotColor = const Color(0xFFE5ECEE);
      }

      if (isSelectedDay && !(dClean == todayClean && count == 0)) {
        dotBorder = Border.all(color: AppColors.textDark.withValues(alpha: 0.45), width: 1.2);
      }

      dotWidgets.add(
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 1.5),
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: dotColor,
            shape: BoxShape.circle,
            border: dotBorder,
          ),
        ),
      );
    }

    return Container(
      key: key,
      margin: const EdgeInsets.symmetric(vertical: 3),
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: isDone ? categoryColor.withValues(alpha: 0.18) : AppColors.white,
        border: Border.all(
          color: isDone
              ? categoryColor.withValues(alpha: 0.33)
              : AppColors.borderGrey,
          width: 1.0,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
        onTap: () => _showVirdHistoryHeatMap(item, categoryColor),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            children: [
              // Sol Kategori İkonu
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isDone ? categoryColor : categoryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: isDone
                      ? [BoxShadow(color: categoryColor.withValues(alpha: 0.27), blurRadius: 10, offset: const Offset(0, 4))]
                      : null,
                ),
                child: Icon(
                  categoryIcon,
                  color: isDone ? Colors.white : categoryColor,
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              
              // Orta Bilgi (Başlık + Alt Bilgi)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      item.title,
                      style: GoogleFonts.nunito(
                        fontSize: 14.0,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Text(
                          item.recommendedTime,
                          style: GoogleFonts.nunito(fontSize: 10.0, color: AppColors.textLight, fontWeight: FontWeight.w600),
                        ),
                        if (item.arabicTitle != null) ...[
                          const SizedBox(width: 6),
                          Text(
                            '•',
                            style: TextStyle(fontSize: 8, color: AppColors.textLight.withValues(alpha: 0.5)),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            item.arabicTitle!,
                            style: GoogleFonts.amiri(
                              fontSize: 10.5,
                              color: AppColors.textLight,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                        if (isZikir && !isDone) ...[
                          const SizedBox(width: 6),
                          Text(
                            '•',
                            style: TextStyle(fontSize: 8, color: AppColors.orange.withValues(alpha: 0.5)),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$currentCount / ${item.targetCount}',
                            style: GoogleFonts.nunito(
                              fontSize: 10.0,
                              color: AppColors.orange,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                        if (!isZikir && item.category != 'sure' && item.targetCount > 1 && !isDone) ...[
                          const SizedBox(width: 6),
                          Text(
                            '•',
                            style: TextStyle(fontSize: 8, color: categoryColor.withValues(alpha: 0.5)),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${item.targetCount} defa',
                            style: GoogleFonts.nunito(
                              fontSize: 10.0,
                              color: categoryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              
              // Son 5 Gün Form Takip Noktaları
              Row(
                mainAxisSize: MainAxisSize.min,
                children: dotWidgets,
              ),
              const SizedBox(width: 10),
              
              // Zikirmatik butonu — sadece zikir kartları için
              if (isZikir) ...[
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _openZikirmatik(item, currentCount),
                  child: Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    child: const Icon(Icons.touch_app_rounded, color: AppColors.orange, size: 19),
                  ),
                ),
                const SizedBox(width: 4),
              ],

              // Sağ Aksiyon Butonu (sure/dua/zikir hepsi aynı onay dairesi)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  HapticFeedback.selectionClick();
                  _toggleSureDua(item, currentCount);
                },
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDone ? categoryColor : Colors.white,
                    border: isDone
                        ? Border.all(color: categoryColor, width: 2.0)
                        : Border.all(color: const Color(0xFFD0D9DD), width: 2.0),
                  ),
                  child: isDone
                      ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                      : null,
                ),
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
        ),
      ),
    );
  }

  // Vird ID → Kuran sure bilgisi (id, başlangıç/bitiş sayfa)
  // Sayfa aralıkları lib/data/quran_cuz.dart ile hizalıdır.
  static const Map<String, ({int surahId, int startPage, int endPage})> _sureVirdMap = {
    'kehf':  (surahId: 18, startPage: 292, endPage: 303),
    'yasin': (surahId: 36, startPage: 439, endPage: 444),
    'fetih': (surahId: 48, startPage: 510, endPage: 514),
    'vakia': (surahId: 56, startPage: 533, endPage: 536),
    'mulk':  (surahId: 67, startPage: 561, endPage: 563),
    'nebe':  (surahId: 78, startPage: 581, endPage: 582),
  };

  void _toggleSureDua(VirdItem item, int current) {
    HapticFeedback.mediumImpact();
    final newCount = current >= item.targetCount ? 0 : item.targetCount;
    _updateVirdProgress(item.id, newCount);

    // Sadece varsayılan sure virdleri için okuma logu oluşturulur
    if (item.category == 'sure' && !item.isCustom && _sureVirdMap.containsKey(item.id)) {
      if (newCount >= item.targetCount) {
        // Tamamlandı
        if (_isToday()) {
          _requestSureLog(item, true);
        } else {
          _showTopNotification(
            context,
            'Vird kaydedildi. Bu tarih için okuma logu oluşturulmadı — istatistiklere ve Kuran haritasına yansıtmak istersen "Okuma Kaydet" ekranından manuel giriş yapabilirsin.',
            isError: false,
            duration: const Duration(milliseconds: 5000),
          );
        }
      } else {
        // Geri alındı — yalnızca bugünse logu sil
        if (_isToday()) _requestSureLog(item, false);
      }
    }
  }

  // Kullanıcı tıklamalarını sıralar; son istek her zaman kazanır
  void _requestSureLog(VirdItem item, bool shouldCreate) {
    _sureLogPendingIntent[item.id] = shouldCreate;
    if (!_sureLogProcessing.contains(item.id)) {
      _processSureLogQueue(item);
    }
  }

  // Kuyruğu tüketir — create devam ederken undo gelirse create biter, sonra undo çalışır
  Future<void> _processSureLogQueue(VirdItem item) async {
    _sureLogProcessing.add(item.id);
    try {
      while (_sureLogPendingIntent.containsKey(item.id)) {
        final shouldCreate = _sureLogPendingIntent.remove(item.id)!;
        if (shouldCreate) {
          await _doCreateSureReadingLog(item);
        } else {
          await _doDeleteSureReadingLog(item.id);
        }
      }
    } catch (e) {
      debugPrint('Sure log queue error: $e');
    } finally {
      _sureLogProcessing.remove(item.id);
    }
  }

  Future<void> _doCreateSureReadingLog(VirdItem item) async {
    if (_uid == null) return;
    final info = _sureVirdMap[item.id];
    if (info == null) return;

    try {
      final db = FirebaseFirestore.instance;
      final uid = _uid;
      final pagesRead = info.endPage - info.startPage + 1;
      final dateStr = _todayDateStr(); // await öncesinde yakala

      try { await StreakFreezeService.autoApplyFreezes(uid); } catch (_) {}

      final userRef = db.collection('users').doc(uid);
      final virdDocRef = db.collection('users').doc(uid).collection('logs').doc(dateStr);

      // Paralel: user doc + vird tracking doc
      final fetchResults = await Future.wait([userRef.get(), virdDocRef.get()]);
      final userSnap = fetchResults[0] as DocumentSnapshot;
      final virdSnap = fetchResults[1] as DocumentSnapshot;

      // İdempotency: bu sure için zaten log varsa tekrar oluşturma
      final existingLogId = (virdSnap.data() as Map<String, dynamic>?)?['sureLogIds']?[item.id] as String?;
      if (existingLogId != null) {
        debugPrint('Sure log for ${item.id} already exists ($existingLogId), skipping');
        return;
      }

      final userData = userSnap.data() as Map<String, dynamic>?;
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final lastLogTs = userData?['lastLogDate'] as Timestamp?;
      final lastLogDate = lastLogTs?.toDate();
      final currentSeri = (userData?['seri'] as int?) ?? 0;
      final displayedSeri = seriDisplayState(currentSeri, lastLogTs).value;

      final Map<String, dynamic> seriUpdate;
      bool needsSeriRecalculate = false;

      if (lastLogDate != null && !lastLogDate.isBefore(today)) {
        seriUpdate = {'lastLogDate': FieldValue.serverTimestamp()};
      } else if (lastLogDate != null && !lastLogDate.isBefore(yesterday)) {
        seriUpdate = {'seri': currentSeri + 1, 'lastLogDate': FieldValue.serverTimestamp()};
      } else {
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
          needsSeriRecalculate = true;
          seriUpdate = {'lastLogDate': FieldValue.serverTimestamp()};
        } else {
          seriUpdate = {'seri': 1, 'lastLogDate': FieldValue.serverTimestamp()};
        }
      }

      // Haftalık hasanat güncelleme (LogEntryBottomSheet ile birebir)
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
        weeklyUpdate = {
          'weeklyHasanat': pagesRead * 10,
          'weeklyStartDate': weekStartStr,
          'prevWeeklyStartDate': existingWeekStr,
          'prevWeeklyHasanat': (userData?['weeklyHasanat'] as int?) ?? 0,
        };
      }

      final batch = db.batch();
      final logRef = userRef.collection('logs').doc();

      batch.set(logRef, {
        'type': 'arapca',
        'method': 'surah',
        'pagesRead': pagesRead,
        'surahId': info.surahId,
        'startPage': info.startPage,
        'endPage': info.endPage,
        'hatimId': null,
        'source': 'vird',
        'createdAt': Timestamp.fromDate(now),
      });

      batch.set(userRef, {
        'hasanat': FieldValue.increment(pagesRead * 10),
        'totalPages': FieldValue.increment(pagesRead),
        ...seriUpdate,
        ...weeklyUpdate,
      }, SetOptions(merge: true));

      // sureLogIds aynı batch'te — log + istatistik + takip ID'si atomik
      batch.set(virdDocRef, {
        'sureLogIds': {item.id: logRef.id},
        'sureLogPages': {item.id: pagesRead},
      }, SetOptions(merge: true));

      await batch.commit();

      if (mounted) {
        _showTopNotification(
          context,
          'Okuma kaydı oluşturuldu — profil istatistiklerinize ve Kuran haritasına eklendi.',
          isError: false,
          duration: const Duration(milliseconds: 3500),
        );
      }

      // Seri hesapla + animasyonu göster
      int newSeri = displayedSeri;
      if (needsSeriRecalculate) {
        await SeriCalculator.recalculate(uid);
        final refreshed = await userRef.get();
        newSeri = (refreshed.data()?['seri'] as int?) ?? 1;
      } else if (seriUpdate.containsKey('seri')) {
        newSeri = seriUpdate['seri'] as int;
      }

      if (newSeri > displayedSeri && mounted) {
        // Root navigator kullan — widget nested navigator içinde olsa bile tam ekran görünür
        final rootCtx = Navigator.of(context, rootNavigator: true).context;
        try {
          final weekData = await _getWeekFilled(uid);
          if (mounted && rootCtx.mounted) {
            await StreakAnimationScreen.show(
              rootCtx,
              count: newSeri,
              prevCount: displayedSeri,
              filled: weekData.filled,
              dayLabels: weekData.labels,
              todayIndex: 6,
            );
          }
        } catch (e) {
          debugPrint('Seri animasyonu gösterilemedi: $e');
        }
      }
    } catch (e) {
      debugPrint('Error creating sure reading log: $e');
    }
  }

  Future<void> _doDeleteSureReadingLog(String virdId) async {
    if (_uid == null) return;

    try {
      final db = FirebaseFirestore.instance;
      final uid = _uid;
      final virdDocRef = db.collection('users').doc(uid).collection('logs').doc(_todayDateStr());

      final virdDoc = await virdDocRef.get();
      if (!virdDoc.exists) return;

      final sureLogIds = (virdDoc.data()?['sureLogIds'] as Map<String, dynamic>?) ?? {};
      final logId = sureLogIds[virdId] as String?;
      if (logId == null) return;

      final sureLogPages = (virdDoc.data()?['sureLogPages'] as Map<String, dynamic>?) ?? {};
      int pagesRead = (sureLogPages[virdId] as int?) ?? 0;

      // Log dokümanından gerçek sayfa sayısını doğrula
      final logDoc = await db.collection('users').doc(uid).collection('logs').doc(logId).get();
      if (logDoc.exists) {
        pagesRead = (logDoc.data()?['pagesRead'] as int?) ?? pagesRead;
      }

      final batch = db.batch();
      final userRef = db.collection('users').doc(uid);

      if (logDoc.exists) {
        batch.delete(logDoc.reference);

        // Stat reversal yalnızca log gerçekten varsa — dışarıdan silinmişse double decrement önlenir
        if (pagesRead > 0) {
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          final weekMonday = today.subtract(Duration(days: today.weekday - 1));
          final weekStartStr = '${weekMonday.year}-${weekMonday.month.toString().padLeft(2, '0')}-${weekMonday.day.toString().padLeft(2, '0')}';
          final userSnap = await userRef.get();
          final existingWeekStr = (userSnap.data())?['weeklyStartDate'] as String?;
          final logCreatedAt = (logDoc.data()?['createdAt'] as Timestamp?)?.toDate();
          final logInThisWeek = logCreatedAt != null && !logCreatedAt.isBefore(weekMonday) && existingWeekStr == weekStartStr;

          final Map<String, dynamic> reversal = {
            'hasanat': FieldValue.increment(-pagesRead * 10),
            'totalPages': FieldValue.increment(-pagesRead),
          };
          if (logInThisWeek) {
            reversal['weeklyHasanat'] = FieldValue.increment(-pagesRead * 10);
          }
          batch.update(userRef, reversal);
        }
      } else {
        debugPrint('Sure log $logId already deleted externally — clearing sureLogIds only');
      }

      // sureLogIds ve sureLogPages her durumda temizle
      // completions.$virdId: 0 da aynı write'a eklenir — batch stream'i tetiklediğinde
      // virdDoc'taki completions güncel kalır, flicker önlenir
      batch.update(virdDocRef, {
        'sureLogIds.$virdId': FieldValue.delete(),
        'sureLogPages.$virdId': FieldValue.delete(),
        'completions.$virdId': 0,
      });

      await batch.commit();

      await SeriCalculator.recalculate(uid);

      if (mounted) {
        _showTopNotification(
          context,
          'Okuma kaydı silindi.',
          isError: false,
          duration: const Duration(milliseconds: 2500),
        );
      }
    } catch (e) {
      debugPrint('Error deleting sure reading log: $e');
    }
  }

  // Seri animasyonu için son 7 günlük doluluk verisi (LogEntryBottomSheet ile aynı)
  static const _dayAbbr = ['Pt', 'Sa', 'Ça', 'Pe', 'Cu', 'Ct', 'Pa'];

  Future<({List<bool> filled, List<String> labels})> _getWeekFilled(String uid) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
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
      ((userSnap.data() as Map<String, dynamic>?)?['frozenDates'] as List<dynamic>?) ?? [],
    );

    final loggedDays = <String>{...frozenDates};
    for (final doc in logsSnap.docs) {
      final docData = doc.data() as Map<String, dynamic>?;
      if (docData == null) continue;
      final type = docData['type'] as String?;
      if (type != 'arapca' && type != 'meal') continue;
      final d = (docData['createdAt'] as Timestamp?)?.toDate().toLocal();
      if (d != null) loggedDays.add(seriDateKey(d));
    }

    final filled = List.generate(7, (i) {
      final day = startDay.add(Duration(days: i));
      return loggedDays.contains(seriDateKey(day));
    });
    final labels = List.generate(7, (i) {
      final day = startDay.add(Duration(days: i));
      return _dayAbbr[day.weekday - 1];
    });

    return (filled: filled, labels: labels);
  }

  void _openZikirmatik(VirdItem item, int current) {
    ZikirmatikModal.show(
      context,
      title: item.title,
      arabicTitle: item.arabicTitle,
      description: item.hadith ?? item.description,
      initialCount: current,
      targetCount: item.targetCount,
      onCountChanged: (newCount) {
        _updateVirdProgress(item.id, newCount);
      },
    );
  }

  Future<void> _showVirdHistoryHeatMap(VirdItem item, Color categoryColor) async {
    if (_uid == null) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: CircularProgressIndicator(color: AppColors.teal),
      ),
    );
    
    try {
      final logsSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .collection('logs')
          .get();
          
      if (mounted) Navigator.pop(context); // Dismiss loading dialog
      
      final Map<String, Map<String, dynamic>> allVirdLogs = {};
      final Set<String> completedDateStrs = {};
      
      for (var doc in logsSnap.docs) {
        if (!doc.id.startsWith('vird_')) continue;
        final data = doc.data();
        final dateKey = doc.id; // "vird_2026-06-01"
        allVirdLogs[dateKey] = data;

        final comps = data['completions'] as Map<String, dynamic>? ?? {};
        final count = (comps[item.id] as num?)?.toInt() ?? 0;
        if (count >= item.targetCount) {
          completedDateStrs.add(dateKey.replaceAll('vird_', ''));
        }
      }
      
      final streak = _calculateVirdStreak(item.id, item.targetCount, allVirdLogs);

      // Başlangıç tarihi hesabı açtığı gün (_userCreatedAt) veya en eski tamamlama tarihidir
      DateTime startDate = _userCreatedAt ?? DateTime.now();
      for (final dateStr in completedDateStrs) {
        try {
          final parts = dateStr.split('-');
          if (parts.length != 3) continue;
          final d = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
          if (d.isBefore(startDate)) startDate = d;
        } catch (_) {}
      }

      final fakeHabit = HabitDef(
        id: item.id,
        title: item.title,
        color: categoryColor,
        createdAt: startDate,
      );
      
      if (!mounted) return;
      
      HabitHeatMapSheet.show(
        context,
        habit: fakeHabit,
        completedDateStrs: completedDateStrs,
        currentStreak: streak,
        createdAt: startDate,
        hadithText: item.hadith ?? (item.description.isNotEmpty ? item.description : null),
      );
    } catch (e) {
      if (mounted) Navigator.pop(context); // Dismiss loading dialog in case of error
      debugPrint("Error loading vird history: $e");
    }
  }
  
  int _calculateVirdStreak(String itemId, int targetCount, Map<String, Map<String, dynamic>> allVirdLogs) {
    int streak = 0;
    final today = DateTime.now();
    for (int i = 0; i < 365; i++) {
      final d = today.subtract(Duration(days: i));
      final dateStr = "vird_${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
      final completions = allVirdLogs[dateStr]?['completions'] as Map<String, dynamic>? ?? {};
      final count = completions[itemId] as int? ?? 0;
      if (count >= targetCount) {
        streak++;
      } else {
        if (i == 0) continue;
        break;
      }
    }
    return streak;
  }


  Widget _buildEmptyStateExploreNotice() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        children: [
          const Text('📿', style: TextStyle(fontSize: 36)),
          const SizedBox(height: 12),
          Text(
            'Aktif Virdiniz Bulunmuyor',
            style: GoogleFonts.nunito(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.textDark),
          ),
          const SizedBox(height: 6),
          Text(
            'Vird Kütüphanesi\'nden dilediğiniz sure, dua ve zikirleri listenize ekleyebilirsiniz.',
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(fontSize: 12.5, color: AppColors.textLight, height: 1.5),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.teal,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              elevation: 0,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const VirdLibraryScreen()),
              );
            },
            icon: const Icon(Icons.explore_outlined, color: Colors.white),
            label: Text(
              'KÜTÜPHANEYİ KEŞFET',
              style: GoogleFonts.nunito(fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _quickToggleVird(String id, bool currentlyAdded) async {
    if (_uid == null) return;
    HapticFeedback.mediumImpact();

    try {
      final item = VirdItem.defaultVirds.cast<VirdItem?>().firstWhere(
        (e) => e?.id == id,
        orElse: () => null,
      );
      if (item == null) return;

      if (currentlyAdded) {
        // Kaldır
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_uid)
            .update({
          'virdPreferences.${item.id}.active': false,
          'virdPreferences.${item.id}.updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Ekle
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_uid)
            .update({
          'virdPreferences.${item.id}': {
            'active': true,
            'category': item.category,
            'targetCount': item.targetCount,
            'isCustom': item.isCustom,
            'updatedAt': FieldValue.serverTimestamp(),
          }
        });
      }

      if (mounted) {
        _showTopNotification(
          context,
          currentlyAdded 
              ? '${item.title} listenizden kaldırıldı.' 
              : '${item.title} listenize eklendi!',
          isError: currentlyAdded,
        );
      }
    } catch (e) {
      debugPrint('Error toggling vird: $e');
    }
  }

  Widget _buildLibraryShowcaseCard(List<VirdItem> activeList) {
    final showcasedVirds = [
      if (_isFriday())
        {'id': 'kehf', 'title': 'Kehf', 'arabic': 'الكهف', 'category': 'sure', 'isSpecial': 'true'},
      {'id': 'yasin', 'title': 'Yâsîn', 'arabic': 'يس', 'category': 'sure'},
      {'id': 'fetih', 'title': 'Fetih', 'arabic': 'الفتح', 'category': 'sure'},
      {'id': 'mulk', 'title': 'Mülk', 'arabic': 'الملك', 'category': 'sure'},
      {'id': 'vakia', 'title': 'Vâkıa', 'arabic': 'الواقعة', 'category': 'sure'},
      {'id': 'nebe', 'title': 'Nebe', 'arabic': 'النبأ', 'category': 'sure'},
      {'id': 'salavat', 'title': 'Salavat', 'arabic': 'صلوات', 'category': 'zikir'},
      {'id': 'istigfar', 'title': 'İstiğfar', 'arabic': 'استغفار', 'category': 'zikir'},
    ];

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderGrey),
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'VİRD KÜTÜPHANESİ',
                style: GoogleFonts.nunito(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: AppColors.teal,
                  letterSpacing: 1.2,
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const VirdLibraryScreen()),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Tümünü Gör',
                      style: GoogleFonts.nunito(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMid,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 10, color: AppColors.textMid),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 76,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: showcasedVirds.length + 1,
              itemBuilder: (context, idx) {
                if (idx == showcasedVirds.length) {
                  return GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const VirdLibraryScreen()),
                    ),
                    child: SizedBox(
                      width: 54,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: AppColors.lightGrey,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.borderGrey, width: 1.5),
                            ),
                            child: const Icon(Icons.more_horiz_rounded, color: AppColors.teal, size: 20),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tümü',
                            style: GoogleFonts.nunito(fontSize: 9, fontWeight: FontWeight.w600, color: AppColors.textMid),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final vird = showcasedVirds[idx];
                final id = vird['id']!;
                final isAdded = activeList.any((e) => e.id == id);
                final isSpecial = vird['isSpecial'] == 'true';
                final category = vird['category'] ?? 'sure';

                final Color circleColor;
                switch (category) {
                  case 'zikir':
                    circleColor = AppColors.orange;
                    break;
                  case 'dua':
                    circleColor = AppColors.infoBlue;
                    break;
                  default:
                    circleColor = AppColors.teal;
                }

                return GestureDetector(
                  onTap: () => _quickToggleVird(id, isAdded),
                  child: Container(
                    width: 54,
                    margin: const EdgeInsets.only(right: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isAdded
                                    ? AppColors.successGreen.withValues(alpha: 0.1)
                                    : circleColor.withValues(alpha: 0.08),
                                border: Border.all(
                                  color: isAdded
                                      ? AppColors.successGreen
                                      : isSpecial
                                          ? AppColors.gold
                                          : circleColor.withValues(alpha: 0.4),
                                  width: isAdded || isSpecial ? 2.0 : 1.5,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  vird['arabic']!,
                                  style: GoogleFonts.amiri(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: isAdded ? AppColors.successGreen : circleColor,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: isAdded ? AppColors.successGreen : circleColor,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 1.5),
                                ),
                                child: Icon(
                                  isAdded ? Icons.check_rounded : Icons.add_rounded,
                                  color: Colors.white,
                                  size: 9,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isSpecial ? '🕌 ${vird['title']!}' : vird['title']!,
                          style: GoogleFonts.nunito(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: isSpecial ? const Color(0xFFB8860B) : AppColors.textDark,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

}

class VirdlerimScreen extends StatelessWidget {
  const VirdlerimScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textDark, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Günlük Virdlerim',
          style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textDark),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded, color: AppColors.teal, size: 24),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const VirdLibraryScreen()),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: const VirdlerimContentWidget(),
    );
  }
}


class StreamZip {
  final List<Stream<dynamic>> streams;
  StreamZip(this.streams);

  Stream<List<dynamic>> get stream {
    StreamController<List<dynamic>>? controller;
    List<StreamSubscription<dynamic>>? subs;

    controller = StreamController<List<dynamic>>(
      onListen: () {
        final values = List<dynamic>.filled(streams.length, null, growable: false);
        final hasVal = List<bool>.filled(streams.length, false, growable: false);

        subs = streams.asMap().entries.map((e) {
          return e.value.listen(
            (data) {
              values[e.key] = data;
              hasVal[e.key] = true;

              if (hasVal.every((b) => b)) {
                controller?.add(List<dynamic>.from(values));
              }
            },
            onError: controller?.addError,
            onDone: () {
              controller?.close();
            },
          );
        }).toList();
      },
      onCancel: () {
        if (subs != null) {
          for (var s in subs!) {
            s.cancel();
          }
        }
      },
    );

    return controller.stream;
  }
}

void _showTopNotification(BuildContext context, String message, {required bool isError, Duration duration = const Duration(milliseconds: 1800)}) {
  final overlay = Overlay.of(context);
  late OverlayEntry entry;

  entry = OverlayEntry(
    builder: (context) => _TopNotificationOverlay(
      message: message,
      isError: isError,
      duration: duration,
      onDismiss: () => entry.remove(),
    ),
  );

  overlay.insert(entry);
}

class _TopNotificationOverlay extends StatefulWidget {
  final String message;
  final bool isError;
  final Duration duration;
  final VoidCallback onDismiss;

  const _TopNotificationOverlay({
    required this.message,
    required this.isError,
    required this.onDismiss,
    this.duration = const Duration(milliseconds: 1800),
  });

  @override
  State<_TopNotificationOverlay> createState() => _TopNotificationOverlayState();
}

class _TopNotificationOverlayState extends State<_TopNotificationOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _yAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _yAnim = Tween<double>(begin: -80.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _controller.forward();

    Future.delayed(widget.duration, () async {
      if (mounted) {
        await _controller.reverse();
        widget.onDismiss();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color bgColor = widget.isError ? const Color(0xFFFDE8E8) : const Color(0xFFE0F2F1);
    final Color textColor = widget.isError ? const Color(0xFFC81E1E) : const Color(0xFF00695C);
    final IconData icon = widget.isError ? Icons.info_outline_rounded : Icons.check_circle_outline_rounded;

    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.only(top: 16),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, _yAnim.value),
                child: Opacity(
                  opacity: _fadeAnim.value,
                  child: child,
                ),
              );
            },
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                margin: const EdgeInsets.symmetric(horizontal: 24),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: textColor.withValues(alpha: 0.15), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: textColor, size: 18),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        widget.message,
                        style: GoogleFonts.nunito(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
