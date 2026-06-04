import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app_colors.dart';
import 'habit_tracker_widget.dart';

class HabitHeatMapSheet extends StatelessWidget {
  final HabitDef habit;
  final Set<String> completedDateStrs;
  final int currentStreak;
  final DateTime createdAt;

  const HabitHeatMapSheet({
    super.key,
    required this.habit,
    required this.completedDateStrs,
    required this.currentStreak,
    required this.createdAt,
  });

  static Future<void> show(
    BuildContext context, {
    required HabitDef habit,
    required Set<String> completedDateStrs,
    required int currentStreak,
    required DateTime createdAt,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => HabitHeatMapSheet(
        habit: habit,
        completedDateStrs: completedDateStrs,
        currentStreak: currentStreak,
        createdAt: createdAt,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 10),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderGrey,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 12, 16),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 32,
                  decoration: BoxDecoration(
                    color: habit.color,
                    borderRadius: BorderRadius.circular(6),
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
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                        ),
                      ),
                      Text(
                        'Devamlılık Haritası',
                        style: GoogleFonts.nunito(fontSize: 13, color: AppColors.textMid),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textMid, size: 24),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          
          const Divider(height: 1, color: AppColors.borderGrey),
          
          // İstatistikler
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Row(
              children: [
                _StatCard(
                  title: 'Ateş Serisi',
                  value: '$currentStreak',
                  icon: '🔥',
                  color: AppColors.orange,
                ),
                const SizedBox(width: 16),
                _StatCard(
                  title: 'Toplam Gün',
                  value: '${completedDateStrs.length}',
                  icon: '⭐',
                  color: habit.color,
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8),
            child: Text(
              'Alışkanlık Haritası',
              style: GoogleFonts.nunito(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
              ),
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: SizedBox(
              height: 160,
              child: _HabitHeatGrid(
                habitColor: habit.color,
                completedDateStrs: completedDateStrs,
                createdAt: createdAt,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(icon, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMid,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: GoogleFonts.nunito(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: AppColors.textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HabitHeatGrid extends StatelessWidget {
  final Color habitColor;
  final Set<String> completedDateStrs;
  final DateTime createdAt;

  const _HabitHeatGrid({
    required this.habitColor,
    required this.completedDateStrs,
    required this.createdAt,
  });

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayClean = DateTime(today.year, today.month, today.day);
    final createdDay = DateTime(createdAt.year, createdAt.month, createdAt.day);

    final currentMonday = todayClean.subtract(Duration(days: todayClean.weekday - 1));
    final startMonday = createdDay.subtract(Duration(days: createdDay.weekday - 1));
    final totalWeeks = (currentMonday.difference(startMonday).inDays ~/ 7) + 1;

    const double squareSize = 16;
    const double gap = 3;
    const List<String> monthNames = ["Oca", "Şub", "Mar", "Nis", "May", "Haz", "Tem", "Ağu", "Eyl", "Eki", "Kas", "Ara"];

    // Ay etiketlerini önceden hesapla — çakışmayı önlemek için min 2 kolon boşluk
    final Map<int, String> labelMap = {};
    int lastLabelCol = -10;
    String? pendingLabel;
    for (int i = 0; i < totalWeeks; i++) {
      final wm = currentMonday.subtract(Duration(days: i * 7));
      if (i == 0) {
        labelMap[0] = monthNames[wm.month - 1];
        lastLabelCol = 0;
      } else {
        final prevWm = currentMonday.subtract(Duration(days: (i - 1) * 7));
        if (prevWm.month != wm.month) {
          pendingLabel = monthNames[wm.month - 1];
        }
        if (pendingLabel != null && (i - lastLabelCol) >= 2) {
          labelMap[i] = pendingLabel;
          lastLabelCol = i;
          pendingLabel = null;
        }
      }
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 14.0, right: 8.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _dayLabel('Pzt', squareSize, gap),
              _dayLabel('', squareSize, gap),
              _dayLabel('Çar', squareSize, gap),
              _dayLabel('', squareSize, gap),
              _dayLabel('Cum', squareSize, gap),
              _dayLabel('', squareSize, gap),
              _dayLabel('Paz', squareSize, gap),
            ],
          ),
        ),

        Expanded(
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: totalWeeks,
            itemBuilder: (context, index) {
              final weekMonday = currentMonday.subtract(Duration(days: index * 7));
              final monthLabel = labelMap[index];

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 14,
                    width: squareSize + gap,
                    child: monthLabel != null
                        ? Text(
                            monthLabel,
                            style: GoogleFonts.nunito(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textMid,
                            ),
                            overflow: TextOverflow.visible,
                            softWrap: false,
                          )
                        : null,
                  ),
                  ...List.generate(7, (dayIndex) {
                    final d = weekMonday.add(Duration(days: dayIndex));
                    final dStr = "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
                    final isDone = completedDateStrs.contains(dStr);
                    final isFuture = d.isAfter(todayClean);
                    final isBeforeCreation = d.isBefore(createdDay);
                    final isActive = !isBeforeCreation && !isFuture;

                    return Container(
                      width: squareSize,
                      height: squareSize,
                      margin: const EdgeInsets.only(bottom: gap, right: gap),
                      decoration: BoxDecoration(
                        color: isActive
                            ? (isDone ? habitColor : AppColors.borderGrey.withValues(alpha: 0.3))
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(3),
                        border: isActive
                            ? Border.all(color: isDone ? habitColor.withValues(alpha: 0.5) : Colors.transparent)
                            : Border.all(color: AppColors.borderGrey.withValues(alpha: 0.08)),
                      ),
                      child: isActive
                          ? Center(
                              child: Text(
                                '${d.day}',
                                style: TextStyle(
                                  fontSize: 6.5,
                                  fontWeight: FontWeight.w700,
                                  color: isDone
                                      ? Colors.white.withValues(alpha: 0.5)
                                      : AppColors.textDark.withValues(alpha: 0.2),
                                ),
                              ),
                            )
                          : null,
                    );
                  }),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _dayLabel(String text, double size, double gap) {
    return Container(
      height: size,
      margin: EdgeInsets.only(bottom: gap),
      alignment: Alignment.centerRight,
      child: Text(
        text,
        style: GoogleFonts.nunito(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: AppColors.textMid,
        ),
      ),
    );
  }
}
