import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app_colors.dart';

class SeriCalendarSheet extends StatefulWidget {
  final String uid;
  final int currentSeri;

  const SeriCalendarSheet({super.key, required this.uid, required this.currentSeri});

  static void show(BuildContext context, {required String uid, required int seri}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SeriCalendarSheet(uid: uid, currentSeri: seri),
    );
  }

  @override
  State<SeriCalendarSheet> createState() => _SeriCalendarSheetState();
}

class _SeriCalendarSheetState extends State<SeriCalendarSheet> {
  late DateTime _month;
  Set<String> _logDays = {};
  bool _loading = true;

  static const _monthNames = [
    '', 'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
    'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık',
  ];
  static const _dayLabels = ['Pt', 'Sa', 'Ça', 'Pe', 'Cu', 'Ct', 'Pa'];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _loading = true);
    final start = _month;
    final end = DateTime(_month.year, _month.month + 1);
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.uid)
        .collection('logs')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('createdAt', isLessThan: Timestamp.fromDate(end))
        .get();

    final days = <String>{};
    for (final doc in snap.docs) {
      final ts = doc.data()['createdAt'] as Timestamp?;
      if (ts != null) {
        final d = ts.toDate().toLocal();
        days.add('${d.year}-${d.month}-${d.day}');
      }
    }
    if (mounted) setState(() { _logDays = days; _loading = false; });
  }

  bool get _canGoNext {
    final now = DateTime.now();
    return _month.isBefore(DateTime(now.year, now.month));
  }

  void _prevMonth() {
    setState(() => _month = DateTime(_month.year, _month.month - 1));
    _loadLogs();
  }

  void _nextMonth() {
    if (!_canGoNext) return;
    setState(() => _month = DateTime(_month.year, _month.month + 1));
    _loadLogs();
  }

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateUtils.getDaysInMonth(_month.year, _month.month);
    final firstWeekday = DateTime(_month.year, _month.month, 1).weekday; // 1=Pzt
    final today = DateTime.now();
    final isCurrentMonth = _month.year == today.year && _month.month == today.month;

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.5,
      maxChildSize: 0.88,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: ListView(
          controller: controller,
          padding: EdgeInsets.zero,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.borderGrey,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Başlık + seri sayısı
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Text('🔥', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Seri Takvimi',
                      style: GoogleFonts.nunito(
                        fontSize: 18, fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.orange.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${widget.currentSeri} günlük seri',
                      style: GoogleFonts.nunito(
                        fontSize: 13, fontWeight: FontWeight.w800,
                        color: AppColors.orange,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Ay navigasyonu
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: _prevMonth,
                    color: AppColors.textMid,
                  ),
                  Expanded(
                    child: Text(
                      '${_monthNames[_month.month]} ${_month.year}',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.nunito(
                        fontSize: 15, fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: _canGoNext ? _nextMonth : null,
                    color: _canGoNext ? AppColors.textMid : AppColors.borderGrey,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            // Gün isimleri
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: _dayLabels.map((d) => Expanded(
                  child: Center(
                    child: Text(d,
                      style: GoogleFonts.nunito(
                        fontSize: 11, fontWeight: FontWeight.w700,
                        color: AppColors.textLight,
                      ),
                    ),
                  ),
                )).toList(),
              ),
            ),
            const SizedBox(height: 6),
            // Takvim ızgarası
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7, childAspectRatio: 1,
                  ),
                  itemCount: (firstWeekday - 1) + daysInMonth,
                  itemBuilder: (_, i) {
                    if (i < firstWeekday - 1) return const SizedBox();
                    final day = i - (firstWeekday - 1) + 1;
                    final key = '${_month.year}-${_month.month}-$day';
                    final hasLog = _logDays.contains(key);
                    final isToday = isCurrentMonth && day == today.day;
                    final isFuture = isCurrentMonth && day > today.day;

                    Color? bgColor;
                    Border? border;
                    Color textColor = AppColors.textDark;
                    FontWeight fontWeight = FontWeight.w500;

                    if (isFuture) {
                      textColor = AppColors.borderGrey;
                    } else if (hasLog) {
                      bgColor = AppColors.orange;
                      textColor = Colors.white;
                      fontWeight = FontWeight.w800;
                    } else if (isToday) {
                      border = Border.all(color: AppColors.orange, width: 1.5);
                      textColor = AppColors.orange;
                      fontWeight = FontWeight.w700;
                    }

                    return Center(
                      child: Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: bgColor,
                          border: border,
                        ),
                        child: Center(
                          child: Text('$day',
                            style: GoogleFonts.nunito(
                              fontSize: 12,
                              fontWeight: fontWeight,
                              color: textColor,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 16),
            // Özet şeridi
            if (!_loading)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _SummaryChip(
                      label: "${_monthNames[_month.month]}'da",
                      value: '${_logDays.length} gün',
                      icon: '📅',
                    ),
                    const SizedBox(width: 10),
                    _SummaryChip(
                      label: 'Güncel seri',
                      value: '${widget.currentSeri} gün 🔥',
                      icon: '',
                      hideIcon: true,
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final String value;
  final String icon;
  final bool hideIcon;

  const _SummaryChip({
    required this.label,
    required this.value,
    required this.icon,
    this.hideIcon = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.lightGrey,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            if (!hideIcon) Text(icon, style: const TextStyle(fontSize: 16)),
            if (!hideIcon) const SizedBox(height: 2),
            Text(value,
              style: GoogleFonts.nunito(
                fontSize: 14, fontWeight: FontWeight.w800,
                color: AppColors.textDark,
              ),
            ),
            Text(label,
              style: GoogleFonts.nunito(
                fontSize: 11, color: AppColors.textLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
