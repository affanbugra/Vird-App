import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math' as math;
import '../app_colors.dart';
import '../widgets/habit_tracker_widget.dart';

enum PrayerStatus { none, onTime, kaza, cemaat }
enum PrayerTime { sabah, ogle, ikindi, aksam, yatsi }

class DayRecord {
  final DateTime date;
  Map<PrayerTime, PrayerStatus> prayers;

  DayRecord({required this.date, required this.prayers});
}

class GunlukTakiplerScreen extends StatefulWidget {
  const GunlukTakiplerScreen({super.key});

  @override
  State<GunlukTakiplerScreen> createState() => _GunlukTakiplerScreenState();
}

class _GunlukTakiplerScreenState extends State<GunlukTakiplerScreen> {
  final Map<DateTime, DayRecord> _allRecords = {};
  bool _isLoading = false;

  late final PageController _pageController;
  final int _initialPage = 10000;
  int _currentPage = 10000;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _initialPage);
    
    // Uygulama ilk açıldığında mevcut haftayı (offset = 0) ve önceki haftayı (offset = -1) önden yükleyelim
    _fetchWeekData(0);
    _fetchWeekData(-1);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  int get _weekOffset => _currentPage - _initialPage;

  PrayerStatus _statusFromString(String? val) {
    if (val == 'onTime') return PrayerStatus.onTime;
    if (val == 'kaza') return PrayerStatus.kaza;
    if (val == 'cemaat') return PrayerStatus.cemaat;
    return PrayerStatus.none;
  }

  String _stringFromStatus(PrayerStatus status) {
    if (status == PrayerStatus.onTime) return 'onTime';
    if (status == PrayerStatus.kaza) return 'kaza';
    if (status == PrayerStatus.cemaat) return 'cemaat';
    return 'none';
  }

  Future<void> _fetchWeekData(int targetOffset) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final today = DateTime.now();
    final todayClean = DateTime(today.year, today.month, today.day);
    final currentMonday = todayClean.subtract(Duration(days: todayClean.weekday - 1));
    final targetMonday = currentMonday.add(Duration(days: targetOffset * 7));

    // 7 günün verilerini paralel olarak çekelim
    try {
      final futures = List.generate(7, (index) {
        final d = targetMonday.add(Duration(days: index));
        final dateStr = "prayer_${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
        return FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('logs')
            .doc(dateStr)
            .get();
      });

      final snapshots = await Future.wait(futures);
      bool hasChanges = false;

      for (var doc in snapshots) {
        if (!doc.exists) continue;
        final data = doc.data()!;
        final dateStr = (data['date'] as String).replaceAll('prayer_', '');
        final parts = dateStr.split('-');
        final d = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
        
        final Map<String, dynamic> pMap = data['prayers'] ?? {};
        
        _allRecords[d] = DayRecord(
          date: d,
          prayers: {
             PrayerTime.sabah: _statusFromString(pMap['sabah']),
             PrayerTime.ogle: _statusFromString(pMap['ogle']),
             PrayerTime.ikindi: _statusFromString(pMap['ikindi']),
             PrayerTime.aksam: _statusFromString(pMap['aksam']),
             PrayerTime.yatsi: _statusFromString(pMap['yatsi']),
          }
        );
        hasChanges = true;
      }

      if (hasChanges && mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint("Error fetching prayers: \$e");
    }
  }

  Future<void> _updatePrayer(DayRecord record, PrayerTime time, PrayerStatus status) async {
    record.prayers[time] = status;
    setState(() {});

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final d = record.date;
    final dateStr = "prayer_${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

    try {
      await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('logs')
        .doc(dateStr)
        .set({
           'type': 'prayer',
           'date': dateStr,
           'prayers': {
              'sabah': _stringFromStatus(record.prayers[PrayerTime.sabah]!),
              'ogle': _stringFromStatus(record.prayers[PrayerTime.ogle]!),
              'ikindi': _stringFromStatus(record.prayers[PrayerTime.ikindi]!),
              'aksam': _stringFromStatus(record.prayers[PrayerTime.aksam]!),
              'yatsi': _stringFromStatus(record.prayers[PrayerTime.yatsi]!),
           }
        }, SetOptions(merge: true));
    } catch (e) {
      debugPrint("Error updating prayer: \$e");
    }
  }

  DayRecord _getRecordForDate(DateTime date) {
    final cleanDate = DateTime(date.year, date.month, date.day);
    if (!_allRecords.containsKey(cleanDate)) {
      _allRecords[cleanDate] = DayRecord(
        date: cleanDate,
        prayers: {
          PrayerTime.sabah: PrayerStatus.none,
          PrayerTime.ogle: PrayerStatus.none,
          PrayerTime.ikindi: PrayerStatus.none,
          PrayerTime.aksam: PrayerStatus.none,
          PrayerTime.yatsi: PrayerStatus.none,
        },
      );
    }
    return _allRecords[cleanDate]!;
  }

  List<DayRecord> _getWeekRecordsForOffset(int offset) {
    final today = DateTime.now();
    final todayClean = DateTime(today.year, today.month, today.day);
    final currentMonday = todayClean.subtract(Duration(days: todayClean.weekday - 1));
    final targetMonday = currentMonday.add(Duration(days: offset * 7));
    
    return List.generate(7, (index) => _getRecordForDate(targetMonday.add(Duration(days: index))));
  }

  String _getDayName(DateTime date) {
    const days = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
    return days[date.weekday - 1];
  }

  String _getMonthName(int month) {
    const months = ['', 'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', 'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'];
    return months[month];
  }

  void _showPrayerPopup(DayRecord record) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${record.date.day} ${_getMonthName(record.date.month)} Namaz Takibi',
                    style: GoogleFonts.nunito(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...PrayerTime.values.map((time) {
                    final status = record.prayers[time] ?? PrayerStatus.none;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _getPrayerName(time),
                            style: GoogleFonts.nunito(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark,
                            ),
                          ),
                          Row(
                            children: [
                              // Kaza Butonu
                              GestureDetector(
                                onTap: () {
                                  final newStatus = status == PrayerStatus.kaza ? PrayerStatus.none : PrayerStatus.kaza;
                                  setModalState(() {
                                    record.prayers[time] = newStatus;
                                  });
                                  _updatePrayer(record, time, newStatus);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: status == PrayerStatus.kaza ? AppColors.goldSoft : AppColors.lightGrey,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: status == PrayerStatus.kaza ? AppColors.gold : AppColors.borderGrey,
                                    ),
                                  ),
                                  child: Text(
                                    'Kaza',
                                    style: GoogleFonts.nunito(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: status == PrayerStatus.kaza ? Colors.white : AppColors.textMid,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Onay (Vaktinde) Butonu
                              GestureDetector(
                                onTap: () {
                                  final newStatus = status == PrayerStatus.onTime ? PrayerStatus.none : PrayerStatus.onTime;
                                  setModalState(() {
                                    record.prayers[time] = newStatus;
                                  });
                                  _updatePrayer(record, time, newStatus);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: status == PrayerStatus.onTime ? AppColors.tealSoft : AppColors.lightGrey,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: status == PrayerStatus.onTime ? AppColors.teal : AppColors.borderGrey,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.check,
                                        size: 16,
                                        color: status == PrayerStatus.onTime ? Colors.white : AppColors.textMid,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Kılındı',
                                        style: GoogleFonts.nunito(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: status == PrayerStatus.onTime ? Colors.white : AppColors.textMid,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Cemaatle Butonu
                              GestureDetector(
                                onTap: () {
                                  final newStatus = status == PrayerStatus.cemaat ? PrayerStatus.none : PrayerStatus.cemaat;
                                  setModalState(() {
                                    record.prayers[time] = newStatus;
                                  });
                                  _updatePrayer(record, time, newStatus);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: status == PrayerStatus.cemaat ? AppColors.teal : AppColors.lightGrey,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: status == PrayerStatus.cemaat ? AppColors.tealDark : AppColors.borderGrey,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.people,
                                        size: 16,
                                        color: status == PrayerStatus.cemaat ? Colors.white : AppColors.textMid,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Cemaat',
                                        style: GoogleFonts.nunito(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: status == PrayerStatus.cemaat ? Colors.white : AppColors.textMid,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          )
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _getPrayerName(PrayerTime time) {
    switch (time) {
      case PrayerTime.sabah: return 'Sabah';
      case PrayerTime.ogle: return 'Öğle';
      case PrayerTime.ikindi: return 'İkindi';
      case PrayerTime.aksam: return 'Akşam';
      case PrayerTime.yatsi: return 'Yatsı';
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentWeekRecords = _getWeekRecordsForOffset(_weekOffset);
    final weekMidDate = currentWeekRecords[3].date; 
    final currentMonthText = '${_getMonthName(weekMidDate.month)} ${weekMidDate.year}';

    return Scaffold(
      backgroundColor: AppColors.lightGrey,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.textDark),
        title: Text(
          'Günlük Takiplerim',
          style: GoogleFonts.nunito(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.textDark,
          ),
        ),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: AppColors.teal))
        : SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Haftalık Namaz Takibi',
                style: GoogleFonts.nunito(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.fromLTRB(4, 12, 4, 20),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderGrey),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_left, color: AppColors.textDark),
                            onPressed: () {
                              _pageController.previousPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            },
                          ),
                          Expanded(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              child: Text(
                                currentMonthText,
                                key: ValueKey(currentMonthText),
                                textAlign: TextAlign.right,
                                style: GoogleFonts.nunito(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textMid,
                                ),
                              ),
                            ),
                          ),
                          if (_weekOffset < 0)
                            IconButton(
                              icon: const Icon(Icons.chevron_right, color: AppColors.textDark),
                              onPressed: () {
                                _pageController.nextPage(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                );
                              },
                            )
                          else
                            const SizedBox(width: 48),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 100, // Daireler ve metinler için yeterli yükseklik (overflow'u önlemek için artırıldı)
                      child: PageView.builder(
                        controller: _pageController,
                        itemCount: _initialPage + 1, // Max sayfa _initialPage (geleceğe gidiş yok)
                        onPageChanged: (page) {
                          setState(() {
                            _currentPage = page;
                          });
                          _fetchWeekData(_weekOffset);
                        },
                        itemBuilder: (context, index) {
                          final pageOffset = index - _initialPage;
                          final pageRecords = _getWeekRecordsForOffset(pageOffset);

                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: pageRecords.map((record) {
                              final now = DateTime.now();
                              final todayDate = DateTime(now.year, now.month, now.day);
                              final recDate = DateTime(record.date.year, record.date.month, record.date.day);
                              
                              final isToday = recDate.isAtSameMomentAs(todayDate);
                              final isFuture = recDate.isAfter(todayDate);

                              return GestureDetector(
                                onTap: () {
                                  if (isFuture) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Henüz bu güne gelmediniz!',
                                          style: GoogleFonts.nunito(fontWeight: FontWeight.w600),
                                        ),
                                        backgroundColor: AppColors.orange,
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  } else {
                                    _showPrayerPopup(record);
                                  }
                                },
                                child: Opacity(
                                  opacity: isFuture ? 0.4 : 1.0,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _getDayName(record.date),
                                        style: GoogleFonts.nunito(
                                          fontSize: 12,
                                          fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                                          color: isToday ? AppColors.teal : AppColors.textMid,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      SizedBox(
                                        width: 36,
                                        height: 36,
                                        child: CustomPaint(
                                          painter: PrayerPieChartPainter(record.prayers),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        '${record.date.day}',
                                        style: GoogleFonts.nunito(
                                          fontSize: 12,
                                          fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                                          color: isToday ? AppColors.teal : AppColors.textLight,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              HabitTrackerWidget(),
            ],
          ),
        ),
      ),
    );
  }
}

class PrayerPieChartPainter extends CustomPainter {
  final Map<PrayerTime, PrayerStatus> prayers;

  PrayerPieChartPainter(this.prayers);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final sweepAngle = (2 * math.pi) / 5;
    
    final paint = Paint()..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = AppColors.white
      ..strokeWidth = 1.5;

    int i = 0;
    for (var time in PrayerTime.values) {
      final status = prayers[time] ?? PrayerStatus.none;
      
      if (status == PrayerStatus.onTime) {
        paint.color = AppColors.tealSoft; 
      } else if (status == PrayerStatus.kaza) {
        paint.color = AppColors.goldSoft; 
      } else if (status == PrayerStatus.cemaat) {
        paint.color = AppColors.teal; 
      } else {
        paint.color = AppColors.borderGrey.withValues(alpha: 0.5); 
      }
      
      final startAngle = -math.pi / 2 + (i * sweepAngle);
      
      canvas.drawArc(rect, startAngle, sweepAngle, true, paint);
      canvas.drawArc(rect, startAngle, sweepAngle, true, borderPaint);
      i++;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
