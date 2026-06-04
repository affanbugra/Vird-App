import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math' as math;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app_colors.dart';
import '../providers/user_provider.dart';
import '../widgets/habit_tracker_widget.dart';
import '../widgets/regl_calendar_sheet.dart';
import 'virdlerim_screen.dart';

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

class _GunlukTakiplerScreenState extends State<GunlukTakiplerScreen>
    with TickerProviderStateMixin {
  final Map<DateTime, DayRecord> _allRecords = {};
  // Hangi hafta/ay periyodunun Firestore'dan çekildiğini tutar.
  // _allRecords.containsKey yerine bunu kullanmak, build sırasında
  // _getRecordForDate'in oluşturduğu boş kayıtların fetch'i atlatmasını önler.
  final Set<String> _fetchedPeriods = {};

  late final PageController _pageController;
  final int _initialPage = 10000;
  int _currentPage = 10000;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _initialPage);
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _saveTab(_tabController.index);
      }
    });
    _fetchWeekData(0);
    _fetchWeekData(-1);

    // Cari ay verilerini arka planda önceden yükle (hızlandırma için)
    final now = DateTime.now();
    _fetchMonthData(now.year, now.month);

    _loadSavedTab();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedTab() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getInt('takipler_tab_index') ?? 0;
    if (mounted && saved != 0) {
      _tabController.animateTo(saved, duration: Duration.zero);
    }
  }

  void _saveTab(int index) {
    SharedPreferences.getInstance().then((prefs) {
      prefs.setInt('takipler_tab_index', index);
    });
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

    // Aynı haftayı tekrar çekme — _allRecords.containsKey kullanmıyoruz çünkü
    // build sırasında _getRecordForDate boş kayıt oluşturarak fetch'i atlatabiliyor.
    final weekKey = 'week_${targetMonday.year}-${targetMonday.month}-${targetMonday.day}';
    if (_fetchedPeriods.contains(weekKey)) return;
    _fetchedPeriods.add(weekKey);

    final daysToFetch = <DateTime>[];
    for (int i = 0; i < 7; i++) {
      final d = targetMonday.add(Duration(days: i));
      if (d.isAfter(todayClean)) break;
      daysToFetch.add(d);
    }
    if (daysToFetch.isEmpty) return;

    try {
      final futures = daysToFetch.map((d) {
        final dateStr = "prayer_${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
        return FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('logs')
            .doc(dateStr)
            .get();
      }).toList();

      final snapshots = await Future.wait(futures);
      bool hasChanges = false;

      for (var doc in snapshots) {
        if (!doc.exists) continue;
        final data = doc.data()!;
        final rawDate = data['date'];
        if (rawDate == null) continue;
        final dateStr = (rawDate as String).replaceAll('prayer_', '');
        final parts = dateStr.split('-');
        if (parts.length != 3) continue;
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
      debugPrint("Error fetching prayers: $e");
    }
  }

  Future<void> _updatePrayer(DayRecord record, PrayerTime time, PrayerStatus status) async {
    record.prayers[time] = status;

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
      debugPrint("Error updating prayer: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Kayıt sırasında sorun oluştu. İnternet bağlantını kontrol et.',
            style: GoogleFonts.nunito(fontWeight: FontWeight.w600),
          ),
          backgroundColor: AppColors.errorRed,
          duration: const Duration(seconds: 3),
        ),
      );
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

  Future<void> _showPrayerPopup(DayRecord record) async {
    final cinsiyet = context.read<UserProvider>().cinsiyet;
    PrayerTime selectedTime = PrayerTime.sabah;
    
    // Uygulama saati bazlı varsayılan vakit seçimi
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) selectedTime = PrayerTime.sabah;
    else if (hour >= 12 && hour < 16) selectedTime = PrayerTime.ogle;
    else if (hour >= 16 && hour < 19) selectedTime = PrayerTime.ikindi;
    else if (hour >= 19 && hour < 21) selectedTime = PrayerTime.aksam;
    else selectedTime = PrayerTime.yatsi;

    await showModalBottomSheet(
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

            final bottomInset = MediaQuery.of(context).viewPadding.bottom;
            return Container(
              padding: EdgeInsets.only(
                top: 20,
                left: 16,
                right: 16,
                bottom: 20 + bottomInset + 16,
              ),
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
                              for (var time in PrayerTime.values) {
                                record.prayers[time] = PrayerStatus.regl;
                                record.sunnahs[time] = _defaultSunnahs(time);
                                record.tesbihats[time] = false;
                              }
                              setModalState(() {});
                              setState(() {});
                              _updatePrayer(record, PrayerTime.sabah, PrayerStatus.regl);
                            } else if (val == 'current') {
                              final newStatus = isRegl ? PrayerStatus.none : PrayerStatus.regl;
                              setModalState(() {
                                record.prayers[selectedTime] = newStatus;
                                if (newStatus == PrayerStatus.regl) {
                                  record.sunnahs[selectedTime] = _defaultSunnahs(selectedTime);
                                  record.tesbihats[selectedTime] = false;
                                }
                              });
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
                              setModalState(() {
                                record.prayers[selectedTime] = next;
                                // Kaza seçilince o vaktin sünnetlerini sıfırla —
                                // aksi halde stats'a yanlış sünnet tamamlandı sayılır.
                                if (next == PrayerStatus.kaza) {
                                  record.sunnahs[selectedTime] = _defaultSunnahs(selectedTime);
                                }
                              });
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
                            isEnabled: !(isKaza || isRegl),
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
                          
                          // Kaza veya Regl seçiliyse pasif görünüm
                          final isPassive = isKaza || isRegl;

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
    // Popup kapandıktan sonra namaz bloğundaki pasta grafiklerini güncellemek için tek bir setState
    if (mounted) setState(() {});
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
      onTap: isEnabled
          ? () {
              HapticFeedback.selectionClick();
              onTap();
            }
          : null,
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

  void _showKerahatInfoSheet(BuildContext context) {
    String? selectedSector;
    bool kerahatExpanded = true;
    final kerahatController = ExpansionTileController();
    const double chartSize = 270;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            String? sectorAt(Offset localPos) {
              final center = const Offset(chartSize / 2, chartSize / 2);
              final dx = localPos.dx - center.dx;
              final dy = localPos.dy - center.dy;
              final distance = math.sqrt(dx * dx + dy * dy);
              final innerR = KerahatChartPainter.innerR;
              final outerR = chartSize / 2 - 42;
              if (distance < innerR || distance > outerR + 4) return null;
              double deg = math.atan2(dy, dx) * 180 / math.pi;
              deg = (deg % 360 + 360) % 360;
              if (deg >= 350 || deg < 10) return 'red';
              if (deg < 135) return 'green';
              if (deg < 180) return 'yellow';
              if (deg < 200) return 'red';
              if (deg < 255) return 'green';
              if (deg < 270) return 'red';
              if (deg < 315) return 'green';
              if (deg < 350) return 'blue';
              return null;
            }

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(sheetCtx).size.height * 0.92,
              ),
              padding: const EdgeInsets.only(top: 12, bottom: 24),
              decoration: const BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: AppColors.borderGrey,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Namaz Bilgileri',
                          style: GoogleFonts.nunito(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textDark,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: AppColors.textMid, size: 20),
                          onPressed: () => Navigator.pop(sheetCtx),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Divider(height: 1),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // === İnteraktif Kerahat Çarkı ===
                          Center(
                            child: SizedBox(
                              width: chartSize,
                              height: chartSize,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Positioned.fill(
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTapDown: (details) {
                                        final s = sectorAt(details.localPosition);
                                        if (s == null) return;
                                        HapticFeedback.selectionClick();
                                        if (!kerahatExpanded) {
                                          kerahatController.expand();
                                          kerahatExpanded = true;
                                        }
                                        setSheetState(() => selectedSector = s);
                                      },
                                      child: CustomPaint(
                                        painter: KerahatChartPainter(
                                            highlightSector: selectedSector),
                                      ),
                                    ),
                                  ),
                                  IgnorePointer(
                                    child: Container(
                                      width: 100,
                                      height: 100,
                                      decoration: BoxDecoration(
                                        color: AppColors.white,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.08),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        'NAMAZ ve\nKERAHAT\nVAKİTLERİ',
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.nunito(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.textDark,
                                          height: 1.3,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // === Accordion Kartları ===
                          _buildInfoAccordion(
                            emoji: '🚫',
                            emojiColor: AppColors.errorRed,
                            title: 'Kerahat Kuralları',
                            initiallyExpanded: true,
                            controller: kerahatController,
                            onExpansionChanged: (expanded) {
                              kerahatExpanded = expanded;
                            },
                            content: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'Günün belirli vakitlerinde namaz kılmak ya tamamen yasaktır ya da bazı namazlarla sınırlıdır. Bu zamanlara "kerahat vakitleri" denir.',
                                  style: GoogleFonts.nunito(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textDark,
                                    height: 1.55,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: AppColors.tealLight,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                        color:
                                            AppColors.teal.withValues(alpha: 0.25)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.touch_app_rounded,
                                          size: 16, color: AppColors.teal),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Detayı görmek için yukarıdaki haritada renkli bir alana tıklayın.',
                                          style: GoogleFonts.nunito(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.tealDark,
                                            height: 1.4,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                AnimatedSize(
                                  duration: const Duration(milliseconds: 250),
                                  curve: Curves.easeOutCubic,
                                  child: selectedSector == null
                                      ? const SizedBox(height: 0)
                                      : Padding(
                                          padding: const EdgeInsets.only(top: 12),
                                          child: AnimatedSwitcher(
                                            duration: const Duration(milliseconds: 220),
                                            switchInCurve: Curves.easeOutCubic,
                                            child: _buildSectorContent(
                                              selectedSector!,
                                              key: ValueKey(selectedSector),
                                            ),
                                          ),
                                        ),
                                ),
                              ],
                            ),
                          ),
                          _buildInfoAccordion(
                            emoji: '🕌',
                            emojiColor: AppColors.gold,
                            title: 'Cemaat ile Namaz',
                            content: _buildCemaatContent(sheetCtx),
                          ),
                          _buildInfoAccordion(
                            emoji: '🌅',
                            emojiColor: AppColors.orange,
                            title: 'Sabah Namazının Sünneti',
                            content: _buildSabahSunnetContent(sheetCtx),
                          ),
                          _buildInfoAccordion(
                            emoji: '📿',
                            emojiColor: AppColors.teal,
                            title: 'Neden Her Vakitten Sonra Tesbihat?',
                            content: _buildTesbihatContent(sheetCtx),
                          ),
                          const SizedBox(height: 4),
                          _buildKaynakcaFooter(sheetCtx),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ── Sektör içerik (kırmızı/sarı/yeşil/mavi)
  Widget _buildSectorContent(String sector, {Key? key}) {
    Color color;
    String title;
    String emoji;
    Widget body;
    switch (sector) {
      case 'red':
        color = AppColors.errorRed;
        title = 'Hiçbir Namazın Kılınmadığı 3 Vakit';
        emoji = '🚫';
        body = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bu vakitlerde farz dahil hiçbir namaz kılınmaz:',
              style: GoogleFonts.nunito(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            _bullet('Güneş doğarken — Güneş ufuktan göründüğü andan, gözle bakılamayacak parlaklığa erişene kadar (yaklaşık 45-50 dk).'),
            _bullet('Güneş tam tepedeyken — Öğle ezanından önceki son 10-20 dakika (zeval vakti).'),
            _bullet('Güneş batarken — Güneşin sararıp doğrudan bakılabilir hale gelmesinden batışına kadar (yaklaşık 45-50 dk).'),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.goldSoft.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('⚠️ ', style: TextStyle(fontSize: 14)),
                  Expanded(
                    child: Text(
                      'Tek istisna: O günün ikindi farzı henüz kılınmamışsa, güneş batarken bile sadece o ikindinin farzı kılınabilir. Namazı kasten bu vakte ertelemek günahtır.',
                      style: GoogleFonts.nunito(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
        break;
      case 'yellow':
        color = AppColors.gold;
        title = 'Sabah Vaktinde';
        emoji = '🌅';
        body = Text.rich(
          TextSpan(
            style: GoogleFonts.nunito(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
              height: 1.6,
            ),
            children: [
              const TextSpan(text: 'İmsak vakti girdikten sonra güneş doğana kadar '),
              TextSpan(
                text: 'sadece sabahın iki rekât sünneti',
                style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
              ),
              const TextSpan(text: ' kılınır. Başka nafile namaz yoktur. '),
              TextSpan(
                text: 'Sabahın farzı bu vakit içinde her zaman kılınabilir.',
                style: GoogleFonts.nunito(fontStyle: FontStyle.italic, color: AppColors.textMid),
              ),
            ],
          ),
        );
        break;
      case 'blue':
        color = AppColors.teal;
        title = 'İkindiden Sonra';
        emoji = '🔵';
        body = Text.rich(
          TextSpan(
            style: GoogleFonts.nunito(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
              height: 1.6,
            ),
            children: [
              const TextSpan(text: 'İkindinin farzı kılındıktan sonra, akşam ezanından yaklaşık '),
              TextSpan(
                text: '45 dakika öncesine',
                style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
              ),
              const TextSpan(text: ' kadar '),
              TextSpan(
                text: 'nafile namaz kılınmaz',
                style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
              ),
              const TextSpan(text: '. Ancak bu süre içinde '),
              TextSpan(
                text: 'kaza namazları kılınabilir.',
                style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        );
        break;
      case 'green':
      default:
        color = AppColors.successGreen;
        title = 'Serbest Vakitler';
        emoji = '🟢';
        body = Text(
          'Yukarıdaki kısıtlamalar dışında kalan tüm vakitlerde (Öğle-İkindi arası, Akşam-Yatsı arası, Yatsı-İmsak arası) kaza ve nafile namazlar serbestçe kılınabilir.',
          style: GoogleFonts.nunito(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,
            height: 1.55,
          ),
        );
        break;
    }
    return Container(
      key: key,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(11),
                topRight: Radius.circular(11),
              ),
            ),
            child: Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: body,
          ),
        ],
      ),
    );
  }

  Widget _bullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Container(
              width: 4,
              height: 4,
              decoration: const BoxDecoration(
                color: AppColors.textMid,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.nunito(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Hadis kartı (alıntı bloğu)
  Widget _hadithCard(String text, String source, {Color? accent}) {
    final color = accent ?? AppColors.teal;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.lightGrey,
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text,
            style: GoogleFonts.nunito(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            source,
            style: GoogleFonts.nunito(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textMid,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCemaatContent(BuildContext ctx) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _hadithCard(
          '"Cemaatle kılınan namaz, tek başına kılınan namazdan yirmi yedi derece daha faziletlidir."',
          '— Buhârî, Ezân, 30; Müslim, Mesâcid, 249',
          accent: AppColors.gold,
        ),
        _hadithCard(
          'Resûlullah (sav.) Efendimiz: "—Güçlüklere rağmen abdesti güzelce almak, mescitlere doğru çokça adım atmak ve bir namazdan sonra diğerini gözlemektir. İşte, bekleyeceğiniz en faziletli nöbet (ribât) budur" buyurdu.',
          '— Müslim, Tahâret, 41',
          accent: AppColors.gold,
        ),
        _hadithCard(
          '"Sizden biri, abdestini bozmadan namaz kıldığı yerde oturduğu müddetçe, melekler kendisine: «Allah\'ım, onu bağışla, Allah\'ım ona rahmetinle muamele eyle!» diye dua eder."',
          '— Buhârî, Ezân, 36',
          accent: AppColors.gold,
        ),
        _hadithCard(
          '"İmam Fatiha\'yı bitirip «Âmîn» dediğinde siz de «Âmîn» deyiniz. Kimin âmini meleklerin âmin demesine muvâfık düşerse, onun geçmiş (küçük) günahları mağfiret edilir/örtülür."',
          '— Buhârî, Ezân, 111; Müslim, Salât, 72',
          accent: AppColors.gold,
        ),
        _hadithCard(
          '"Münafıklara sabah ve yatsı namazından daha ağır gelen hiçbir namaz yoktur. Onlar, bu iki namazda ne kadar çok ecir ve sevap olduğunu bilselerdi, emekleyerek de olsa cemaate gelirlerdi."',
          '— Buhârî, Ezân, 34; Müslim, Mesâcid, 252; İbn-i Mâce, Mesâcid, 18',
          accent: AppColors.gold,
        ),
      ],
    );
  }

  Widget _buildSabahSunnetContent(BuildContext ctx) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            'Sabah namazının iki rekât sünneti, Peygamber Efendimiz\'in (sav.) hiç terk etmediği, ümmeti için en kıymetli müekked sünnetlerden biridir.',
            style: GoogleFonts.nunito(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
              height: 1.55,
            ),
          ),
        ),
        _hadithCard(
          '"Sabah namazının iki rek\'at sünneti, dünya ve dünyadaki her şeyden daha hayırlıdır."',
          '— Müslim, Müsâfirîn, 96',
          accent: AppColors.orange,
        ),
      ],
    );
  }

  Widget _buildTesbihatContent(BuildContext ctx) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _hadithCard(
          '"Kim her namazın peşinden otuz üç defa \'Sübhânallah\', otuz üç defa \'Elhamdülillâh\', otuz üç defa \'Allâhü ekber\' der, sonra da yüze tamamlamak için; \'Lâ ilâhe illallâhü vahdehû lâ şerîke leh, lehü\'l-mülkü ve lehü\'l-hamdü ve hüve alâ külli şey\'in kadîr\' derse, günahları deniz köpüğü kadar çok olsa bile affedilir."',
          '— Müslim, Mesâcid, 146; Ebû Dâvûd, Vitir, 24',
          accent: AppColors.teal,
        ),
        _hadithCard(
          'Fakir Muhacirler Resûlullah\'a (sav.) gelerek zengin kardeşlerinin hac, umre, cihad ve sadaka ile yüksek dereceleri aldıklarını söyleyince Efendimiz şöyle buyurdu: "—Size bir şey öğreteyim mi? Onun sayesinde sizi geçenlere yetişir, sizden sonrakileri de geçersiniz. Her namazın peşinden otuz üç defa Sübhânallah, otuz üç defa Elhamdülillâh, otuz üç defa Allâhü ekber dersiniz."',
          '— Buhârî, Ezân, 155; Müslim, Mesâcid, 142',
          accent: AppColors.teal,
        ),
      ],
    );
  }

  Widget _buildKaynakcaFooter(BuildContext ctx) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Icon(Icons.bookmark_border_rounded,
              size: 13, color: AppColors.textLight),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Tüm kaynaklar Ayarlar > Kaynakça bölümündedir.',
              style: GoogleFonts.nunito(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textLight,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoAccordion({
    required String emoji,
    required Color emojiColor,
    required String title,
    required Widget content,
    bool initiallyExpanded = false,
    ExpansionTileController? controller,
    ValueChanged<bool>? onExpansionChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderGrey),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashColor: emojiColor.withValues(alpha: 0.06),
          highlightColor: emojiColor.withValues(alpha: 0.04),
        ),
        child: ExpansionTile(
          controller: controller,
          initiallyExpanded: initiallyExpanded,
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          iconColor: AppColors.textMid,
          collapsedIconColor: AppColors.textMid,
          leading: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: emojiColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(emoji, style: const TextStyle(fontSize: 16)),
          ),
          title: Text(
            title,
            style: GoogleFonts.nunito(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
          onExpansionChanged: (expanded) {
            HapticFeedback.selectionClick();
            onExpansionChanged?.call(expanded);
          },
          children: [content],
        ),
      ),
    );
  }

  Future<void> _fetchMonthData(int year, int month) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    // Aynı ayı tekrar çekme
    final monthKey = 'month_$year-$month';
    if (_fetchedPeriods.contains(monthKey)) return;
    _fetchedPeriods.add(monthKey);

    final today = DateTime.now();
    final todayClean = DateTime(today.year, today.month, today.day);
    if (DateTime(year, month, 1).isAfter(todayClean)) return;

    try {
      // 30 ayrı read yerine tek range sorgusu — çok daha hızlı
      final monthStr = '$year-${month.toString().padLeft(2, '0')}';
      final querySnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('logs')
          .where(FieldPath.documentId, isGreaterThanOrEqualTo: 'prayer_${monthStr}-01')
          .where(FieldPath.documentId, isLessThanOrEqualTo: 'prayer_${monthStr}-31')
          .get();
      bool hasChanges = false;
      for (var doc in querySnap.docs) {
        final data = doc.data();
        final rawDate = data['date'] as String? ?? '';
        final dateStr = rawDate.replaceAll('prayer_', '');
        if (dateStr.isEmpty) continue;
        final parts = dateStr.split('-');
        if (parts.length != 3) continue;
        final d = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
        if (d.isAfter(todayClean)) continue;
        final Map<String, dynamic> pMap = data['prayers'] ?? {};
        final Map<String, dynamic> tMap = data['tesbihats'] ?? {};
        final Map<String, dynamic> sMap = data['sunnahs'] ?? {};
        List<bool> getSunnahList(PrayerTime pt, String key) {
          if (sMap[key] != null) return List<bool>.from(sMap[key]);
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
          },
        );
        hasChanges = true;
      }
      if (hasChanges && mounted) setState(() {});
    } catch (e) {
      debugPrint("Error fetching month: $e");
    }
  }

  void _showMonthlyViewSheet(BuildContext context) {
    final cinsiyet = context.read<UserProvider>().cinsiyet ?? 'bey';
    final now = DateTime.now();
    int displayYear = now.year;
    int displayMonth = now.month;
    bool initialFetched = false;
    bool isMonthLoading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            Future<void> ensureMonthLoaded() async {
              final monthKey = 'month_$displayYear-$displayMonth';
              final alreadyFetched = _fetchedPeriods.contains(monthKey);

              if (!alreadyFetched) {
                isMonthLoading = true;
                if (sheetCtx.mounted) setSheetState(() {});
                await _fetchMonthData(displayYear, displayMonth);
                if (!sheetCtx.mounted) return;
                isMonthLoading = false;
                setSheetState(() {});
              } else {
                if (sheetCtx.mounted) setSheetState(() {});
              }
            }

            if (!initialFetched) {
              initialFetched = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                ensureMonthLoaded();
              });
            }

            final isCurrentMonth =
                displayYear == now.year && displayMonth == now.month;

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(sheetCtx).size.height * 0.85,
              ),
              padding: const EdgeInsets.only(top: 12, bottom: 20),
              decoration: const BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: AppColors.borderGrey,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  SizedBox(
                    height: 40,
                    width: double.infinity,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 220,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: () {
                                  setSheetState(() {
                                    displayMonth--;
                                    if (displayMonth < 1) {
                                      displayMonth = 12;
                                      displayYear--;
                                    }
                                  });
                                  ensureMonthLoaded();
                                },
                                child: const Padding(
                                  padding: EdgeInsets.all(6),
                                  child: Icon(Icons.chevron_left_rounded,
                                      color: AppColors.textDark, size: 22),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  '${_getMonthName(displayMonth)} $displayYear',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.nunito(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textDark,
                                  ),
                                ),
                              ),
                              isCurrentMonth
                                  ? const SizedBox(width: 34)
                                  : InkWell(
                                      borderRadius: BorderRadius.circular(20),
                                      onTap: () {
                                        setSheetState(() {
                                          displayMonth++;
                                          if (displayMonth > 12) {
                                            displayMonth = 1;
                                            displayYear++;
                                          }
                                        });
                                        ensureMonthLoaded();
                                      },
                                      child: const Padding(
                                        padding: EdgeInsets.all(6),
                                        child: Icon(Icons.chevron_right_rounded,
                                            color: AppColors.textDark, size: 22),
                                      ),
                                    ),
                            ],
                          ),
                        ),
                        Positioned(
                          right: 16,
                          child: IconButton(
                            icon: const Icon(Icons.close,
                                color: AppColors.textMid, size: 20),
                            onPressed: () => Navigator.pop(sheetCtx),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Divider(height: 1),
                  Flexible(
                    child: SingleChildScrollView(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onHorizontalDragEnd: (details) {
                          final v = details.primaryVelocity ?? 0;
                          if (v.abs() < 200) return;
                          if (v > 0) {
                            setSheetState(() {
                              displayMonth--;
                              if (displayMonth < 1) {
                                displayMonth = 12;
                                displayYear--;
                              }
                            });
                            ensureMonthLoaded();
                          } else if (!isCurrentMonth) {
                            setSheetState(() {
                              displayMonth++;
                              if (displayMonth > 12) {
                                displayMonth = 1;
                                displayYear++;
                              }
                            });
                            ensureMonthLoaded();
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                          child: Column(
                            children: [
                              _buildMonthlyStats(
                                  displayYear, displayMonth, cinsiyet,
                                  isLoading: isMonthLoading),
                              const SizedBox(height: 10),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                child: Row(
                                  children: ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz']
                                      .map((d) => Expanded(
                                            child: Text(
                                              d,
                                              textAlign: TextAlign.center,
                                              style: GoogleFonts.nunito(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.textLight,
                                              ),
                                            ),
                                          ))
                                      .toList(),
                                ),
                              ),
                              _buildMonthlyGrid(
                                  displayYear,
                                  displayMonth,
                                  cinsiyet,
                                  sheetCtx,
                                  () => setSheetState(() {})),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMonthlyStats(int year, int month, String cinsiyet, {bool isLoading = false}) {
    final today = DateTime.now();
    final todayClean = DateTime(today.year, today.month, today.day);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final isCurrentMonth = year == today.year && month == today.month;
    final lastDay = isCurrentMonth ? today.day : daysInMonth;

    int eligiblePrayers = 0;
    int onTimeCount = 0;
    int cemaatCount = 0;
    int doneSunnahs = 0;
    int eligibleSunnahs = 0;
    int doneTesbihats = 0;
    int eligibleTesbihats = 0;

    for (int day = 1; day <= lastDay; day++) {
      final d = DateTime(year, month, day);
      if (d.isAfter(todayClean)) continue;
      final cleanD = DateTime(d.year, d.month, d.day);
      final record = _allRecords[cleanD];
      if (record == null) {
        // Default eligible (kayıt yoksa hiçbiri tamamlanmamış)
        eligiblePrayers += 5;
        // Sünnet sayısı (Vitir hariç): 1+2+1+1+2 = 7
        eligibleSunnahs += 7;
        eligibleTesbihats += 5;
        continue;
      }

      for (var time in PrayerTime.values) {
        final status = record.prayers[time] ?? PrayerStatus.none;
        if (status == PrayerStatus.regl) continue; // hanım için muaf, sayıma alınmaz
        eligiblePrayers += 1;
        if (status == PrayerStatus.onTime || status == PrayerStatus.cemaat) {
          onTimeCount += 1;
        }
        if (status == PrayerStatus.cemaat) cemaatCount += 1;

        // Sünnetler — Vitir hariç (yatsı'da son eleman)
        final sunnahList = record.sunnahs[time] ?? [];
        final names = _getSunnahNames(time);
        for (int i = 0; i < sunnahList.length; i++) {
          if (names[i] == 'Vitir') continue;
          eligibleSunnahs += 1;
          if (sunnahList[i]) doneSunnahs += 1;
        }

        // Tesbihat
        eligibleTesbihats += 1;
        if (record.tesbihats[time] == true) doneTesbihats += 1;
      }
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.lightGrey,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            child: isLoading
                ? Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: AppColors.teal,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Hesaplanıyor…',
                          style: GoogleFonts.nunito(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textMid,
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          Row(
            children: [
              Expanded(
                child: _gaugeCell(
                  label: 'Vaktinde',
                  done: onTimeCount,
                  total: eligiblePrayers,
                  detail: '$onTimeCount/$eligiblePrayers',
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _gaugeCell(
                  label: 'Cemaat',
                  done: cemaatCount,
                  total: eligiblePrayers,
                  detail: '$cemaatCount/$eligiblePrayers',
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _gaugeCell(
                  label: 'Sünnet',
                  done: doneSunnahs,
                  total: eligibleSunnahs,
                  detail: '$doneSunnahs/$eligibleSunnahs',
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _gaugeCell(
                  label: 'Tesbihat',
                  done: doneTesbihats,
                  total: eligibleTesbihats,
                  detail: '$doneTesbihats/$eligibleTesbihats',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _gaugeColorFor(int pctInt) {
    if (pctInt < 50) return AppColors.errorRed;
    if (pctInt < 70) return AppColors.orange;
    if (pctInt < 85) return AppColors.gold;
    return AppColors.successGreen;
  }

  Widget _gaugeCell({
    required String label,
    required int done,
    required int total,
    required String detail,
  }) {
    final hasData = total > 0;
    final ratio = hasData ? (done / total).clamp(0.0, 1.0) : 0.0;
    final pctInt = (ratio * 100).round();
    final ringColor =
        hasData ? _gaugeColorFor(pctInt) : AppColors.borderGrey;

    return Semantics(
      label: '$label %$pctInt — $detail',
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderGrey),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 36,
              height: 36,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: hasData ? ratio : 0.0),
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOutCubic,
                builder: (context, animValue, _) {
                  return Stack(
                    fit: StackFit.expand,
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        painter: _RingGaugePainter(
                          progress: animValue,
                          color: ringColor,
                          backgroundColor:
                              AppColors.borderGrey.withValues(alpha: 0.45),
                          strokeWidth: 4.0,
                        ),
                      ),
                      Center(
                        child: Text(
                          hasData ? '%${(animValue * 100).round()}' : '—',
                          style: GoogleFonts.nunito(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textDark,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 8.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textLight,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyGrid(int year, int month, String cinsiyet, BuildContext sheetCtx, VoidCallback onRecordChanged) {
    final firstDay = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final leadingEmpty = firstDay.weekday - 1; // Pzt=1
    final totalCells = leadingEmpty + daysInMonth;
    final rows = (totalCells / 7).ceil();

    final today = DateTime.now();
    final todayClean = DateTime(today.year, today.month, today.day);

    return Column(
      children: List.generate(rows, (rowIdx) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: List.generate(7, (colIdx) {
              final cellIdx = rowIdx * 7 + colIdx;
              final dayNum = cellIdx - leadingEmpty + 1;

              if (dayNum < 1 || dayNum > daysInMonth) {
                return const Expanded(child: SizedBox(height: 44));
              }

              final cellDate = DateTime(year, month, dayNum);
              final cellClean = DateTime(cellDate.year, cellDate.month, cellDate.day);
              final isFuture = cellClean.isAfter(todayClean);
              final isToday = cellClean.isAtSameMomentAs(todayClean);
              final record = _getRecordForDate(cellDate);

              return Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: isFuture
                      ? null
                      : () async {
                          HapticFeedback.selectionClick();
                          await _showPrayerPopup(record);
                          if (!sheetCtx.mounted) return;
                          onRecordChanged();
                        },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Opacity(
                      opacity: isFuture ? 0.35 : 1.0,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$dayNum',
                            style: GoogleFonts.nunito(
                              fontSize: 9.5,
                              fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                              color: isToday ? AppColors.teal : AppColors.textLight,
                            ),
                          ),
                          const SizedBox(height: 2),
                          SizedBox(
                            width: 30,
                            height: 30,
                            child: CustomPaint(
                              painter: PrayerPieChartPainter(
                                record.prayers,
                                cinsiyet,
                                record.tesbihats,
                                record.sunnahs,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        );
      }),
    );
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
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: GestureDetector(
                behavior: HitTestBehavior.deferToChild,
                onHorizontalDragEnd: (details) {
                  final v = details.primaryVelocity ?? 0;
                  if (v.abs() < 200) return;
                  if (v > 0) {
                    _pageController.previousPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  } else if (_weekOffset < 0) {
                    _pageController.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  }
                },
                child: Container(
                padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
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
                      padding: const EdgeInsets.symmetric(horizontal: 6.0),
                      child: Row(
                        children: [
                          // Sol: chevron + küçük ay yazısı (önceki hafta)
                          Expanded(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                InkWell(
                                  borderRadius: BorderRadius.circular(20),
                                  onTap: () {
                                    _pageController.previousPage(
                                      duration: const Duration(milliseconds: 300),
                                      curve: Curves.easeInOut,
                                    );
                                  },
                                  child: const Padding(
                                    padding: EdgeInsets.all(6),
                                    child: Icon(Icons.chevron_left_rounded,
                                        size: 20, color: AppColors.textMid),
                                  ),
                                ),
                                InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: () => _showMonthlyViewSheet(context),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 4, vertical: 4),
                                    child: AnimatedSwitcher(
                                      duration: const Duration(milliseconds: 300),
                                      child: Text(
                                        currentMonthText,
                                        key: ValueKey(currentMonthText),
                                        style: GoogleFonts.nunito(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textLight,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Orta: Başlık + info ikonu
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Namaz Takibi',
                                style: GoogleFonts.nunito(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textDark,
                                ),
                              ),
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: () => _showKerahatInfoSheet(context),
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: const BoxDecoration(
                                    color: AppColors.tealLight,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.info_outline,
                                    size: 12,
                                    color: AppColors.teal,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          // Sağ: aylık takvim ikonu + (geçmişteyse) sağ chevron
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                InkWell(
                                  borderRadius: BorderRadius.circular(20),
                                  onTap: () => _showMonthlyViewSheet(context),
                                  child: const Padding(
                                    padding: EdgeInsets.all(6),
                                    child: Icon(
                                      Icons.calendar_month_rounded,
                                      size: 18,
                                      color: AppColors.teal,
                                    ),
                                  ),
                                ),
                                if (_weekOffset < 0)
                                  InkWell(
                                    borderRadius: BorderRadius.circular(20),
                                    onTap: () {
                                      _pageController.nextPage(
                                        duration: const Duration(milliseconds: 300),
                                        curve: Curves.easeInOut,
                                      );
                                    },
                                    child: const Padding(
                                      padding: EdgeInsets.all(6),
                                      child: Icon(Icons.chevron_right_rounded,
                                          size: 20, color: AppColors.textMid),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                        SizedBox(
                          height: 78,
                          child: PageView.builder(
                            controller: _pageController,
                            itemCount: _initialPage + 1,
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
                                        HapticFeedback.selectionClick();
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
                ),
              ),
            ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabBarDelegate(
              TabBar(
                controller: _tabController,
                indicatorColor: AppColors.teal,
                labelColor: AppColors.teal,
                unselectedLabelColor: AppColors.textMid,
                indicatorSize: TabBarIndicatorSize.tab,
                labelStyle: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w800),
                unselectedLabelStyle: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w600),
                tabs: const [
                  Tab(text: 'Alışkanlıklarım'),
                  Tab(text: 'Virdlerim'),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: const HabitTrackerWidget(),
            ),
            const VirdlerimContentWidget(),
          ],
        ),
      ),
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  _TabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Material(color: AppColors.white, child: tabBar);
  }

  @override
  bool shouldRebuild(_TabBarDelegate oldDelegate) => tabBar != oldDelegate.tabBar;
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

class _RingGaugePainter extends CustomPainter {
  final double progress; // 0.0 .. 1.0
  final Color color;
  final Color backgroundColor;
  final double strokeWidth;

  _RingGaugePainter({
    required this.progress,
    required this.color,
    required this.backgroundColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) / 2) - strokeWidth / 2;

    final bgPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = backgroundColor;
    canvas.drawCircle(center, radius, bgPaint);

    if (progress <= 0) return;

    final fgPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = color;
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * progress, false, fgPaint);
  }

  @override
  bool shouldRepaint(covariant _RingGaugePainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.backgroundColor != backgroundColor ||
      old.strokeWidth != strokeWidth;
}

class KerahatChartPainter extends CustomPainter {
  final String? highlightSector; // 'red' | 'yellow' | 'green' | 'blue' | null

  KerahatChartPainter({this.highlightSector});

  static const double innerR = 50; // iç delik (orta beyaz dairenin yarıçapı)

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.width / 2 - 42; // dış kenardan iç boşluk (etiketler için)
    final innerRadius = innerR;

    double toRad(double deg) => deg * math.pi / 180;

    Path donutSectorPath(double startDeg, double sweepDeg) {
      final outerRect = Rect.fromCircle(center: center, radius: outerRadius);
      final innerRect = Rect.fromCircle(center: center, radius: innerRadius);
      final startOuter = Offset(
        center.dx + outerRadius * math.cos(toRad(startDeg)),
        center.dy + outerRadius * math.sin(toRad(startDeg)),
      );
      return Path()
        ..moveTo(startOuter.dx, startOuter.dy)
        ..arcTo(outerRect, toRad(startDeg), toRad(sweepDeg), false)
        ..arcTo(innerRect, toRad(startDeg + sweepDeg), -toRad(sweepDeg), false)
        ..close();
    }

    void drawSector(double startDeg, double sweepDeg, Color fillColor, Color borderColor, {String? sectorKey}) {
      final isHighlighted = highlightSector != null && sectorKey == highlightSector;
      final fillPaint = Paint()
        ..color = isHighlighted ? borderColor.withValues(alpha: 0.32) : fillColor
        ..style = PaintingStyle.fill;
      final borderPaint = Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = isHighlighted ? 2.6 : 2.0
        ..strokeJoin = StrokeJoin.round;
      final path = donutSectorPath(startDeg, sweepDeg);
      canvas.drawPath(path, fillPaint);
      canvas.drawPath(path, borderPaint);
    }

    // Sektörler (vakit sınırları)
    drawSector(-10, 20, AppColors.errorRed.withValues(alpha: 0.15), AppColors.errorRed, sectorKey: 'red');
    drawSector(10, 125, AppColors.successGreen.withValues(alpha: 0.15), AppColors.successGreen, sectorKey: 'green');
    drawSector(135, 45, AppColors.goldSoft.withValues(alpha: 0.25), AppColors.gold, sectorKey: 'yellow');
    drawSector(180, 20, AppColors.errorRed.withValues(alpha: 0.15), AppColors.errorRed, sectorKey: 'red');
    drawSector(200, 55, AppColors.successGreen.withValues(alpha: 0.15), AppColors.successGreen, sectorKey: 'green');
    drawSector(255, 15, AppColors.errorRed.withValues(alpha: 0.15), AppColors.errorRed, sectorKey: 'red');
    drawSector(270, 45, AppColors.successGreen.withValues(alpha: 0.15), AppColors.successGreen, sectorKey: 'green');
    drawSector(315, 35, AppColors.tealSoft.withValues(alpha: 0.25), AppColors.teal, sectorKey: 'blue');

    // Vakit etiketleri — sektör sınırları (vakit başlangıçları)
    final labelRadius = outerRadius + 18;
    void drawLabel(String text, double angleDeg) {
      final angle = toRad(angleDeg);
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: GoogleFonts.nunito(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            color: AppColors.textDark,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final x = center.dx + labelRadius * math.cos(angle) - tp.width / 2;
      final y = center.dy + labelRadius * math.sin(angle) - tp.height / 2;
      tp.paint(canvas, Offset(x, y));
    }

    drawLabel('Öğle', 270);
    drawLabel('İkindi', 315);
    drawLabel('Akşam', -10);
    drawLabel('Yatsı', 10);
    drawLabel('İmsak', 135);
    drawLabel('Güneş', 180);
  }

  @override
  bool shouldRepaint(covariant KerahatChartPainter old) =>
      old.highlightSector != highlightSector;
}
