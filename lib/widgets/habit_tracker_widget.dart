import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math' as math;
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

class _HabitTrackerWidgetState extends State<HabitTrackerWidget> {
  bool _isLoading = true;
  List<HabitDef> _habits = [];
  
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
      final startDate = _selectedDate.subtract(const Duration(days: 30));
      final startDateStr = "${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}";

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
    final colors = [AppColors.teal, AppColors.orange, AppColors.gold, Colors.blueAccent, Colors.pinkAccent, Colors.purpleAccent];

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
                    decoration: InputDecoration(
                      hintText: 'Örn: Sabah Yürüyüşü',
                      filled: true,
                      fillColor: AppColors.lightGrey,
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: colors.map((c) {
                      final isSelected = c == selectedColor;
                      return GestureDetector(
                        onTap: () => setModalState(() => selectedColor = c),
                        child: Container(
                          width: 40, height: 40,
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

  Future<void> _reorderHabits(int oldIndex, int newIndex) async {
    if (_uid == null) return;
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _habits.removeAt(oldIndex);
      _habits.insert(newIndex, item);
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
      debugPrint("Error reordering habits: \$e");
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
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.lightGrey,
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

  @override
  Widget build(BuildContext context) {
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

        // Habit Cards — ReorderableListView ile sürükle-bırak
        if (_habits.isNotEmpty)
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: _habits.length,
            onReorder: _reorderHabits,
            proxyDecorator: (child, index, animation) {
              return AnimatedBuilder(
                animation: animation,
                builder: (ctx, _) {
                  final double elevation = animation.value * 8;
                  return Material(
                    elevation: elevation,
                    borderRadius: BorderRadius.circular(16),
                    shadowColor: Colors.black26,
                    child: child,
                  );
                },
              );
            },
            itemBuilder: (context, habitIndex) {
              final habit = _habits[habitIndex];
              final createdDay = DateTime(habit.createdAt.year, habit.createdAt.month, habit.createdAt.day);
              final isInactive = selDay.isBefore(createdDay); // Bu tarihte henüz eklenmemişti
              
              if (isInactive) {
                return SizedBox.shrink(key: ValueKey(habit.id));
              }

              final isDoneToday = !isInactive && (_logs[selectedStr]?[habit.id] ?? false);
              final streak = _calculateStreak(habit.id);

              int weekCompletions = 0;
              final monday = _selectedDate.subtract(Duration(days: _selectedDate.weekday - 1));
              for (int i = 0; i < 7; i++) {
                final d = monday.add(Duration(days: i));
                final dStr = "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
                if (_logs[dStr]?[habit.id] == true) weekCompletions++;
              }

              return GestureDetector(
                key: ValueKey(habit.id),
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
                child: Opacity(
                  opacity: isInactive ? 0.38 : 1.0,
                  child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isInactive
                        ? AppColors.lightGrey
                        : (isDoneToday ? habit.color.withValues(alpha: 0.1) : AppColors.white),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isInactive
                          ? AppColors.borderGrey
                          : (isDoneToday ? habit.color.withValues(alpha: 0.5) : AppColors.borderGrey),
                      width: isDoneToday ? 2 : 1,
                    ),
                    boxShadow: (isInactive || isDoneToday) ? [] : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      )
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          // Sürükleme tutamacı
                          ReorderableDragStartListener(
                            index: habitIndex,
                            child: Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Icon(
                                Icons.drag_handle,
                                color: AppColors.textLight,
                                size: 20,
                              ),
                            ),
                          ),
                          Container(
                            width: 4, height: 24,
                            decoration: BoxDecoration(
                              color: habit.color,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  habit.title,
                                  style: GoogleFonts.nunito(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: isInactive ? AppColors.textLight : AppColors.textDark,
                                    decoration: isDoneToday ? TextDecoration.lineThrough : null,
                                  ),
                                ),
                                if (isInactive)
                                  Text(
                                    'Bu gün henüz eklenmemişti',
                                    style: GoogleFonts.nunito(
                                      fontSize: 11,
                                      color: AppColors.textLight,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  )
                                else
                                  Row(
                                    children: [
                                      if (streak > 0)
                                        Padding(
                                          padding: const EdgeInsets.only(right: 8.0),
                                          child: Text(
                                            "🔥 $streak",
                                            style: GoogleFonts.nunito(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.orange,
                                            ),
                                          ),
                                        ),
                                      Text(
                                        "Bu Hafta: $weekCompletions/7",
                                        style: GoogleFonts.nunito(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textMid,
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                          // İşaretleme butonu — sadece aktif alışkanlıklar için
                          if (!isInactive)
                          GestureDetector(
                            onTap: () => _toggleHabit(habit),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 32, height: 32,
                              decoration: BoxDecoration(
                                color: isDoneToday ? habit.color : Colors.transparent,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isDoneToday ? habit.color : AppColors.borderGrey,
                                  width: 2,
                                ),
                              ),
                              child: isDoneToday
                                  ? const Icon(Icons.check, color: Colors.white, size: 20)
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 4),
                          PopupMenuButton<String>(
                            icon: Icon(Icons.more_vert, color: AppColors.textLight, size: 20),
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            onSelected: (value) {
                              if (value == 'rename') _renameHabit(habit);
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
                      const SizedBox(height: 12),
                      // Mini 7 day graph
                      Row(
                        children: List.generate(7, (index) {
                          final monday2 = _selectedDate.subtract(Duration(days: _selectedDate.weekday - 1));
                          final d = monday2.add(Duration(days: index));
                          final dStr = "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
                          final isDone = _logs[dStr]?[habit.id] ?? false;
                          final isSelected = dStr == selectedStr;

                          return Expanded(
                            child: GestureDetector(
                              onTap: () {
                                if (!d.isAfter(today)) {
                                  setState(() => _selectedDate = d);
                                }
                              },
                              child: Container(
                                margin: const EdgeInsets.symmetric(horizontal: 2),
                                height: isSelected ? 10 : 6,
                                decoration: BoxDecoration(
                                  color: isDone
                                      ? habit.color
                                      : habit.color.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(isSelected ? 6 : 4),
                                  border: isSelected
                                      ? Border.all(color: habit.color.withValues(alpha: 0.5), width: 1)
                                      : null,
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                ),
                ),
              );
            },
          ),
      ],
    );
  }
}
