import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app_colors.dart';
import 'habit_tracker_widget.dart';

class HabitHeatMapSheet extends StatelessWidget {
  final HabitDef habit;
  final Set<String> completedDateStrs;
  final int currentStreak;
  final DateTime createdAt;
  final String? hadithText;

  const HabitHeatMapSheet({
    super.key,
    required this.habit,
    required this.completedDateStrs,
    required this.currentStreak,
    required this.createdAt,
    this.hadithText,
  });

  static Future<void> show(
    BuildContext context, {
    required HabitDef habit,
    required Set<String> completedDateStrs,
    required int currentStreak,
    required DateTime createdAt,
    String? hadithText,
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
        hadithText: hadithText,
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
      child: SingleChildScrollView(
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
  
            if (hadithText != null && hadithText!.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Text(
                  'Fazilet',
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: habit.color.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: habit.color.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.star_rounded, color: habit.color, size: 12),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          hadithText!,
                          style: GoogleFonts.nunito(
                            fontSize: 10.5,
                            color: AppColors.textDark,
                            height: 1.35,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],

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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
            const SizedBox(height: 4),
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

    // Başlangıç tarihi hesabı açtığı gün (createdAt) veya en eski tamamlama tarihidir
    DateTime effectiveStartDate = createdAt;
    for (final dateStr in completedDateStrs) {
      try {
        final parts = dateStr.split('-');
        if (parts.length != 3) continue;
        final d = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
        if (d.isBefore(effectiveStartDate)) effectiveStartDate = d;
      } catch (_) {}
    }

    final currentMonday = todayClean.subtract(Duration(days: todayClean.weekday - 1));
    final startMonday = effectiveStartDate.subtract(Duration(days: effectiveStartDate.weekday - 1));
    
    // Her zaman 1 yıllık harita (53 hafta) gösterilir
    const int totalWeeks = 53;

    // Mevcut haftanın indeksini bul (left-to-right kronolojik sırada kaçıncı kolona denk geldiği)
    final currentWeekIndex = currentMonday.difference(startMonday).inDays ~/ 7;
    // Mevcut haftayı görünür kılmak için kaydırma offseti (kolon genişliği 16 + gap 3 = 19)
    final scrollOffset = currentWeekIndex >= 3 
        ? (currentWeekIndex - 2) * 19.0 
        : 0.0;

    const double squareSize = 16;
    const double gap = 3;
    const List<String> monthNames = ["Oca", "Şub", "Mar", "Nis", "May", "Haz", "Tem", "Ağu", "Eyl", "Eki", "Kas", "Ara"];

    // Ay etiketlerini önceden hesapla — soldan sağa kronolojik sırada
    final Map<int, String> labelMap = {};
    int lastLabelCol = -10;
    String? pendingLabel;
    for (int i = 0; i < totalWeeks; i++) {
      final wm = startMonday.add(Duration(days: i * 7));
      if (i == 0) {
        labelMap[0] = monthNames[wm.month - 1];
        lastLabelCol = 0;
      } else {
        final prevWm = startMonday.add(Duration(days: (i - 1) * 7));
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
              _dayLabel('Sal', squareSize, gap),
              _dayLabel('Çar', squareSize, gap),
              _dayLabel('Per', squareSize, gap),
              _dayLabel('Cum', squareSize, gap),
              _dayLabel('Cmt', squareSize, gap),
              _dayLabel('Paz', squareSize, gap),
            ],
          ),
        ),

        Expanded(
          child: ListView.builder(
            controller: ScrollController(initialScrollOffset: scrollOffset),
            scrollDirection: Axis.horizontal,
            itemCount: totalWeeks,
            itemBuilder: (context, index) {
              final weekMonday = startMonday.add(Duration(days: index * 7));
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
                    final isBeforeCreation = d.isBefore(effectiveStartDate);

                    Color boxColor;
                    Border boxBorder;

                    if (isBeforeCreation) {
                      boxColor = Colors.transparent;
                      boxBorder = const Border.fromBorderSide(BorderSide.none);
                    } else if (isFuture) {
                      boxColor = Colors.transparent;
                      boxBorder = Border.all(
                        color: AppColors.borderGrey.withValues(alpha: 0.25),
                        width: 1.0,
                      );
                    } else {
                      boxColor = isDone ? habitColor : AppColors.borderGrey.withValues(alpha: 0.3);
                      boxBorder = Border.all(
                        color: isDone ? habitColor.withValues(alpha: 0.5) : Colors.transparent,
                        width: 1.0,
                      );
                    }

                    return Container(
                      width: squareSize,
                      height: squareSize,
                      margin: const EdgeInsets.only(bottom: gap, right: gap),
                      decoration: BoxDecoration(
                        color: boxColor,
                        borderRadius: BorderRadius.circular(3),
                        border: boxBorder,
                      ),
                      child: (!isBeforeCreation && !isFuture)
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
          fontSize: 8,
          fontWeight: FontWeight.w600,
          color: AppColors.textMid,
        ),
      ),
    );
  }
}
