import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math' as math;
import 'package:provider/provider.dart';
import '../app_colors.dart';
import '../providers/user_provider.dart';
import '../widgets/habit_tracker_widget.dart';
import '../widgets/regl_calendar_sheet.dart';

enum PrayerStatus { none, onTime, kaza, cemaat, regl }
enum PrayerTime { sabah, ogle, ikindi, aksam, yatsi }

class DayRecord {
  final DateTime date;
  Map<PrayerTime, PrayerStatus> prayers;
  Map<PrayerTime, bool> tesbihats;
  Map<PrayerTime, List<bool>> sunnahs;

  DayRecord({required this.date, required this.prayers, required this.tesbihats, required this.sunnahs});
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
    if (val == 'regl') return PrayerStatus.regl;
    return PrayerStatus.none;
  }

  String _stringFromStatus(PrayerStatus status) {
    if (status == PrayerStatus.onTime) return 'onTime';
    if (status == PrayerStatus.kaza) return 'kaza';
    if (status == PrayerStatus.cemaat) return 'cemaat';
    if (status == PrayerStatus.regl) return 'regl';
    return 'none';
  }

  List<bool> _defaultSunnahs(PrayerTime time) {
    switch (time) {
      case PrayerTime.sabah: return [false];
      case PrayerTime.ogle: return [false, false];
      case PrayerTime.ikindi: return [false];
      case PrayerTime.aksam: return [false];
      case PrayerTime.yatsi: return [false, false, false];
    }
  }

  List<String> _getSunnahNames(PrayerTime time) {
    switch (time) {
      case PrayerTime.sabah: return ['Sünnet'];
      case PrayerTime.ogle: return ['İlk Sünnet', 'Son Sünnet'];
      case PrayerTime.ikindi: return ['Sünnet'];
      case PrayerTime.aksam: return ['Sünnet'];
      case PrayerTime.yatsi: return ['İlk Sünnet', 'Son Sünnet', 'Vitir'];
    }
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
        final Map<String, dynamic> tMap = data['tesbihats'] ?? {};
        final Map<String, dynamic> sMap = data['sunnahs'] ?? {};

        List<bool> getSunnahList(PrayerTime pt, String key) {
           if (sMap[key] != null) {
              return List<bool>.from(sMap[key]);
           }
           return _defaultSunnahs(pt);
        }
        
        _allRecords[d] = DayRecord(
          date: d,
          prayers: {
             PrayerTime.sabah: _statusFromString(pMap['sabah']),
             PrayerTime.ogle: _statusFromString(pMap['ogle']),
             PrayerTime.ikindi: _statusFromString(pMap['ikindi']),
             PrayerTime.aksam: _statusFromString(pMap['aksam']),
             PrayerTime.yatsi: _statusFromString(pMap['yatsi']),
          },
          tesbihats: {
             PrayerTime.sabah: tMap['sabah'] ?? false,
             PrayerTime.ogle: tMap['ogle'] ?? false,
             PrayerTime.ikindi: tMap['ikindi'] ?? false,
             PrayerTime.aksam: tMap['aksam'] ?? false,
             PrayerTime.yatsi: tMap['yatsi'] ?? false,
          },
          sunnahs: {
             PrayerTime.sabah: getSunnahList(PrayerTime.sabah, 'sabah'),
             PrayerTime.ogle: getSunnahList(PrayerTime.ogle, 'ogle'),
             PrayerTime.ikindi: getSunnahList(PrayerTime.ikindi, 'ikindi'),
             PrayerTime.aksam: getSunnahList(PrayerTime.aksam, 'aksam'),
             PrayerTime.yatsi: getSunnahList(PrayerTime.yatsi, 'yatsi'),
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
           },
           'tesbihats': {
              'sabah': record.tesbihats[PrayerTime.sabah],
              'ogle': record.tesbihats[PrayerTime.ogle],
              'ikindi': record.tesbihats[PrayerTime.ikindi],
              'aksam': record.tesbihats[PrayerTime.aksam],
              'yatsi': record.tesbihats[PrayerTime.yatsi],
           },
           'sunnahs': {
              'sabah': record.sunnahs[PrayerTime.sabah],
              'ogle': record.sunnahs[PrayerTime.ogle],
              'ikindi': record.sunnahs[PrayerTime.ikindi],
              'aksam': record.sunnahs[PrayerTime.aksam],
              'yatsi': record.sunnahs[PrayerTime.yatsi],
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
        tesbihats: {
          PrayerTime.sabah: false,
          PrayerTime.ogle: false,
          PrayerTime.ikindi: false,
          PrayerTime.aksam: false,
          PrayerTime.yatsi: false,
        },
        sunnahs: {
          PrayerTime.sabah: _defaultSunnahs(PrayerTime.sabah),
          PrayerTime.ogle: _defaultSunnahs(PrayerTime.ogle),
          PrayerTime.ikindi: _defaultSunnahs(PrayerTime.ikindi),
          PrayerTime.aksam: _defaultSunnahs(PrayerTime.aksam),
          PrayerTime.yatsi: _defaultSunnahs(PrayerTime.yatsi),
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
    final cinsiyet = context.read<UserProvider>().cinsiyet;
    PrayerTime selectedTime = PrayerTime.sabah;
    
    // Uygulama saati bazlı varsayılan vakit seçimi
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) selectedTime = PrayerTime.sabah;
    else if (hour >= 12 && hour < 16) selectedTime = PrayerTime.ogle;
    else if (hour >= 16 && hour < 19) selectedTime = PrayerTime.ikindi;
    else if (hour >= 19 && hour < 21) selectedTime = PrayerTime.aksam;
    else selectedTime = PrayerTime.yatsi;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final status = record.prayers[selectedTime] ?? PrayerStatus.none;
            final isRegl = status == PrayerStatus.regl && cinsiyet == 'hanim';
            final isTesbihat = record.tesbihats[selectedTime] ?? false;
            final isOnTime = status == PrayerStatus.onTime || status == PrayerStatus.cemaat;
            final isKaza = status == PrayerStatus.kaza;
            final isCemaat = status == PrayerStatus.cemaat;

            return Container(
              padding: const EdgeInsets.only(top: 20, left: 16, right: 16, bottom: 20),
              decoration: const BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Başlık ve Muafiyet
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${record.date.day} ${_getMonthName(record.date.month)} Namaz Takibi',
                        style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textDark),
                      ),
                      if (cinsiyet == 'hanim')
                        PopupMenuButton<String>(
                          position: PopupMenuPosition.under,
                          offset: const Offset(0, 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          onSelected: (val) {
                            if (val == 'all') {
                              setModalState(() {
                                for (var time in PrayerTime.values) {
                                  record.prayers[time] = PrayerStatus.regl;
                                  _updatePrayer(record, time, PrayerStatus.regl);
                                }
                              });
                              setState(() {});
                            } else if (val == 'current') {
                              final newStatus = isRegl ? PrayerStatus.none : PrayerStatus.regl;
                              setModalState(() { record.prayers[selectedTime] = newStatus; });
                              setState(() {});
                              _updatePrayer(record, selectedTime, newStatus);
                            } else if (val == 'calendar') {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (context) => const ReglCalendarSheet(),
                              );
                            }
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 'current',
                              child: Row(
                                children: [
                                  Icon(Icons.check_circle_outline, size: 18, color: Colors.pink.shade300),
                                  const SizedBox(width: 8),
                                  Text(isRegl ? 'Muafiyeti Kaldır' : 'Bu Vakti Muaf Yap', style: GoogleFonts.nunito(fontSize: 13)),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'all',
                              child: Row(
                                children: [
                                  Icon(Icons.done_all, size: 18, color: Colors.pink.shade300),
                                  const SizedBox(width: 8),
                                  Text('Hepsini Muaf Yap', style: GoogleFonts.nunito(fontSize: 13)),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'calendar',
                              child: Row(
                                children: [
                                  Icon(Icons.calendar_month, size: 18, color: Colors.pink.shade300),
                                  const SizedBox(width: 8),
                                  Text('Regl Takvimi', style: GoogleFonts.nunito(fontSize: 13)),
                                ],
                              ),
                            ),
                          ],
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: isRegl ? Colors.pink.shade50 : AppColors.lightGrey,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: isRegl ? Colors.pink.shade200 : Colors.transparent),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.filter_vintage, size: 14, color: isRegl ? Colors.pink.shade400 : Colors.grey),
                                const SizedBox(width: 4),
                                Text('Muaf', style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w700, color: isRegl ? Colors.pink.shade400 : Colors.grey)),
                                const Icon(Icons.arrow_drop_down, size: 16, color: Colors.grey),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 1. SATIR: Vakit Seçici Bar
                  Container(
                    height: 36,
                    decoration: BoxDecoration(color: AppColors.lightGrey, borderRadius: BorderRadius.circular(18)),
                    child: Row(
                      children: PrayerTime.values.map((time) {
                        final isSelected = time == selectedTime;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () => setModalState(() => selectedTime = time),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.teal : Colors.transparent,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                _getPrayerName(time),
                                style: GoogleFonts.nunito(fontSize: 11, fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600, color: isSelected ? Colors.white : AppColors.textMid),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (isRegl) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text('Bu vakit için muaf durumdasınız.', style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.pink.shade400)),
                    ),
                  ] else ...[
                    // 2. SATIR: Kaza | Vaktinde Kıldım | Cemaat
                    Row(
                      children: [
                        // Kaza (Küçük)
                        Expanded(
                          flex: 2,
                          child: _buildActionButton(
                            label: 'Kaza',
                            isSelected: isKaza,
                            activeColor: const Color(0xFFB8DFE4),
                            activeTextColor: AppColors.tealDark,
                            onTap: () {
                              final next = isKaza ? PrayerStatus.none : PrayerStatus.kaza;
                              setModalState(() { record.prayers[selectedTime] = next; });
                              setState(() {});
                              _updatePrayer(record, selectedTime, next);
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Vaktinde Kıldım (Büyük - Orta)
                        Expanded(
                          flex: 5,
                          child: _buildActionButton(
                            label: 'Vaktinde Kıldım',
                            isSelected: isOnTime,
                            activeColor: const Color(0xFF7EC4CC),
                            activeTextColor: Colors.white,
                            isBold: true,
                            onTap: () {
                              final next = isOnTime ? PrayerStatus.none : PrayerStatus.onTime;
                              setModalState(() { record.prayers[selectedTime] = next; });
                              setState(() {});
                              _updatePrayer(record, selectedTime, next);
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Cemaat (Küçük)
                        Expanded(
                          flex: 2,
                          child: _buildActionButton(
                            label: 'Cemaat',
                            icon: Icons.people,
                            isSelected: isCemaat,
                            activeColor: AppColors.teal,
                            activeTextColor: Colors.white,
                            fontSize: 10,
                            onTap: () {
                              final next = isCemaat ? PrayerStatus.onTime : PrayerStatus.cemaat;
                              setModalState(() { record.prayers[selectedTime] = next; });
                              setState(() {});
                              _updatePrayer(record, selectedTime, next);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // 3. SATIR: Tesbihat + Sünnetler
                    Row(
                      children: [
                        Expanded(
                          child: _buildActionButton(
                            label: 'Tesbihat 📿',
                            isSelected: isTesbihat,
                            activeColor: AppColors.gold,
                            activeTextColor: Colors.white,
                            fontSize: 11,
                            onTap: () {
                              setModalState(() { record.tesbihats[selectedTime] = !isTesbihat; });
                              setState(() {});
                              _updatePrayer(record, selectedTime, record.prayers[selectedTime] ?? PrayerStatus.none);
                            },
                          ),
                        ),
                        const SizedBox(width: 6),
                        ...List.generate(_getSunnahNames(selectedTime).length, (idx) {
                          final sNameRaw = _getSunnahNames(selectedTime)[idx];
                          final sName = sNameRaw == 'Vitir' ? 'Vitir Namazı' : sNameRaw;
                          final isDone = record.sunnahs[selectedTime]![idx];
                          
                          // Kaza seçiliyse pasif görünüm
                          final isPassive = isKaza;

                          return Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(right: idx == _getSunnahNames(selectedTime).length - 1 ? 0 : 6.0),
                              child: _buildActionButton(
                                label: sName,
                                isSelected: isDone,
                                activeColor: isPassive ? AppColors.borderGrey : AppColors.goldSoft,
                                activeTextColor: Colors.white,
                                fontSize: 10,
                                isEnabled: !isPassive,
                                onTap: () {
                                  setModalState(() { record.sunnahs[selectedTime]![idx] = !isDone; });
                                  setState(() {});
                                  _updatePrayer(record, selectedTime, record.prayers[selectedTime] ?? PrayerStatus.none);
                                },
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildActionButton({
    String? label,
    IconData? icon,
    required bool isSelected,
    required Color activeColor,
    required Color activeTextColor,
    required VoidCallback onTap,
    double fontSize = 11,
    bool isBold = false,
    bool isEnabled = true,
  }) {
    return GestureDetector(
      onTap: isEnabled ? onTap : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: isEnabled ? 1.0 : 0.5,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? activeColor : AppColors.lightGrey,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isSelected ? activeColor.withValues(alpha: 0.5) : AppColors.borderGrey),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: isSelected ? activeTextColor : Colors.grey.shade400),
                if (label != null) const SizedBox(width: 4),
              ],
              if (label != null)
                Flexible(
                  child: Text(
                    label,
                    style: GoogleFonts.nunito(
                      fontSize: fontSize,
                      fontWeight: isBold || isSelected ? FontWeight.w800 : FontWeight.w600,
                      color: isSelected ? activeTextColor : AppColors.textMid,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        ),
      ),
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
    final cinsiyet = context.read<UserProvider>().cinsiyet ?? 'bey';
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
                                        width: 46,
                                        height: 46,
                                        child: CustomPaint(
                                          painter: PrayerPieChartPainter(record.prayers, cinsiyet, record.tesbihats, record.sunnahs),
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
  final String cinsiyet;
  final Map<PrayerTime, bool> tesbihats;
  final Map<PrayerTime, List<bool>> sunnahs;

  PrayerPieChartPainter(this.prayers, this.cinsiyet, this.tesbihats, this.sunnahs);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRingWidth = size.width * 0.07; 
    final gap = size.width * 0.04;
    final innerRadius = (size.width / 2) - outerRingWidth - gap;
    final innerRect = Rect.fromCircle(center: center, radius: innerRadius);
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
        paint.color = const Color(0xFF7EC4CC); 
      } else if (status == PrayerStatus.kaza) {
        paint.color = const Color(0xFFB8DFE4); 
      } else if (status == PrayerStatus.cemaat) {
        paint.color = AppColors.teal; 
      } else if (status == PrayerStatus.regl && cinsiyet == 'hanim') {
        paint.color = Colors.pink.shade200; 
      } else {
        paint.color = AppColors.borderGrey.withValues(alpha: 0.5); 
      }
      
      final startAngle = -math.pi / 2 + (i * sweepAngle);
      
      canvas.drawArc(innerRect, startAngle, sweepAngle, true, paint);
      canvas.drawArc(innerRect, startAngle, sweepAngle, true, borderPaint);

      final sunnahList = sunnahs[time] ?? [];
      final numSunnahs = sunnahList.length;
      if (numSunnahs > 0) {
        final outerRadius = (size.width / 2) - (outerRingWidth / 2);
        final outerRect = Rect.fromCircle(center: center, radius: outerRadius);
        
        final borderGapAngle = 0.18; 
        final usableSweep = sweepAngle - borderGapAngle;
        final startOffset = startAngle + (borderGapAngle / 2);
        
        final sunnahSweep = usableSweep / numSunnahs;
        
        for (int j = 0; j < numSunnahs; j++) {
           final isDone = sunnahList[j];
           final sunnahGap = numSunnahs > 1 ? 0.12 : 0.0; 
           
           final actualStart = startOffset + (j * sunnahSweep) + (sunnahGap / 2);
           final actualSweep = sunnahSweep - sunnahGap;

           Color ringColor;
           if (status == PrayerStatus.regl && cinsiyet == 'hanim') {
             ringColor = Colors.pink.shade200;
           } else {
             ringColor = isDone ? AppColors.gold : AppColors.borderGrey.withValues(alpha: 0.4);
           }

           final ringPaint = Paint()
             ..style = PaintingStyle.stroke
             ..strokeWidth = outerRingWidth
             ..color = ringColor
             ..strokeCap = StrokeCap.round; 

           canvas.drawArc(outerRect, actualStart, actualSweep, false, ringPaint);
        }
      }

      if (tesbihats[time] == true) {
        final middleAngle = startAngle + sweepAngle / 2;
        // Inner radius referans alarak yıldıza boyut verelim
        final rOut = innerRadius / 3.0; 
        final rMax = innerRadius / 1.2; 
        
        final path = Path();
        path.moveTo(center.dx, center.dy);
        path.lineTo(center.dx + math.cos(startAngle + sweepAngle * 0.15) * rOut, 
                    center.dy + math.sin(startAngle + sweepAngle * 0.15) * rOut);
        path.lineTo(center.dx + math.cos(middleAngle) * rMax, 
                    center.dy + math.sin(middleAngle) * rMax);
        path.lineTo(center.dx + math.cos(startAngle + sweepAngle * 0.85) * rOut, 
                    center.dy + math.sin(startAngle + sweepAngle * 0.85) * rOut);
        path.close();
        
        final tesbihPaint = Paint()
          ..style = PaintingStyle.fill
          ..color = (status == PrayerStatus.regl && cinsiyet == 'hanim') 
              ? Colors.pink.shade200 
              : AppColors.gold;
          
        canvas.drawPath(path, tesbihPaint);
      }
      
      i++;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
