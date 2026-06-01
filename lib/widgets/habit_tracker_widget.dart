import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../app_colors.dart';
import 'habit_heat_map_sheet.dart';

class HabitDef {
  final String id;
  final String title;
  final Color color;
  final DateTime createdAt;

  HabitDef({
    required this.id,
    required this.title,
    required this.color,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'color': color.value,
    'createdAt': '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}',
  };

  factory HabitDef.fromMap(Map<String, dynamic> map) {
    DateTime? createdAt;
    if (map['createdAt'] is String) {
      final parts = (map['createdAt'] as String).split('-');
      if (parts.length == 3) {
        createdAt = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
      }
    }
    return HabitDef(
      id: map['id'] as String,
      title: map['title'] as String,
      color: Color(map['color'] as int),
      createdAt: createdAt,
    );
  }
}

class HabitTrackerWidget extends StatefulWidget {
  const HabitTrackerWidget({super.key});

  @override
  State<HabitTrackerWidget> createState() => _HabitTrackerWidgetState();
}

class _HabitTrackerWidgetState extends State<HabitTrackerWidget>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  bool _isLoading = true;
  List<HabitDef> _habits = [];
  bool _showCompletedHabits = false;
  
  // dateStr -> { habitId: bool }
  final Map<String, Map<String, bool>> _logs = {};

  final String? _uid = FirebaseAuth.instance.currentUser?.uid;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _syncDateWithOffset();
    _fetchData();
  }

  void _syncDateWithOffset() {
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
  }

  Future<void> _fetchData() async {
    if (_uid == null) return;
    setState(() => _isLoading = true);

    try {
      // 1. Fetch Habit Defs
      final defsDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .collection('logs')
          .doc('habit_defs')
          .get();

      if (defsDoc.exists) {
        final List<dynamic> items = defsDoc.data()?['items'] ?? [];
        _habits = items.map((e) => HabitDef.fromMap(e as Map<String, dynamic>)).toList();
      }

      // 2. Fetch Logs for last 30 days
      final logsSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .collection('logs')
          .where('type', isEqualTo: 'habit_log')
          .get();

      _logs.clear();
      for (var doc in logsSnap.docs) {
        final data = doc.data();
        final dateStr = data['date'] as String;
        final comps = data['completions'] as Map<String, dynamic>? ?? {};
        
        _logs[dateStr] = {};
        comps.forEach((k, v) {
          _logs[dateStr]![k] = v as bool;
        });
      }
    } catch (e) {
      debugPrint("Error fetching habits: \$e");
    }

    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  Future<void> _toggleHabit(HabitDef habit) async {
    if (_uid == null) return;

    // Alışkanlık oluşturulmadan önceki tarihlere log girişini engelle
    final createdDay = DateTime(habit.createdAt.year, habit.createdAt.month, habit.createdAt.day);
    final selDay = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    if (selDay.isBefore(createdDay)) return;

    final dateStr = "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}";

    // Optimistic Update
    final currentStatus = _logs[dateStr]?[habit.id] ?? false;
    final newStatus = !currentStatus;

    setState(() {
      if (_logs[dateStr] == null) _logs[dateStr] = {};
      _logs[dateStr]![habit.id] = newStatus;
    });

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .collection('logs')
          .doc('habit_log_$dateStr')
          .set({
            'type': 'habit_log',
            'date': dateStr,
            'completions': _logs[dateStr]
          }, SetOptions(merge: true));
    } catch (e) {
      debugPrint("Error updating habit: $e");
    }
  }

  void _showAddHabitSheet() {
    String newTitle = '';
    Color selectedColor = AppColors.teal;
    final colors = [
      // 1. Kırmızı & Mercan Tonları
      const Color(0xFFE63946), // Premium Kırmızı
      const Color(0xFFD63031), // Klasik Koyu Kırmızı
      const Color(0xFFF07167), // Pastel Mercan
      const Color(0xFFE07A5F), // Sıcak Kiremit

      // 2. Turuncu & Altın Tonları
      AppColors.orange,        // Canlı Turuncu
      const Color(0xFFF4A261), // Pastel Şeftali
      AppColors.gold,          // Canlı Altın
      const Color(0xFFE9C46A), // Hardal Kum Sarısı

      // 3. Yeşil Tonları
      AppColors.emeraldGreen,  // Zümrüt Yeşili
      const Color(0xFF2A9D8F), // Çam Yeşili
      const Color(0xFF4CAF50), // Doğa Yeşili
      const Color(0xFF81B29A), // Adaçayı Yeşili

      // 4. Mavi & Turkuaz Tonları
      AppColors.teal,          // Uygulama Teali
      const Color(0xFF00B4D8), // Okyanus Mavisi
      AppColors.infoBlue,      // Gökyüzü Mavisi
      const Color(0xFF4361EE), // Kraliyet Mavisi

      // 5. Mor & Pembe Tonları
      const Color(0xFF7209B7), // Premium Mor
      const Color(0xFF9B5DE5), // Lavanta
      const Color(0xFFB5179E), // Canlı Magenta
      const Color(0xFFFF85A1), // Gül Pembesi
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                top: 24, left: 24, right: 24
              ),
              decoration: const BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Yeni Alışkanlık Ekle',
                    style: GoogleFonts.nunito(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    autofocus: true,
                    textInputAction: TextInputAction.done,
                    maxLength: 50,
                    onSubmitted: (val) {
                      newTitle = val;
                      if (newTitle.trim().isEmpty) return;
                      Navigator.pop(ctx);
                      _addNewHabit(newTitle.trim(), selectedColor);
                    },
                    decoration: InputDecoration(
                      hintText: 'Örn: Sabah Yürüyüşü',
                      filled: true,
                      fillColor: AppColors.lightGrey,
                      counterText: '',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (val) => newTitle = val,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Renk Seçin',
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMid,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: colors.map((c) {
                      final isSelected = c.value == selectedColor.value;
                      return GestureDetector(
                        onTap: () => setModalState(() => selectedColor = c),
                        child: Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: isSelected ? Border.all(color: AppColors.textDark, width: 3) : null,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.teal,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        if (newTitle.trim().isEmpty) return;
                        Navigator.pop(ctx);
                        _addNewHabit(newTitle.trim(), selectedColor);
                      },
                      child: Text(
                        'Ekle',
                        style: GoogleFonts.nunito(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  )
                ],
              ),
            );
          }
        );
      }
    );
  }

  Future<void> _addNewHabit(String title, Color color) async {
    if (_uid == null) return;
    
    final newHabit = HabitDef(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      color: color,
      createdAt: DateTime.now(),
    );

    setState(() {
      _habits.add(newHabit);
    });

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .collection('logs')
          .doc('habit_defs')
          .set({
            'type': 'habit_defs',
            'items': _habits.map((e) => e.toMap()).toList()
          });
    } catch (e) {
      debugPrint("Error saving habit def: \$e");
    }
  }


  Future<void> _deleteHabit(HabitDef habit) async {
    if (_uid == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Sil', style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
        content: Text(
          '"${habit.title}" alışkanlığını silmek istediğinize emin misiniz?\nTüm geçmiş veriler de silinecek.',
          style: GoogleFonts.nunito(color: AppColors.textMid),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('İptal', style: GoogleFonts.nunito(color: AppColors.textMid)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.errorRed,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Sil', style: GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;
    setState(() => _habits.removeWhere((h) => h.id == habit.id));
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .collection('logs')
          .doc('habit_defs')
          .set({
            'type': 'habit_defs',
            'items': _habits.map((e) => e.toMap()).toList()
          });
    } catch (e) {
      debugPrint('Error deleting habit: $e');
    }
  }

  Future<void> _renameHabit(HabitDef habit) async {
    final ctrl = TextEditingController(text: habit.title);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Adı Düzenle', style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textInputAction: TextInputAction.done,
          maxLength: 50,
          onSubmitted: (val) {
            if (val.trim().isNotEmpty) Navigator.pop(ctx, val.trim());
          },
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.lightGrey,
            counterText: '',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('İptal', style: GoogleFonts.nunito(color: AppColors.textMid)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.teal,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: Text('Kaydet', style: GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (newName == null || newName.isEmpty) return;
    if (!mounted) return;
    final idx = _habits.indexWhere((h) => h.id == habit.id);
    if (idx == -1) return;
    setState(() {
      _habits[idx] = HabitDef(id: habit.id, title: newName, color: habit.color);
    });
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .collection('logs')
          .doc('habit_defs')
          .set({
            'type': 'habit_defs',
            'items': _habits.map((e) => e.toMap()).toList()
          });
    } catch (e) {
      debugPrint('Error renaming habit: $e');
    }
  }

  Future<void> _changeHabitColor(HabitDef habit) async {
    if (_uid == null) return;
    Color selectedColor = habit.color;
    final colors = [
      // 1. Kırmızı & Mercan Tonları
      const Color(0xFFE63946), // Premium Kırmızı
      const Color(0xFFD63031), // Klasik Koyu Kırmızı
      const Color(0xFFF07167), // Pastel Mercan
      const Color(0xFFE07A5F), // Sıcak Kiremit

      // 2. Turuncu & Altın Tonları
      AppColors.orange,        // Canlı Turuncu
      const Color(0xFFF4A261), // Pastel Şeftali
      AppColors.gold,          // Canlı Altın
      const Color(0xFFE9C46A), // Hardal Kum Sarısı

      // 3. Yeşil Tonları
      AppColors.emeraldGreen,  // Zümrüt Yeşili
      const Color(0xFF2A9D8F), // Çam Yeşili
      const Color(0xFF4CAF50), // Doğa Yeşili
      const Color(0xFF81B29A), // Adaçayı Yeşili

      // 4. Mavi & Turkuaz Tonları
      AppColors.teal,          // Uygulama Teali
      const Color(0xFF00B4D8), // Okyanus Mavisi
      AppColors.infoBlue,      // Gökyüzü Mavisi
      const Color(0xFF4361EE), // Kraliyet Mavisi

      // 5. Mor & Pembe Tonları
      const Color(0xFF7209B7), // Premium Mor
      const Color(0xFF9B5DE5), // Lavanta
      const Color(0xFFB5179E), // Canlı Magenta
      const Color(0xFFFF85A1), // Gül Pembesi
    ];

    final newColor = await showDialog<Color>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Renk Seçin', style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '"${habit.title}" için yeni bir renk belirleyin.',
                style: GoogleFonts.nunito(color: AppColors.textMid, fontSize: 13),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: colors.map((c) {
                  final isSelected = c.value == selectedColor.value;
                  return GestureDetector(
                    onTap: () => setModalState(() => selectedColor = c),
                    child: Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: isSelected ? Border.all(color: AppColors.textDark, width: 2.5) : null,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('İptal', style: GoogleFonts.nunito(color: AppColors.textMid)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.teal,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.pop(ctx, selectedColor),
              child: Text('Kaydet', style: GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );

    if (newColor == null) return;
    if (!mounted) return;

    final idx = _habits.indexWhere((h) => h.id == habit.id);
    if (idx == -1) return;

    setState(() {
      _habits[idx] = HabitDef(
        id: habit.id,
        title: habit.title,
        color: newColor,
        createdAt: habit.createdAt,
      );
    });

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .collection('logs')
          .doc('habit_defs')
          .set({
            'type': 'habit_defs',
            'items': _habits.map((e) => e.toMap()).toList()
          });
    } catch (e) {
      debugPrint('Error updating habit color: $e');
    }
  }

  int _calculateStreak(String habitId) {
    int streak = 0;
    final today = DateTime.now();
    
    // Geçmişe doğru kontrol et
    for (int i = 0; i < 30; i++) {
      final d = today.subtract(Duration(days: i));
      final dateStr = "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
      
      final isDone = _logs[dateStr]?[habitId] ?? false;
      if (isDone) {
        streak++;
      } else {
        // Eğer bugünün verisi yoksa ama dününki varsa seriyi kırma
        if (i == 0) continue; 
        break;
      }
    }
    return streak;
  }

  Widget _buildHabitRow(
    HabitDef habit, {
    required bool isLast,
    required bool isDoneToday,
    required DateTime selDay,
    required DateTime today,
    required String selectedStr,
  }) {
    final createdDay = DateTime(habit.createdAt.year, habit.createdAt.month, habit.createdAt.day);
    final isInactive = selDay.isBefore(createdDay);
    final streak = _calculateStreak(habit.id);
    final todayClean = DateTime(today.year, today.month, today.day);

    int weekCompletions = 0;
    final monday = _selectedDate.subtract(Duration(days: _selectedDate.weekday - 1));
    for (int i = 0; i < 7; i++) {
      final d = monday.add(Duration(days: i));
      final dStr = "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
      if (_logs[dStr]?[habit.id] == true) weekCompletions++;
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
      child: Opacity(
        opacity: isInactive ? 0.38 : 1.0,
        child: InkWell(
          onTap: () {
            final Set<String> completedStrs = {};
            _logs.forEach((date, comps) {
              if (comps[habit.id] == true) completedStrs.add(date);
            });
            HabitHeatMapSheet.show(
              context,
              habit: habit,
              completedDateStrs: completedStrs,
              currentStreak: streak,
              createdAt: habit.createdAt,
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
            child: Row(
              children: [
                // Yuvarlak Habit İkonu (virdlerim stili)
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isDoneToday
                        ? habit.color.withValues(alpha: 0.05)
                        : habit.color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.star_rounded,
                    color: isDoneToday
                        ? habit.color.withValues(alpha: 0.45)
                        : habit.color,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 12),
                // Orta Kısım: Başlık ve İstatistikler
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        habit.title,
                        style: GoogleFonts.nunito(
                          fontSize: 14.0,
                          fontWeight: FontWeight.w700,
                          color: isDoneToday ? AppColors.textLight : AppColors.textDark,
                          decoration: isDoneToday ? TextDecoration.lineThrough : null,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      if (isInactive)
                        Text(
                          'Bu gün henüz eklenmemişti',
                          style: GoogleFonts.nunito(
                            fontSize: 10.0,
                            color: AppColors.textLight,
                            fontStyle: FontStyle.italic,
                          ),
                        )
                      else
                        Row(
                          children: [
                            Text(
                              "Bu Hafta: $weekCompletions/7",
                              style: GoogleFonts.nunito(
                                fontSize: 10.0,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textLight,
                              ),
                            ),
                            if (streak > 0) ...[
                              const SizedBox(width: 6),
                              Text(
                                '•',
                                style: TextStyle(
                                  fontSize: 8,
                                  color: AppColors.textLight.withValues(alpha: 0.5),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                "🔥 $streak",
                                style: GoogleFonts.nunito(
                                  fontSize: 10.0,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.orange,
                                ),
                              ),
                            ],
                          ],
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // 7 günlük haftalık takip noktaları
                if (!isInactive) ...[
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(7, (index) {
                      final d = monday.add(Duration(days: index));
                      final createdDayOnDot = DateTime(habit.createdAt.year, habit.createdAt.month, habit.createdAt.day);
                      final dCleanOnDot = DateTime(d.year, d.month, d.day);
                      final isInactiveOnDay = dCleanOnDot.isBefore(createdDayOnDot);
                      
                      final dStr = "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
                      final isDone = !isInactiveOnDay && (_logs[dStr]?[habit.id] ?? false);
                      
                      final isSelectedDay = dCleanOnDot.year == _selectedDate.year &&
                                            dCleanOnDot.month == _selectedDate.month &&
                                            dCleanOnDot.day == _selectedDate.day;
                      
                      Color dotColor;
                      if (isInactiveOnDay) {
                        dotColor = Colors.transparent;
                      } else if (dCleanOnDot.isAfter(todayClean)) {
                        dotColor = Colors.transparent;
                      } else if (isDone) {
                        dotColor = const Color(0xFF52B788); // Yeşil
                      } else {
                        if (dCleanOnDot == todayClean) {
                          dotColor = AppColors.borderGrey.withValues(alpha: 0.6); // Bugün
                        } else {
                          dotColor = const Color(0xFFF28482).withValues(alpha: 0.7); // Geçmiş yapılmamış
                        }
                      }
                      
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 1.5),
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: dotColor,
                          shape: BoxShape.circle,
                          border: isSelectedDay
                              ? Border.all(color: AppColors.textDark.withValues(alpha: 0.45), width: 1.2)
                              : (isInactiveOnDay || dCleanOnDot.isAfter(todayClean)
                                  ? Border.all(color: AppColors.borderGrey, width: 1.0)
                                  : null),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(width: 10),
                ],
                // İşaretleme butonu (virdlerim stili)
                if (!isInactive)
                  GestureDetector(
                    onTap: () => _toggleHabit(habit),
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDoneToday ? habit.color : Colors.white,
                        border: Border.all(
                          color: isDoneToday ? habit.color : AppColors.borderGrey,
                          width: 1.8,
                        ),
                      ),
                      child: isDoneToday
                        ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
                        : null,
                    ),
                  ),
                const SizedBox(width: 4),
                // Üç nokta menüsü
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, color: AppColors.textLight, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onSelected: (value) {
                    if (value == 'rename') _renameHabit(habit);
                    if (value == 'change_color') _changeHabitColor(habit);
                    if (value == 'delete') _deleteHabit(habit);
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'rename',
                      child: Row(
                        children: [
                          const Icon(Icons.edit_outlined, size: 18, color: AppColors.textMid),
                          const SizedBox(width: 10),
                          Text('Adı Düzenle', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'change_color',
                      child: Row(
                        children: [
                          const Icon(Icons.palette_outlined, size: 18, color: AppColors.textMid),
                          const SizedBox(width: 10),
                          Text('Renk Değiştir', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          const Icon(Icons.delete_outline, size: 18, color: AppColors.errorRed),
                          const SizedBox(width: 10),
                          Text('Sil', style: GoogleFonts.nunito(fontWeight: FontWeight.w700, color: AppColors.errorRed)),
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

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(32.0),
        child: Center(child: CircularProgressIndicator(color: AppColors.teal)),
      );
    }

    final today = DateTime.now();
    final selectedStr = "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}";

    final selDay = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);

    // Seçili tarihte aktif olan alışkanlıklar (createdAt <= selectedDate)
    final activeHabits = _habits.where((h) {
      final c = DateTime(h.createdAt.year, h.createdAt.month, h.createdAt.day);
      return !c.isAfter(selDay);
    }).toList();

    // Virdlerim tarzı yapılacak/tamamlanan ayrımı
    final List<HabitDef> todo = [];
    final List<HabitDef> done = [];
    for (var habit in activeHabits) {
      final isDoneToday = (_logs[selectedStr]?[habit.id] ?? false);
      if (isDoneToday) {
        done.add(habit);
      } else {
        todo.add(habit);
      }
    }

    int completedToday = 0;
    for (var habit in activeHabits) {
      if (_logs[selectedStr]?[habit.id] == true) {
        completedToday++;
      }
    }
    double progress = activeHabits.isEmpty ? 0 : completedToday / activeHabits.length;

    final monthNames = ["Ocak", "Şubat", "Mart", "Nisan", "Mayıs", "Haziran", "Temmuz", "Ağustos", "Eylül", "Ekim", "Kasım", "Aralık"];
    final dateDisplay = "${_selectedDate.day} ${monthNames[_selectedDate.month - 1]}";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Günlük Alışkanlıklar',
              style: GoogleFonts.nunito(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
              ),
            ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left, color: AppColors.textMid),
                  onPressed: () => setState(() => _selectedDate = _selectedDate.subtract(const Duration(days: 1))),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 8),
                Text(
                  dateDisplay,
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.teal,
                  ),
                ),
                const SizedBox(width: 8),
                // Sağ ok: sadece bugün değilsek göster
                if (_selectedDate.isBefore(DateTime(today.year, today.month, today.day)))
                  IconButton(
                    icon: const Icon(Icons.chevron_right, color: AppColors.textMid),
                    onPressed: () {
                      final next = _selectedDate.add(const Duration(days: 1));
                      final todayClean = DateTime(today.year, today.month, today.day);
                      if (!next.isAfter(todayClean)) {
                        setState(() => _selectedDate = next);
                      }
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  )
                else
                  const SizedBox(width: 40),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.add_circle, color: AppColors.teal, size: 28),
              onPressed: _showAddHabitSheet,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            )
          ],
        ),
        
        // Progress Ring
        if (_habits.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 16, top: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.white,
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
                        color: progress == 1.0 ? AppColors.teal : AppColors.orange,
                      ),
                      Center(
                        child: Text(
                          "$completedToday/${activeHabits.length}",
                          style: GoogleFonts.nunito(
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
                        activeHabits.isEmpty
                            ? 'Bu tarih için aktif alışkanlık yok'
                            : (progress == 1.0 ? 'Harika! Hepsini tamamladın 🎉' : 'Bugün nasılız?'),
                        style: GoogleFonts.nunito(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                        ),
                      ),
                      Text(
                        'Allah katında amellerin en sevimlisi (en makbülü) az da olsa devamlı olanıdır',
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
          ),

        if (_habits.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderGrey),
            ),
            child: Text(
              "Henüz bir alışkanlık eklemedin.\nSağ üstteki + butonundan başlayabilirsin.",
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(color: AppColors.textMid),
            ),
          ),

        // Habit Cards — Virdlerim ile Birebir Aynı Bölünmüş Liste Yapısı (Yapılacaklar & Tamamlananlar)
        if (_habits.isNotEmpty) ...[
          // Todo list
          ...todo.asMap().entries.map((entry) {
            final idx = entry.key;
            final habit = entry.value;
            final isLast = idx == todo.length - 1 && (done.isEmpty || !_showCompletedHabits);
            return _buildHabitRow(
              habit,
              isLast: isLast,
              isDoneToday: false,
              selDay: selDay,
              today: today,
              selectedStr: selectedStr,
            );
          }),
          
          // Collapsible Completed list
          if (done.isNotEmpty) ...[
            GestureDetector(
              onTap: () => setState(() => _showCompletedHabits = !_showCompletedHabits),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                color: Colors.transparent,
                child: Row(
                  children: [
                    Icon(
                      _showCompletedHabits ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
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
            if (_showCompletedHabits)
              ...done.asMap().entries.map((entry) {
                final idx = entry.key;
                final habit = entry.value;
                final isLast = idx == done.length - 1;
                return _buildHabitRow(
                  habit,
                  isLast: isLast,
                  isDoneToday: true,
                  selDay: selDay,
                  today: today,
                  selectedStr: selectedStr,
                );
              }),
          ],
        ],
      ],
    );
  }
}
