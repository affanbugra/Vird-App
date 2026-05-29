import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../app_colors.dart';
import '../models/vird_model.dart';
import 'vird_library_screen.dart';
import '../widgets/zikirmatik_modal.dart';

class VirdlerimScreen extends StatefulWidget {
  const VirdlerimScreen({super.key});

  @override
  State<VirdlerimScreen> createState() => _VirdlerimScreenState();
}

class _VirdlerimScreenState extends State<VirdlerimScreen> {
  final _uid = FirebaseAuth.instance.currentUser?.uid;
  bool _showCompletedSures = false;
  bool _showCompletedZikirs = false;
  bool _showCompletedDuas = false;
  bool _showCompletedOthers = false;
  final Map<String, double> _weeklyStatus = {};
  int _currentWeekOffset = 0;
  static const int _kCurrentWeekPage = 500;
  late final PageController _weekPageController;

  late Stream<Map<String, dynamic>> _combinedStream;

  @override
  void initState() {
    super.initState();
    _weekPageController = PageController(initialPage: _kCurrentWeekPage);
    _combinedStream = _getCombinedStream();
    _fetchWeekData(0);
  }

  @override
  void dispose() {
    _weekPageController.dispose();
    super.dispose();
  }

  Future<void> _fetchWeekData(int weekOffset) async {
    if (_uid == null) return;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final currentMonday = today.subtract(Duration(days: now.weekday - 1));
    final monday = currentMonday.add(Duration(days: 7 * weekOffset));

    final userDoc = await FirebaseFirestore.instance.collection('users').doc(_uid).get();
    final prefsMap = (userDoc.data()?['virdPreferences'] as Map<String, dynamic>?) ?? {};
    final allVirds = VirdItem.defaultVirds.map((e) => e.copyWith()).toList();
    prefsMap.forEach((id, val) {
      final map = Map<String, dynamic>.from(val as Map);
      if (map['isCustom'] == true) {
        allVirds.add(VirdItem.fromMap({...map, 'id': id}));
      } else {
        final idx = allVirds.indexWhere((e) => e.id == id);
        if (idx != -1) allVirds[idx] = VirdItem.fromMap({...allVirds[idx].toMap(), ...map});
      }
    });
    final activeVirds = allVirds.where((e) => e.active).toList();

    // Geçmiş haftalar için 7 gün, bu hafta için bugüne kadar olan günler
    final daysToFetch = weekOffset == 0 ? (now.weekday - 1) : 7;
    final updates = <String, double>{};
    for (int i = 0; i < daysToFetch; i++) {
      final d = monday.add(Duration(days: i));
      final key = "vird_${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
      if (_weeklyStatus.containsKey(key)) continue;
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users').doc(_uid)
            .collection('logs').doc(key).get();
        if (!doc.exists || activeVirds.isEmpty) {
          updates[key] = 0.0;
        } else {
          final log = VirdLog.fromDoc(doc);
          double total = 0.0;
          for (final v in activeVirds) {
            total += ((log.completions[v.id] ?? 0) / v.targetCount).clamp(0.0, 1.0);
          }
          updates[key] = total / activeVirds.length;
        }
      } catch (_) {
        updates[key] = 0.0;
      }
    }
    if (mounted && updates.isNotEmpty) setState(() => _weeklyStatus.addAll(updates));
  }

  String _todayDateStr() {
    final now = DateTime.now();
    return "vird_${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
  }

  // Cuma günü kontrolü
  bool _isFriday() {
    return DateTime.now().weekday == DateTime.friday;
  }

  // Kullanıcı tercihlerini ve bugünün logunu birleştirip listeyi döner
  Stream<Map<String, dynamic>> _getCombinedStream() {
    if (_uid == null) {
      return Stream.value({'virds': <VirdItem>[], 'log': VirdLog(date: _todayDateStr(), completions: {})});
    }

    final prefsStream = FirebaseFirestore.instance
        .collection('users')
        .doc(_uid)
        .snapshots();

    final logStream = FirebaseFirestore.instance
        .collection('users')
        .doc(_uid)
        .collection('logs')
        .doc(_todayDateStr())
        .snapshots();

    return StreamZip([prefsStream, logStream]).stream.map((results) {
      final userSnap = results[0] as DocumentSnapshot<Map<String, dynamic>>;
      final logSnap = results[1] as DocumentSnapshot<Map<String, dynamic>>;

      // 1. Kütüphaneden başla
      final List<VirdItem> allVirds = VirdItem.defaultVirds.map((e) => e.copyWith()).toList();

      // 2. Tercihleri uygula (Custom ekle / Default üzerine yaz)
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

      // 3. Günün log verisini çek
      final log = VirdLog.fromDoc(logSnap);

      return {
        'virds': activeVirds,
        'log': log,
      };
    });
  }

  Future<void> _updateVirdProgress(String virdId, int newCount) async {
    if (_uid == null) return;
    try {
      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .collection('logs')
          .doc(_todayDateStr());

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) {
          transaction.set(docRef, {
            'type': 'vird',
            'date': _todayDateStr(),
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
      body: StreamBuilder<Map<String, dynamic>>(
        stream: _combinedStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.teal));
          }
          if (!snapshot.hasData) {
            return _buildEmptyState();
          }

          final activeVirds = snapshot.data!['virds'] as List<VirdItem>;
          final log = snapshot.data!['log'] as VirdLog;

          if (activeVirds.isEmpty) {
            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildProgressCard(0, 0, 0.0, VirdLog(date: _todayDateStr(), completions: {})),
                const SizedBox(height: 16),
                _buildLibraryShowcaseCard(const []),
                const SizedBox(height: 24),
                _buildEmptyStateExploreNotice(),
                const SizedBox(height: 48),
              ],
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

          // Helper function to build a categorized box with dynamic inline finished list and badge counter
          Widget buildCategoryGroup(
            String title,
            Color color,
            List<VirdItem> allItems,
            bool isExpanded,
            ValueSetter<bool> onToggle,
          ) {
            if (allItems.isEmpty) return const SizedBox.shrink();

            final List<VirdItem> todo = [];
            final List<VirdItem> done = [];

            for (final item in allItems) {
              final count = log.completions[item.id] ?? 0;
              if (count >= item.targetCount) {
                done.add(item);
              } else {
                todo.add(item);
              }
            }

            final total = allItems.length;
            final completedCount = done.length;

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
                
                // Yapılacaklar (todo) listesi
                if (todo.isNotEmpty)
                  ...todo.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final item = entry.value;
                    // Eğer tamamlanan listesi boşsa veya kapalıysa, son todo elemanı alt çizgi çizmemeli
                    final isLast = idx == todo.length - 1 && (done.isEmpty || !isExpanded);
                    return _buildVirdCard(item, log.completions[item.id] ?? 0, isLast: isLast);
                  }),
                  
                // Tamamlananlar (done) varsa göster/gizle butonu
                if (done.isNotEmpty) ...[
                  GestureDetector(
                    onTap: () => onToggle(!isExpanded),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                      color: Colors.transparent,
                      child: Row(
                        children: [
                          Icon(
                            isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                            color: AppColors.successGreen,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Tamamlananlar (${done.length})',
                            style: GoogleFonts.nunito(
                              fontSize: 10.5,
                              color: AppColors.successGreen,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (isExpanded)
                    ...done.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final item = entry.value;
                      final isLast = idx == done.length - 1;
                      return _buildVirdCard(item, log.completions[item.id] ?? 0, isDone: true, isLast: isLast);
                    }),
                ],
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

          suresAll.sort((a, b) => getTimeSortOrder(a).compareTo(getTimeSortOrder(b)));
          zikirsAll.sort((a, b) => getTimeSortOrder(a).compareTo(getTimeSortOrder(b)));
          duasAll.sort((a, b) => getTimeSortOrder(a).compareTo(getTimeSortOrder(b)));
          othersAll.sort((a, b) => getTimeSortOrder(a).compareTo(getTimeSortOrder(b)));

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _buildLibraryShowcaseCard(activeVirds),
              const SizedBox(height: 16),
              _buildProgressCard(completed.length, activeVirds.length, totalProgress, log),
              const SizedBox(height: 16),

              if (_isFriday()) _buildFridayBanner(),

              buildCategoryGroup(
                'SURELER',
                AppColors.teal,
                suresAll,
                _showCompletedSures,
                (val) => setState(() => _showCompletedSures = val),
              ),

              buildCategoryGroup(
                'ZİKİRLER',
                AppColors.orange,
                zikirsAll,
                _showCompletedZikirs,
                (val) => setState(() => _showCompletedZikirs = val),
              ),

              buildCategoryGroup(
                'DUALAR',
                AppColors.infoBlue,
                duasAll,
                _showCompletedDuas,
                (val) => setState(() => _showCompletedDuas = val),
              ),

              buildCategoryGroup(
                'DİĞER',
                AppColors.textMid,
                othersAll,
                _showCompletedOthers,
                (val) => setState(() => _showCompletedOthers = val),
              ),
              const SizedBox(height: 48),
            ],
          );
        },
      ),
    );
  }

  Widget _buildProgressCard(int done, int total, double progress, VirdLog todayLog) {
    final now = DateTime.now();
    final months = ['Ocak','Şubat','Mart','Nisan','Mayıs','Haziran',
                    'Temmuz','Ağustos','Eylül','Ekim','Kasım','Aralık'];
    final dateLabel = '${now.day} ${months[now.month - 1]} ${now.year}';
    final todayKey = _todayDateStr();

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2A7F8C), Color(0xFF1E6370)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.tealDark.withValues(alpha: 0.22),
            offset: const Offset(0, 6),
            blurRadius: 14,
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Başlık + Tarih
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'GÜNLÜK RUTİNİM',
                style: GoogleFonts.nunito(
                  fontSize: 10, fontWeight: FontWeight.w800,
                  color: AppColors.goldSoft, letterSpacing: 1.5,
                ),
              ),
              Text(
                dateLabel,
                style: GoogleFonts.nunito(
                  fontSize: 11, color: Colors.white54, fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // İlerleme satırı
          Row(
            children: [
              Text(
                '$done / $total',
                style: GoogleFonts.outfit(
                  fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'tamamlandı',
                style: GoogleFonts.nunito(
                  fontSize: 11, color: Colors.white60, fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Text(
                '${(progress * 100).toInt()}%',
                style: GoogleFonts.outfit(
                  fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white70,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation<Color>(
                progress >= 1.0 ? AppColors.successGreen : AppColors.gold,
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Hadis
          Text(
            '"Az da olsa devamlı olanıdır." (Müslim, Müsâfirîn 215)',
            style: GoogleFonts.nunito(
              fontSize: 11, color: Colors.white54,
              fontStyle: FontStyle.italic, height: 1.4,
            ),
          ),
          const SizedBox(height: 12),

          // Ayırıcı
          Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 10),

          // Haftalık takip — kaydırılabilir
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _currentWeekOffset == 0
                    ? 'Bu Hafta'
                    : _currentWeekOffset == -1
                        ? 'Geçen Hafta'
                        : _weekRangeLabel(_currentWeekOffset),
                style: GoogleFonts.nunito(
                  fontSize: 10, color: Colors.white54, fontWeight: FontWeight.w600,
                ),
              ),
              if (_currentWeekOffset < 0)
                GestureDetector(
                  onTap: () => _weekPageController.animateToPage(
                    _kCurrentWeekPage,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  ),
                  child: Text(
                    'Bugün →',
                    style: GoogleFonts.nunito(
                      fontSize: 10, color: AppColors.gold, fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRect(
            child: SizedBox(
              height: 52,
              child: PageView.builder(
                controller: _weekPageController,
                itemCount: _kCurrentWeekPage + 1,
                onPageChanged: (page) {
                  final offset = page - _kCurrentWeekPage;
                  setState(() => _currentWeekOffset = offset);
                  _fetchWeekData(offset);
                },
                itemBuilder: (context, page) {
                  final offset = page - _kCurrentWeekPage;
                  return _buildWeekRow(offset, progress, todayKey);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _weekRangeLabel(int weekOffset) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final currentMonday = today.subtract(Duration(days: now.weekday - 1));
    final wMonday = currentMonday.add(Duration(days: 7 * weekOffset));
    final wSunday = wMonday.add(const Duration(days: 6));
    const months = ['Oca','Şub','Mar','Nis','May','Haz','Tem','Ağu','Eyl','Eki','Kas','Ara'];
    return '${wMonday.day} ${months[wMonday.month-1]} – ${wSunday.day} ${months[wSunday.month-1]}';
  }

  Widget _buildWeekRow(int weekOffset, double todayProgress, String todayKey) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final currentMonday = today.subtract(Duration(days: now.weekday - 1));
    final monday = currentMonday.add(Duration(days: 7 * weekOffset));
    const dayNames = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (i) {
        final d = monday.add(Duration(days: i));
        final key = "vird_${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}";
        final isToday = key == todayKey;
        final isFuture = d.isAfter(today);
        final ratio = isToday ? todayProgress : (isFuture ? 0.0 : (_weeklyStatus[key] ?? 0.0));

        return Column(
          children: [
            Text(
              dayNames[i],
              style: GoogleFonts.nunito(
                fontSize: 9,
                color: isToday ? Colors.white : Colors.white38,
                fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: 28, height: 28,
              child: Stack(
                children: [
                  CustomPaint(
                    size: const Size(28, 28),
                    painter: _PieCirclePainter(
                      ratio: isFuture ? 0.0 : ratio.clamp(0.0, 1.0),
                      fillColor: AppColors.gold.withValues(alpha: 0.8),
                      borderColor: isFuture || ratio == 0
                          ? Colors.white24
                          : AppColors.gold.withValues(alpha: 0.8),
                    ),
                  ),
                  if (!isFuture && ratio > 0)
                    Center(
                      child: Text(
                        ratio >= 1.0 ? '100' : '${(ratio * 100).toInt()}',
                        style: GoogleFonts.outfit(
                          fontSize: 7.5,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      }),
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

  Widget _buildVirdCard(VirdItem item, int currentCount, {bool isDone = false, bool isLast = false}) {
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
        categoryIcon = Icons.bookmark_added_rounded;
        categoryColor = AppColors.infoBlue;
        break;
      default:
        categoryIcon = Icons.bookmark_rounded;
        categoryColor = AppColors.textMid;
    }

    return Container(
      decoration: BoxDecoration(
        border: isLast ? null : Border(
          bottom: BorderSide(
            color: AppColors.borderGrey.withValues(alpha: 0.5),
            width: 1.0,
          ),
        ),
      ),
      child: InkWell(
        onTap: () {
          if (isZikir) {
            _openZikirmatik(item, currentCount);
          } else {
            _toggleSureDua(item, currentCount);
          }
        },
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
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            item.title,
                            style: GoogleFonts.nunito(
                              fontSize: 14.0,
                              fontWeight: FontWeight.w700,
                              color: isDone ? AppColors.textLight : AppColors.textDark,
                              decoration: isDone ? TextDecoration.lineThrough : null,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (item.hadith != null) ...[
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () => _showHadithDialog(item),
                            child: const Icon(Icons.info_outline_rounded, size: 14, color: AppColors.textLight),
                          ),
                        ],
                      ],
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
                      color: isDone ? AppColors.successGreen : Colors.white,
                      border: Border.all(
                        color: isDone ? AppColors.successGreen : AppColors.borderGrey,
                        width: 1.8,
                      ),
                    ),
                    child: isDone
                        ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
                        : null,
                  ),
                ),
              ],
            ],
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.sync_problem_rounded, size: 54, color: AppColors.borderGrey),
          const SizedBox(height: 12),
          Text(
            'Veriler yüklenemedi.',
            style: GoogleFonts.nunito(fontSize: 14.5, color: AppColors.textMid),
          ),
        ],
      ),
    );
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
      {'id': 'istigfar', 'title': 'İstiğfar', 'arabic': 'استغفار'},
    ];

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1B4D54), Color(0xFF113038)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF113038).withValues(alpha: 0.25),
            offset: const Offset(0, 8),
            blurRadius: 16,
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
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
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppColors.goldSoft,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Kütüphaneyi Keşfet',
                    style: GoogleFonts.nunito(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
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
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Günlük rutininize ekleyebileceğiniz sure, dua ve zikirler kütüphanesini inceleyin.',
            style: GoogleFonts.nunito(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.75),
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 112,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final availableWidth = constraints.maxWidth;
                // We want to show ~4.12 items in the visible area to indicate scrollability without showing text.
                final double visibleItems = 4.12;
                final double spacing = 8.0;
                final double itemWidth = (availableWidth - (visibleItems - 1) * spacing) / visibleItems;

                return ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(vertical: 8),
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
                          width: 52,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1.2),
                          ),
                          child: const Icon(
                            Icons.arrow_forward_rounded,
                            color: Colors.white,
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

                    return GestureDetector(
                      onTap: () => _quickToggleVird(id, isAdded),
                      child: Container(
                        width: itemWidth,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: isHighlight 
                              ? Colors.amber.withValues(alpha: 0.2) 
                              : Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isHighlight 
                                ? AppColors.gold 
                                : (isAdded 
                                    ? AppColors.successGreen.withValues(alpha: 0.5) 
                                    : Colors.white.withValues(alpha: 0.18)), 
                            width: isHighlight ? 1.8 : 1.2
                          ),
                          boxShadow: isHighlight ? [
                            BoxShadow(
                              color: AppColors.gold.withValues(alpha: 0.25),
                              blurRadius: 6,
                              spreadRadius: 1,
                            )
                          ] : null,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (isSpecial) ...[
                              Text(
                                '🕌 CUMA ÖZEL',
                                style: GoogleFonts.nunito(
                                  fontSize: 7.5,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.goldSoft,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 1),
                            ],
                            Text(
                              vird['title']!,
                              style: GoogleFonts.nunito(
                                fontSize: isSpecial ? 12.0 : 12.5,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              vird['arabic']!,
                              style: GoogleFonts.amiri(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: isAdded ? AppColors.successGreen : Colors.white.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isAdded ? Icons.check_rounded : Icons.add_rounded,
                                color: Colors.white,
                                size: 11,
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

class _PieCirclePainter extends CustomPainter {
  final double ratio;
  final Color fillColor;
  final Color borderColor;

  _PieCirclePainter({
    required this.ratio,
    required this.fillColor,
    required this.borderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Arka plan
    canvas.drawCircle(center, radius, Paint()..color = Colors.white12);

    // Pasta dilimi dolumu
    if (ratio > 0) {
      final fillPaint = Paint()..color = fillColor;
      canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * ratio, true, fillPaint);
    }

    // Kenarlık
    canvas.drawCircle(
      center,
      radius - 0.75,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_PieCirclePainter old) =>
      old.ratio != ratio || old.fillColor != fillColor || old.borderColor != borderColor;
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
