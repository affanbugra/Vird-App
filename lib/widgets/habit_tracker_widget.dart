import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../app_colors.dart';
import 'habit_heat_map_sheet.dart';

// Kullanıcının seçebileceği alışkanlık ikonları. const liste — codePoint ile lookup yapılır,
// böylece eski kayıtlar (iconCode'suz) varsayılan star'a düşer.
const List<IconData> kHabitIcons = [
  Icons.star_rounded,
  Icons.favorite_rounded,
  // Spor & Beden
  Icons.directions_run_rounded,
  Icons.fitness_center_rounded,
  Icons.mosque,
  Icons.directions_walk_rounded,
  Icons.directions_bike_rounded,
  Icons.pool_rounded,
  Icons.sports_soccer_rounded,
  // Sağlık
  Icons.local_drink_rounded,
  Icons.restaurant_rounded,
  Icons.bedtime_rounded,
  Icons.medication_rounded,
  Icons.spa_rounded,
  // Öğrenme & Üretkenlik
  Icons.menu_book_rounded,
  Icons.school_rounded,
  Icons.language_rounded,
  Icons.edit_rounded,
  Icons.computer_rounded,
  Icons.work_rounded,
  Icons.checklist_rounded,
  Icons.lightbulb_rounded,
  // Manevi & Zihin
  Icons.brightness_3,
  Icons.psychology_rounded,
  // Hobi
  Icons.music_note_rounded,
  Icons.palette_rounded,
  Icons.camera_alt_rounded,
  // Ev & Yaşam
  Icons.cleaning_services_rounded,
  Icons.eco_rounded,
  Icons.local_florist_rounded,
];

IconData resolveHabitIcon(int? codePoint) {
  if (codePoint == null) return Icons.star_rounded;
  for (final icon in kHabitIcons) {
    if (icon.codePoint == codePoint) return icon;
  }
  return Icons.star_rounded;
}

class HabitDef {
  final String id;
  final String title;
  final Color color;
  final int iconCode;
  final DateTime createdAt;

  HabitDef({
    required this.id,
    required this.title,
    required this.color,
    int? iconCode,
    DateTime? createdAt,
  })  : iconCode = iconCode ?? Icons.star_rounded.codePoint,
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'color': color.value,
    'iconCode': iconCode,
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
      iconCode: map['iconCode'] is int ? map['iconCode'] as int : null,
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
  DateTime? _userCreatedAt;

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
      // 0. Fetch User Doc for createdAt
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .get();
      if (userDoc.exists) {
        final userData = userDoc.data() ?? {};
        final createdAtTs = userData['createdAt'] as Timestamp?;
        _userCreatedAt = createdAtTs?.toDate();
      }

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

  void _showHabitDesignSheet({HabitDef? editingHabit}) {
    final isEdit = editingHabit != null;
    String newTitle = editingHabit?.title ?? '';
    Color selectedColor = editingHabit?.color ?? AppColors.teal;
    IconData selectedIcon = editingHabit != null
        ? resolveHabitIcon(editingHabit.iconCode)
        : Icons.star_rounded;
    final colors = [
      const Color(0xFFD63031), // Klasik Koyu Kırmızı
      const Color(0xFFE63946), // Premium Kırmızı
      const Color(0xFFF07167), // Pastel Mercan
      const Color(0xFFE07A5F), // Sıcak Kiremit / Terracotta
      AppColors.orange,        // Canlı Turuncu
      const Color(0xFFF4A261), // Pastel Şeftali
      AppColors.gold,          // Canlı Altın
      const Color(0xFFE9C46A), // Hardal Kum Sarısı
      const Color(0xFF81B29A), // Adaçayı/Sage Yeşili
      const Color(0xFF4CAF50), // Doğa Yeşili
      AppColors.emeraldGreen,  // Zümrüt Yeşili
      const Color(0xFF2A9D8F), // Çam Yeşili
      AppColors.teal,          // Uygulama Teali
      const Color(0xFF00B4D8), // Okyanus Mavisi
      AppColors.infoBlue,      // Gökyüzü Mavisi
      const Color(0xFF4361EE), // Kraliyet Mavisi
      const Color(0xFF9B5DE5), // Lavanta
      const Color(0xFF7209B7), // Premium Mor
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
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEdit ? 'Görünümü Düzenle' : 'Yeni Alışkanlık Ekle',
                      style: GoogleFonts.nunito(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (!isEdit) ...[
                      TextField(
                        autofocus: true,
                        textInputAction: TextInputAction.done,
                        maxLength: 50,
                        onSubmitted: (val) {
                          newTitle = val;
                          if (newTitle.trim().isEmpty) return;
                          Navigator.pop(ctx);
                          _addNewHabit(newTitle.trim(), selectedColor, selectedIcon);
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
                    ],
                    Text(
                      'İkon Seçin',
                      style: GoogleFonts.nunito(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMid,
                      ),
                    ),
                    const SizedBox(height: 6),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: kHabitIcons.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 8,
                        mainAxisSpacing: 6,
                        crossAxisSpacing: 6,
                        childAspectRatio: 1,
                      ),
                      itemBuilder: (_, idx) {
                        final icon = kHabitIcons[idx];
                        final isSelected = icon.codePoint == selectedIcon.codePoint;
                        return GestureDetector(
                          onTap: () => setModalState(() => selectedIcon = icon),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? selectedColor.withValues(alpha: 0.15)
                                  : AppColors.lightGrey,
                              borderRadius: BorderRadius.circular(10),
                              border: isSelected
                                  ? Border.all(color: selectedColor, width: 1.5)
                                  : null,
                            ),
                            child: Icon(
                              icon,
                              size: 16,
                              color: isSelected ? selectedColor : AppColors.textMid,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Renk Seçin',
                      style: GoogleFonts.nunito(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMid,
                      ),
                    ),
                    const SizedBox(height: 6),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: colors.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 10,
                        mainAxisSpacing: 6,
                        crossAxisSpacing: 6,
                        childAspectRatio: 1,
                      ),
                      itemBuilder: (_, idx) {
                        final c = colors[idx];
                        final isSelected = c.value == selectedColor.value;
                        return GestureDetector(
                          onTap: () => setModalState(() => selectedColor = c),
                          child: Container(
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: isSelected ? Border.all(color: AppColors.textDark, width: 2) : null,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.teal,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () async {
                          if (isEdit) {
                            Navigator.pop(ctx);
                            _saveHabitDesign(editingHabit, selectedIcon, selectedColor);
                          } else {
                            if (newTitle.trim().isEmpty) return;
                            Navigator.pop(ctx);
                            _addNewHabit(newTitle.trim(), selectedColor, selectedIcon);
                          }
                        },
                        child: Text(
                          isEdit ? 'Kaydet' : 'Ekle',
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
              ),
            );
          }
        );
      }
    );
  }

  Future<void> _addNewHabit(String title, Color color, IconData icon) async {
    if (_uid == null) return;

    final newHabit = HabitDef(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      color: color,
      iconCode: icon.codePoint,
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
      _habits[idx] = HabitDef(
        id: habit.id,
        title: newName,
        color: habit.color,
        iconCode: habit.iconCode,
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
      debugPrint('Error renaming habit: $e');
    }
  }

  Future<void> _persistHabits() async {
    if (_uid == null) return;
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
      debugPrint('Error persisting habits: $e');
    }
  }

  Future<void> _saveHabitDesign(HabitDef habit, IconData newIcon, Color newColor) async {
    if (_uid == null) return;
    if (!mounted) return;

    final idx = _habits.indexWhere((h) => h.id == habit.id);
    if (idx == -1) return;

    setState(() {
      _habits[idx] = HabitDef(
        id: habit.id,
        title: habit.title,
        color: newColor,
        iconCode: newIcon.codePoint,
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
      debugPrint('Error updating habit design: $e');
    }
  }

  int _calculateStreak(String habitId) {
    int streak = 0;
    final today = DateTime.now();
    
    // Geçmişe doğru kontrol et
    for (int i = 0; i < 365; i++) {
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
    Key? key,
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
      key: key,
      margin: const EdgeInsets.symmetric(vertical: 3),
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: isDoneToday ? habit.color.withValues(alpha: 0.18) : AppColors.white,
        border: Border.all(
          color: isDoneToday
              ? habit.color.withValues(alpha: 0.33)
              : AppColors.borderGrey,
          width: 1.0,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Opacity(
        opacity: isInactive ? 0.38 : 1.0,
        child: Material(
          color: Colors.transparent,
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
              createdAt: _userCreatedAt ?? habit.createdAt,
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              children: [
                // Yuvarlak Habit İkonu (virdlerim stili)
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isDoneToday ? habit.color : habit.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: isDoneToday
                        ? [BoxShadow(color: habit.color.withValues(alpha: 0.27), blurRadius: 10, offset: const Offset(0, 4))]
                        : null,
                  ),
                  child: Icon(
                    resolveHabitIcon(habit.iconCode),
                    color: isDoneToday ? Colors.white : habit.color,
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
                          color: AppColors.textDark,
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
                const SizedBox(width: 8),
                // 7 günlük haftalık takip noktaları — onay butonunun solunda
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
                      Border? dotBorder;

                      if (isInactiveOnDay) {
                        dotColor = Colors.transparent;
                        dotBorder = Border.all(color: AppColors.borderGrey, width: 1.0);
                      } else if (isDone) {
                        dotColor = habit.color;
                      } else if (dCleanOnDot == todayClean) {
                        dotColor = Colors.white;
                        dotBorder = Border.all(color: habit.color, width: 1.0);
                      } else {
                        dotColor = const Color(0xFFE5ECEE);
                      }

                      // Seçili gün göstergesi — bugün+tamamlanmamış stilini bozmuyor
                      if (isSelectedDay && !(dCleanOnDot == todayClean && !isDone)) {
                        dotBorder = Border.all(color: AppColors.textDark.withValues(alpha: 0.45), width: 1.2);
                      }

                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 1.5),
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: dotColor,
                          shape: BoxShape.circle,
                          border: dotBorder,
                        ),
                      );
                    }),
                  ),
                ],
                const SizedBox(width: 8),
                // Onay butonu — en sağda
                if (!isInactive)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      _toggleHabit(habit);
                    },
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDoneToday ? habit.color : Colors.white,
                        border: isDoneToday
                            ? Border.all(color: habit.color, width: 2.0)
                            : Border.all(color: const Color(0xFFD0D9DD), width: 2.0),
                      ),
                      child: isDoneToday
                          ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
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
                    if (value == 'design') _showHabitDesignSheet(editingHabit: habit);
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
                      value: 'design',
                      child: Row(
                        children: [
                          const Icon(Icons.palette_outlined, size: 18, color: AppColors.textMid),
                          const SizedBox(width: 10),
                          Text('İkon & Renk', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
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
    final todayClean = DateTime(today.year, today.month, today.day);
    final selectedStr = "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}";

    final selDay = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);

    // Seçili tarihte aktif olan alışkanlıklar (createdAt <= selectedDate)
    final activeHabits = _habits.where((h) {
      final c = DateTime(h.createdAt.year, h.createdAt.month, h.createdAt.day);
      return !c.isAfter(selDay);
    }).toList();

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
          children: [
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragEnd: (details) {
                  final v = details.primaryVelocity ?? 0;
                  if (v > 250) {
                    setState(() => _selectedDate = _selectedDate.subtract(const Duration(days: 1)));
                  } else if (v < -250) {
                    final next = _selectedDate.add(const Duration(days: 1));
                    if (!next.isAfter(todayClean)) {
                      setState(() => _selectedDate = next);
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
                        onPressed: () => setState(() => _selectedDate = _selectedDate.subtract(const Duration(days: 1))),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      Text(
                        selDay == todayClean ? "Bugün ($dateDisplay)" : dateDisplay,
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
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.add_circle, color: AppColors.teal, size: 28),
              onPressed: () => _showHabitDesignSheet(),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
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
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: progress),
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeOutCubic,
                        builder: (context, animVal, _) => CircularProgressIndicator(
                          value: animVal,
                          strokeWidth: 6,
                          backgroundColor: AppColors.lightGrey,
                          color: progress == 1.0 ? AppColors.teal : AppColors.orange,
                        ),
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
                            : (progress == 1.0
                                ? 'Harika! Hepsini tamamladın 🎉'
                                : selDay == todayClean ? 'Bugün nasılız?' : 'Geçmiş Gün'),
                        style: GoogleFonts.nunito(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                        ),
                      ),
                      Text(
                        '"Allah katında amellerin en sevimlisi, az da olsa devamlı olanıdır." (Buhârî, Teheccüd 18; Müslim, Müsâfirîn 215)',
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
          Padding(
            padding: const EdgeInsets.only(top: 36, bottom: 24),
            child: Center(
              child: Text(
                "Henüz bir alışkanlık eklemedin.\nSağ üstteki + butonundan başlayabilirsin.",
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                  color: AppColors.textLight,
                  fontSize: 12.5,
                  height: 1.5,
                ),
              ),
            ),
          ),

        // Habit Cards — uzun bas-sürükle ile sıralanabilir
        if (_habits.isNotEmpty)
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
            itemCount: activeHabits.length,
            itemBuilder: (context, idx) {
              final habit = activeHabits[idx];
              final isDoneToday = (_logs[selectedStr]?[habit.id] ?? false);
              return RepaintBoundary(
                key: ValueKey(habit.id),
                child: ReorderableDelayedDragStartListener(
                  index: idx,
                  child: _buildHabitRow(
                    habit,
                    isLast: idx == activeHabits.length - 1,
                    isDoneToday: isDoneToday,
                    selDay: selDay,
                    today: today,
                    selectedStr: selectedStr,
                  ),
                ),
              );
            },
            onReorder: (oldIdx, newIdx) {
              if (newIdx > oldIdx) newIdx -= 1;
              if (oldIdx == newIdx) return;

              final newActiveOrder = List<HabitDef>.from(activeHabits);
              final moved = newActiveOrder.removeAt(oldIdx);
              newActiveOrder.insert(newIdx, moved);

              final activeIds = activeHabits.map((h) => h.id).toSet();
              final rebuilt = <HabitDef>[];
              int activeCursor = 0;
              for (final h in _habits) {
                if (activeIds.contains(h.id)) {
                  rebuilt.add(newActiveOrder[activeCursor++]);
                } else {
                  rebuilt.add(h);
                }
              }

              setState(() => _habits = rebuilt);
              _persistHabits();
            },
          ),
      ],
    );
  }
}
