import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../app_colors.dart';
import '../models/vird_model.dart';
import 'vird_library_screen.dart';
import '../widgets/zikirmatik_modal.dart';
import '../widgets/habit_tracker_widget.dart';
import '../widgets/habit_heat_map_sheet.dart';

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
  StreamSubscription? _prefsSub;
  StreamSubscription? _logSub;

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
      
      final List<VirdItem> allVirds = VirdItem.defaultVirds.map((e) => e.copyWith()).toList();
      final userData = userSnap.data() ?? {};
      final prefsMap = userData['virdPreferences'] as Map<String, dynamic>? ?? {};

      prefsMap.forEach((id, val) {
        final map = Map<String, dynamic>.from(val as Map);
        final isCustom = map['isCustom'] ?? false;

        if (isCustom) {
          allVirds.add(VirdItem.fromMap({...map, 'id': id}));
        } else {
          final idx = allVirds.indexWhere((e) => e.id == id);
          if (idx != -1) {
            allVirds[idx] = VirdItem.fromMap({
              ...allVirds[idx].toMap(),
              ...map,
            });
          }
        }
      });

      // Sadece aktif virdleri filtrele
      final activeVirds = allVirds.where((e) => e.active).toList();

      // Cuma günü değilse Kehf suresini listeden gizle (Cuma'ya özel virdleri sakla)
      if (!_isFriday()) {
        activeVirds.removeWhere((e) => e.id == 'kehf');
      }

      // Kullanıcı özel kategori sıralaması
      final orderRaw = userData['virdOrder'] as Map<String, dynamic>? ?? {};
      final Map<String, List<String>> parsedOrder = {};
      orderRaw.forEach((k, v) {
        if (v is List) parsedOrder[k] = v.map((e) => e.toString()).toList();
      });

      setState(() {
        _activeVirds = activeVirds;
        _virdOrder = parsedOrder;
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

  // Cuma günü kontrolü
  bool _isFriday() {
    return DateTime.now().weekday == DateTime.friday;
  }

  Future<void> _updateVirdProgress(String virdId, int newCount) async {
    if (_uid == null) return;
    
    // Optimistic Update for 7-dot tracker
    final dateKey = _todayDateStr();
    setState(() {
      if (_selectedWeekLogs[dateKey] == null) {
        _selectedWeekLogs[dateKey] = {};
      }
      _selectedWeekLogs[dateKey]![virdId] = newCount;
      
      // Update local _currentLog as well for immediate UI response
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

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) {
          transaction.set(docRef, {
            'type': 'vird',
            'date': dateKey,
            'completions': {virdId: newCount},
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          final data = snapshot.data() ?? {};
          final completions = Map<String, dynamic>.from(data['completions'] ?? {});
          completions[virdId] = newCount;
          transaction.update(docRef, {
            'completions': completions,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      });
    } catch (e) {
      debugPrint('Error saving progress: $e');
    }
  }

  void _showHadithDialog(VirdItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.star_rounded, color: AppColors.gold, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Fazileti & Önemi',
                style: GoogleFonts.nunito(fontWeight: FontWeight.bold, color: AppColors.textDark, fontSize: 16),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.title,
              style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.teal),
            ),
            const SizedBox(height: 8),
            Text(
              item.hadith ?? item.description,
              style: GoogleFonts.nunito(fontSize: 14, color: AppColors.textDark, height: 1.5, fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Kapat', style: GoogleFonts.nunito(color: AppColors.teal, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
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

    final activeVirds = _activeVirds;
    final log = _currentLog ?? VirdLog(date: _todayDateStr(), completions: {});

    if (activeVirds.isEmpty) {
      return Material(
        color: Colors.white,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          children: [
            _buildProgressCard(0, 0, 0.0, VirdLog(date: _todayDateStr(), completions: {})),
            const SizedBox(height: 16),
            _buildLibraryShowcaseCard(const []),
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
            padding: const EdgeInsets.only(top: 20, bottom: 6, left: 4),
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
                builder: (context, _) {
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
          const SizedBox(height: 16),
          _buildProgressCard(completed.length, activeVirds.length, totalProgress, log),
          const SizedBox(height: 16),
          _buildDateSelector(),
          const SizedBox(height: 16),

          if (_isFriday()) _buildFridayBanner(),

          buildCategoryGroup('SURELER', AppColors.teal, sures, 'sure'),
          buildCategoryGroup('ZİKİRLER', AppColors.orange, zikirs, 'zikir'),
          buildCategoryGroup('DUALAR', AppColors.infoBlue, duas, 'dua'),
          buildCategoryGroup('DİĞER', AppColors.textMid, others, 'other'),
          const SizedBox(height: 48),
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
                CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 6,
                  backgroundColor: AppColors.lightGrey,
                  color: progress == 1.0 ? AppColors.successGreen : AppColors.gold,
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
                      : (progress == 1.0 ? 'Harika! Hepsini tamamladın 🎉' : 'Günlük Rutinim'),
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
                Text(
                  '"Az da olsa devamlı olanıdır." (Müslim, Müsâfirîn 215)',
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
    final progress = item.targetCount > 0 ? (currentCount / item.targetCount).clamp(0.0, 1.0) : 0.0;

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
      if (dClean.isAfter(todayClean)) {
        dotColor = Colors.transparent;
      } else if (count >= item.targetCount) {
        dotColor = const Color(0xFF52B788); // Yeşil (Tamamlandı)
      } else if (count > 0) {
        dotColor = categoryColor.withValues(alpha: 0.6); // İlerleme var
      } else {
        if (dClean == todayClean) {
          dotColor = AppColors.borderGrey.withValues(alpha: 0.6);
        } else {
          dotColor = const Color(0xFFF28482).withValues(alpha: 0.7);
        }
      }
      
      dotWidgets.add(
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 1.5),
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: dotColor,
            shape: BoxShape.circle,
            border: isSelectedDay
                ? Border.all(color: AppColors.textDark.withValues(alpha: 0.45), width: 1.2)
                : (dClean.isAfter(todayClean)
                    ? Border.all(color: AppColors.borderGrey, width: 1.0)
                    : null),
          ),
        ),
      );
    }

    return Container(
      key: key,
      margin: const EdgeInsets.symmetric(vertical: 3),
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: isDone ? categoryColor.withValues(alpha: 0.1) : AppColors.white,
        border: Border.all(
          color: isDone
              ? categoryColor.withValues(alpha: 0.5)
              : AppColors.borderGrey,
          width: isDone ? 1.5 : 1.0,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
        onTap: () => _showVirdHistoryHeatMap(item, categoryColor),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          child: Row(
            children: [
              // Sol Kategori İkonu
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isDone 
                      ? categoryColor.withValues(alpha: 0.05)
                      : categoryColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  categoryIcon,
                  color: isDone ? categoryColor.withValues(alpha: 0.45) : categoryColor,
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
                        color: isDone ? AppColors.textLight : AppColors.textDark,
                        decoration: isDone ? TextDecoration.lineThrough : null,
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
              
              // Sağ Aksiyon Butonu
              if (isZikir) ...[
                if (isDone)
                  _buildDoneIndicator()
                else
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _updateVirdProgress(item.id, currentCount + 1);
                    },
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 32,
                          height: 32,
                          child: CircularProgressIndicator(
                            value: progress,
                            strokeWidth: 2.5,
                            backgroundColor: AppColors.borderGrey,
                            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.orange),
                          ),
                        ),
                        const Icon(Icons.add_rounded, color: AppColors.orange, size: 18),
                      ],
                    ),
                  ),
              ] else ...[
                GestureDetector(
                  onTap: () => _toggleSureDua(item, currentCount),
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDone ? categoryColor : Colors.white,
                      border: Border.all(
                        color: isDone ? categoryColor : AppColors.borderGrey,
                        width: 1.8,
                      ),
                    ),
                    child: isDone
                        ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
                        : null,
                  ),
                ),
              ],
              const SizedBox(width: 4),

              // Seçenekler Menüsü (Üç Nokta)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: AppColors.textLight, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onSelected: (value) {
                  if (value == 'hadith') _showHadithDialog(item);
                  if (value == 'calendar') _showVirdHistoryHeatMap(item, categoryColor);
                  if (value == 'zikirmatik') _openZikirmatik(item, currentCount);
                },
                itemBuilder: (_) => [
                  if (item.hadith != null || item.description.isNotEmpty)
                    PopupMenuItem(
                      value: 'hadith',
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.textMid),
                          const SizedBox(width: 10),
                          Text('Fazileti & Önemi', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  PopupMenuItem(
                    value: 'calendar',
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_month_rounded, size: 18, color: AppColors.textMid),
                        const SizedBox(width: 10),
                        Text('Detaylı Takvim', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  if (isZikir)
                    PopupMenuItem(
                      value: 'zikirmatik',
                      child: Row(
                        children: [
                          const Icon(Icons.touch_app_rounded, size: 18, color: AppColors.orange),
                          const SizedBox(width: 10),
                          Text('Zikirmatik Aç', style: GoogleFonts.nunito(fontWeight: FontWeight.w700, color: AppColors.orange)),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }

  Widget _buildDoneIndicator() {
    return Container(
      width: 24,
      height: 24,
      decoration: const BoxDecoration(
        color: AppColors.successGreen,
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.check_rounded, color: Colors.white, size: 14),
    );
  }

  void _toggleSureDua(VirdItem item, int current) {
    HapticFeedback.mediumImpact();
    final newCount = current >= item.targetCount ? 0 : item.targetCount;
    _updateVirdProgress(item.id, newCount);
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
          .where('type', isEqualTo: 'vird')
          .get();
          
      if (mounted) Navigator.pop(context); // Dismiss loading dialog
      
      final Map<String, Map<String, dynamic>> allVirdLogs = {};
      final Set<String> completedDateStrs = {};
      
      for (var doc in logsSnap.docs) {
        final data = doc.data();
        final dateKey = data['date'] as String; // e.g. "vird_2026-06-01"
        allVirdLogs[dateKey] = data;
        
        final comps = data['completions'] as Map<String, dynamic>? ?? {};
        final count = comps[item.id] as int? ?? 0;
        if (count >= item.targetCount) {
          completedDateStrs.add(dateKey.replaceAll('vird_', ''));
        }
      }
      
      final streak = _calculateVirdStreak(item.id, item.targetCount, allVirdLogs);
      
      final startRecent = DateTime.now().subtract(const Duration(days: 30));

      final fakeHabit = HabitDef(
        id: item.id,
        title: item.title,
        color: categoryColor,
        createdAt: startRecent,
      );
      
      if (!mounted) return;
      
      HabitHeatMapSheet.show(
        context,
        habit: fakeHabit,
        completedDateStrs: completedDateStrs,
        currentStreak: streak,
        createdAt: startRecent,
      );
    } catch (e) {
      if (mounted) Navigator.pop(context); // Dismiss loading dialog in case of error
      debugPrint("Error loading vird history: $e");
    }
  }
  
  int _calculateVirdStreak(String itemId, int targetCount, Map<String, Map<String, dynamic>> allVirdLogs) {
    int streak = 0;
    final today = DateTime.now();
    for (int i = 0; i < 30; i++) {
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
            style: GoogleFonts.nunito(fontSize: 15.5, fontWeight: FontWeight.bold, color: AppColors.textDark),
          ),
          const SizedBox(height: 6),
          Text(
            'Yukarıdaki kütüphaneden veya "Kütüphaneyi Keşfet" kartından dilediğiniz sure, dua ve zikirleri listenize ekleyebilirsiniz.',
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
      final item = VirdItem.defaultVirds.firstWhere((e) => e.id == id);
      
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
            'title': item.title,
            'arabicTitle': item.arabicTitle,
            'description': item.description,
            'recommendedTime': item.recommendedTime,
            'hadith': item.hadith,
            'isCustom': item.isCustom,
            'updatedAt': FieldValue.serverTimestamp(),
          }
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(currentlyAdded 
                ? '${item.title} listenizden kaldırıldı.' 
                : '${item.title} listenize eklendi!'),
            backgroundColor: currentlyAdded ? AppColors.errorRed : AppColors.teal,
            duration: const Duration(milliseconds: 1500),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error toggling vird: $e');
    }
  }

  Widget _buildLibraryShowcaseCard(List<VirdItem> activeList) {
    final isFridayToday = _isFriday();
    final showcasedVirds = [
      if (isFridayToday)
        {'id': 'kehf', 'title': 'Kehf Suresi', 'arabic': 'سورة الكهف', 'isSpecial': 'true'},
      {'id': 'yasin', 'title': 'Yâsîn', 'arabic': 'سورة يس'},
      {'id': 'fetih', 'title': 'Fetih', 'arabic': 'سورة الفتح'},
      {'id': 'mulk', 'title': 'Mülk', 'arabic': 'سورة الملك'},
      {'id': 'vakia', 'title': 'Vâkıa', 'arabic': 'سورة الواقعة'},
      {'id': 'nebe', 'title': 'Nebe', 'arabic': 'سورة النبأ'},
      {'id': 'ayetel_kursi', 'title': 'Ayetel Kürsi', 'arabic': 'آية الكرسي'},
      {'id': 'salavat', 'title': 'Salavat', 'arabic': 'صلوات'},
      {'id': 'istigfar', 'title': 'İstiğfar', 'arabic': 'استغfar'},
    ];

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderGrey),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'VİRD KÜTÜPHANESİ',
                    style: GoogleFonts.nunito(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.teal,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Kütüphaneyi Keşfet',
                    style: GoogleFonts.nunito(
                      fontSize: 14.0,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const VirdLibraryScreen()),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.lightGrey,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: AppColors.textDark,
                    size: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Günlük rutininize ekleyebileceğiniz sure, dua ve zikirler kütüphanesini inceleyin.',
            style: GoogleFonts.nunito(
              fontSize: 11.0,
              color: AppColors.textMid,
              fontWeight: FontWeight.w500,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 90,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final availableWidth = constraints.maxWidth;
                final double visibleItems = 4.12;
                final double spacing = 8.0;
                final double itemWidth = (availableWidth - (visibleItems - 1) * spacing) / visibleItems;

                return ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  itemCount: showcasedVirds.length + 1,
                  itemBuilder: (context, idx) {
                    if (idx == showcasedVirds.length) {
                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const VirdLibraryScreen()),
                          );
                        },
                        child: Container(
                          width: 44,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: AppColors.lightGrey,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.borderGrey, width: 1.2),
                          ),
                          child: const Icon(
                            Icons.arrow_forward_rounded,
                            color: AppColors.teal,
                            size: 20,
                          ),
                        ),
                      );
                    }

                    final vird = showcasedVirds[idx];
                    final id = vird['id']!;
                    final isAdded = activeList.any((e) => e.id == id);
                    final isSpecial = vird['isSpecial'] == 'true';
                    final isHighlight = isSpecial && !isAdded;

                    Color itemBgColor;
                    Color itemBorderColor;
                    double itemBorderWidth = 1.2;

                    if (isHighlight) {
                      itemBgColor = const Color(0xFFFDF0D5); // Soft gold
                      itemBorderColor = AppColors.gold.withValues(alpha: 0.6);
                      itemBorderWidth = 1.6;
                    } else if (isAdded) {
                      itemBgColor = const Color(0xFFE8F5E9); // Soft success green
                      itemBorderColor = AppColors.successGreen.withValues(alpha: 0.5);
                    } else {
                      itemBgColor = AppColors.lightGrey.withValues(alpha: 0.7);
                      itemBorderColor = AppColors.borderGrey.withValues(alpha: 0.8);
                    }

                    return GestureDetector(
                      onTap: () => _quickToggleVird(id, isAdded),
                      child: Container(
                        width: itemWidth,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: itemBgColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: itemBorderColor,
                            width: itemBorderWidth,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (isSpecial) ...[
                              Text(
                                '🕌 CUMA ÖZEL',
                                style: GoogleFonts.nunito(
                                  fontSize: 6.5,
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFFD4A373),
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 1),
                            ],
                            Text(
                              vird['title']!,
                              style: GoogleFonts.nunito(
                                fontSize: isSpecial ? 10.5 : 11.0,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textDark,
                              ),
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              vird['arabic']!,
                              style: GoogleFonts.amiri(
                                fontSize: 9.0,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textMid,
                              ),
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Container(
                              padding: const EdgeInsets.all(2.5),
                              decoration: BoxDecoration(
                                color: isAdded ? AppColors.successGreen : AppColors.teal.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isAdded ? Icons.check_rounded : Icons.add_rounded,
                                color: isAdded ? Colors.white : AppColors.teal,
                                size: 8.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
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
