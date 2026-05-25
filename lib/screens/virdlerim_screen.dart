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

class VirdlerimScreen extends StatefulWidget {
  const VirdlerimScreen({super.key});

  @override
  State<VirdlerimScreen> createState() => _VirdlerimScreenState();
}

class _VirdlerimScreenState extends State<VirdlerimScreen> {
  final _uid = FirebaseAuth.instance.currentUser?.uid;
  bool _showCompleted = false;

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
          icon: const Icon(Icons.close_rounded, color: AppColors.textDark, size: 24),
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
        stream: _getCombinedStream(),
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
            return _buildNoActiveVirdsState();
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

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _buildProgressCard(completed.length, activeVirds.length, totalProgress),
              const SizedBox(height: 16),

              if (_isFriday()) _buildFridayBanner(),

              if (uncompleted.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'BUGÜN YAPILACAKLAR',
                    style: GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.teal, letterSpacing: 1.2),
                  ),
                ),
                ...uncompleted.map((item) => _buildVirdCard(item, log.completions[item.id] ?? 0)),
              ],

              if (completed.isNotEmpty) ...[
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () => setState(() => _showCompleted = !_showCompleted),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    color: Colors.transparent,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'TAMAMLANANLAR (${completed.length})',
                          style: GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.successGreen, letterSpacing: 1.2),
                        ),
                        Icon(
                          _showCompleted ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                          color: AppColors.successGreen,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
                if (_showCompleted)
                  ...completed.map((item) => _buildVirdCard(item, log.completions[item.id] ?? 0, isDone: true)),
              ],

              const SizedBox(height: 48),
            ],
          );
        },
      ),
    );
  }

  Widget _buildProgressCard(int done, int total, double progress) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2A7F8C), Color(0xFF1E6370)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.tealDark.withValues(alpha: 0.25),
            offset: const Offset(0, 8),
            blurRadius: 16,
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'GÜNLÜK RUTİNİM',
                  style: GoogleFonts.nunito(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppColors.goldSoft,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '"Az da olsa devamlı olanıdır."',
                  style: GoogleFonts.nunito(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                Text(
                  'amellerin en sevimlisi... (Müslim)',
                  style: GoogleFonts.nunito(
                    fontSize: 10.5,
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '$done / $total Tamamlandı',
                  style: GoogleFonts.nunito(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 76,
                height: 76,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 6.5,
                  backgroundColor: Colors.white10,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.gold),
                ),
              ),
              Text(
                '${(progress * 100).toInt()}%',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ],
          ),
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

  Widget _buildVirdCard(VirdItem item, int currentCount, {bool isDone = false}) {
    final isZikir = item.category == 'zikir';
    final progress = item.targetCount > 0 ? (currentCount / item.targetCount).clamp(0.0, 1.0) : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDone ? AppColors.successBg.withValues(alpha: 0.25) : AppColors.lightGrey,
        border: Border.all(
          color: isDone ? AppColors.successGreen.withValues(alpha: 0.25) : AppColors.borderGrey,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(
              width: 4.5,
              decoration: BoxDecoration(
                color: isDone
                    ? AppColors.successGreen
                    : (item.category == 'sure' ? AppColors.teal : AppColors.orange),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
              ),
            ),
            Expanded(
              child: InkWell(
                onTap: () {
                  if (isZikir) {
                    _openZikirmatik(item, currentCount);
                  } else {
                    _toggleSureDua(item, currentCount);
                  }
                },
                borderRadius: const BorderRadius.horizontal(right: Radius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
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
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.bold,
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
                                  style: GoogleFonts.nunito(fontSize: 10.5, color: AppColors.textLight, fontWeight: FontWeight.w600),
                                ),
                                if (isZikir && !isDone) ...[
                                  const SizedBox(width: 6),
                                  Text(
                                    '•  $currentCount / ${item.targetCount}',
                                    style: GoogleFonts.nunito(
                                      fontSize: 10.5,
                                      color: AppColors.orange,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (item.arabicTitle != null && !isDone) ...[
                        const SizedBox(width: 8),
                        Text(
                          item.arabicTitle!,
                          style: GoogleFonts.amiri(
                            fontSize: 15.5,
                            color: AppColors.textLight.withValues(alpha: 0.8),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      const SizedBox(width: 12),
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
                                  width: 38,
                                  height: 38,
                                  child: CircularProgressIndicator(
                                    value: progress,
                                    strokeWidth: 3,
                                    backgroundColor: AppColors.borderGrey,
                                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.orange),
                                  ),
                                ),
                                const Icon(Icons.add_rounded, color: AppColors.orange, size: 20),
                              ],
                            ),
                          ),
                      ] else ...[
                        GestureDetector(
                          onTap: () => _toggleSureDua(item, currentCount),
                          child: Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isDone ? AppColors.successGreen : Colors.white,
                              border: Border.all(
                                color: isDone ? AppColors.successGreen : AppColors.borderGrey,
                                width: 2,
                              ),
                            ),
                            child: isDone
                                ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                                : null,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDoneIndicator() {
    return Container(
      width: 26,
      height: 26,
      decoration: const BoxDecoration(
        color: AppColors.successGreen,
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.check_rounded, color: Colors.white, size: 16),
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

  Widget _buildNoActiveVirdsState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('📿', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            Text(
              'Aktif Virdiniz Bulunmuyor',
              style: GoogleFonts.nunito(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textDark),
            ),
            const SizedBox(height: 6),
            Text(
              'Rutinlerinizi oluşturmak için sağ üstteki buton ile kütüphaneyi inceleyebilir, istediğiniz virdi listenize ekleyebilirsiniz.',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(fontSize: 13.5, color: AppColors.textLight, height: 1.5),
            ),
            const SizedBox(height: 24),
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
      ),
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
