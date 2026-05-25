import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app_colors.dart';
import '../app_theme.dart';
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
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
                color: context.colors.border,
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
                          color: context.colors.textPrimary,
                        ),
                      ),
                      Text(
                        'Devamlılık Haritası',
                        style: GoogleFonts.nunito(fontSize: 13, color: context.colors.textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: context.colors.textSecondary, size: 24),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          
          Divider(height: 1, color: context.colors.border),
          
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
                color: context.colors.textPrimary,
              ),
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: SizedBox(
              height: 180,
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
                    color: context.colors.textSecondary,
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
                color: context.colors.textPrimary,
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
    // Harita alışkanlığın oluşturulduğu aydan başlar
    final startOfMonth = DateTime(createdAt.year, createdAt.month, 1);
    // Grid'i Pazartesi'den başlatmak için o haftanın Pazartesi'sini bul
    final startMonday = startOfMonth.subtract(Duration(days: startOfMonth.weekday - 1));
    // Alışkanlığın oluşturulduğu gün (saat sıfırlanmış)
    final createdDay = DateTime(createdAt.year, createdAt.month, createdAt.day);
    
    // 52 hafta (1 yıl) ileriye doğru
    const int totalWeeks = 52;
    const double squareSize = 14;
    const double gap = 4;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Y-axis labels (Days of week)
        Padding(
          padding: const EdgeInsets.only(top: 14.0, right: 8.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _dayLabel(context, 'Pzt', squareSize, gap),
              _dayLabel(context, '', squareSize, gap),
              _dayLabel(context, 'Çar', squareSize, gap),
              _dayLabel(context, '', squareSize, gap),
              _dayLabel(context, 'Cum', squareSize, gap),
              _dayLabel(context, '', squareSize, gap),
              _dayLabel(context, 'Paz', squareSize, gap),
            ],
          ),
        ),
        
        // Heatmap Grid
        Expanded(
          child: ListView.builder(
            reverse: false, // Soldan sağa doğru
            scrollDirection: Axis.horizontal,
            itemCount: totalWeeks,
            itemBuilder: (context, index) {
              final weekMonday = startMonday.add(Duration(days: index * 7));
              
              // Only show month label if it's the first week of a month
              String? monthLabel;
              if (weekMonday.day <= 7) {
                final monthNames = ["Oca", "Şub", "Mar", "Nis", "May", "Haz", "Tem", "Ağu", "Eyl", "Eki", "Kas", "Ara"];
                monthLabel = monthNames[weekMonday.month - 1];
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Month Label Header
                  SizedBox(
                    height: 14,
                    width: squareSize + gap,
                    child: monthLabel != null
                        ? Text(
                            monthLabel,
                            style: GoogleFonts.nunito(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: context.colors.textSecondary,
                            ),
                            overflow: TextOverflow.visible,
                            softWrap: false,
                          )
                        : null,
                  ),
                  
                  // 7 days of the week
                  ...List.generate(7, (dayIndex) {
                    final d = weekMonday.add(Duration(days: dayIndex));
                    final dStr = "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
                    final isDone = completedDateStrs.contains(dStr);
                    final today = DateTime.now();
                    final todayClean = DateTime(today.year, today.month, today.day);
                    final isFuture = d.isAfter(todayClean);
                    final isBeforeCreation = d.isBefore(createdDay);

                    return Container(
                      width: squareSize,
                      height: squareSize,
                      margin: const EdgeInsets.only(bottom: gap, right: gap),
                      decoration: BoxDecoration(
                        color: isBeforeCreation
                            ? Colors.transparent
                            : isFuture
                                ? Colors.transparent
                                : (isDone ? habitColor : context.colors.border.withValues(alpha: 0.3)),
                        borderRadius: BorderRadius.circular(3),
                        border: isBeforeCreation || isFuture
                            ? Border.all(color: context.colors.border.withValues(alpha: 0.08))
                            : Border.all(
                                color: isDone ? habitColor.withValues(alpha: 0.5) : Colors.transparent,
                              )
                      ),
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

  Widget _dayLabel(BuildContext context, String text, double size, double gap) {
    return Container(
      height: size,
      margin: EdgeInsets.only(bottom: gap),
      alignment: Alignment.centerRight,
      child: Text(
        text,
        style: GoogleFonts.nunito(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: context.colors.textSecondary,
        ),
      ),
    );
  }
}
