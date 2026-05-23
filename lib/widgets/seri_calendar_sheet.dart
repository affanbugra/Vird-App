import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app_colors.dart';
import '../utils/seri_calculator.dart' show seriDateKey;

// Ice palette (local)
const _kIceBg     = Color(0xFFE8F6FF);
const _kIce       = Color(0xFF60C8F0);
const _kIceDark   = Color(0xFF3A9AC4);
const _kIceBorder = Color(0xFF88D4F0);

class SeriCalendarSheet extends StatefulWidget {
  final String uid;
  final int currentSeri;

  const SeriCalendarSheet(
      {super.key, required this.uid, required this.currentSeri});

  static void show(BuildContext context,
      {required String uid, required int seri}) {
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
  Set<String> _frozenDates = {};
  int _streakFreezes = 0;
  bool _loading = true;

  static const _monthNames = [
    '',
    'Ocak',
    'Şubat',
    'Mart',
    'Nisan',
    'Mayıs',
    'Haziran',
    'Temmuz',
    'Ağustos',
    'Eylül',
    'Ekim',
    'Kasım',
    'Aralık',
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
    final start = _month;
    final end = DateTime(_month.year, _month.month + 1);

    final results = await Future.wait<dynamic>([
      FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .collection('logs')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('createdAt', isLessThan: Timestamp.fromDate(end))
          .get(),
      FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .get(),
    ]);

    final logsSnap = results[0] as QuerySnapshot;
    final userSnap = results[1] as DocumentSnapshot;
    final userData = userSnap.data() as Map<String, dynamic>?;

    final days = <String>{};
    for (final doc in logsSnap.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final type = data['type'] as String?;
      if (type != 'arapca' && type != 'meal') continue;
      final ts = data['createdAt'] as Timestamp?;
      if (ts != null) {
        final d = ts.toDate().toLocal();
        days.add(seriDateKey(d));
      }
    }

    final allFrozen = Set<String>.from(
      (userData?['frozenDates'] as List<dynamic>?) ?? [],
    );
    final freezes = (userData?['streakFreezes'] as int?) ?? 0;

    if (mounted) {
      setState(() {
        _logDays = days;
        _frozenDates = allFrozen;
        _streakFreezes = freezes;
        _loading = false;
      });
    }
  }

  bool get _canGoNext {
    final now = DateTime.now();
    return _month.isBefore(DateTime(now.year, now.month));
  }

  void _prevMonth() {
    setState(() {
      _month = DateTime(_month.year, _month.month - 1);
      _logDays = {};
      _loading = true;
    });
    _loadLogs();
  }

  void _nextMonth() {
    if (!_canGoNext) return;
    setState(() {
      _month = DateTime(_month.year, _month.month + 1);
      _logDays = {};
      _loading = true;
    });
    _loadLogs();
  }

  @override
  Widget build(BuildContext context) {
    final daysInMonth =
        DateUtils.getDaysInMonth(_month.year, _month.month);
    final firstWeekday =
        DateTime(_month.year, _month.month, 1).weekday;
    final today = DateTime.now();
    final isCurrentMonth =
        _month.year == today.year && _month.month == today.month;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.92,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: RefreshIndicator(
          onRefresh: _loadLogs,
          child: ListView(
            controller: controller,
            padding: EdgeInsets.zero,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.borderGrey,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header: başlık + freeze chip + seri chip
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
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                  // Freeze chip
                  if (!_loading)
                    _FreezeChip(count: _streakFreezes),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.orange.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${widget.currentSeri} günlük seri',
                      style: GoogleFonts.nunito(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
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
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: _canGoNext ? _nextMonth : null,
                    color: _canGoNext
                        ? AppColors.textMid
                        : AppColors.borderGrey,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 4),

            // Gün isimleri
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: _dayLabels
                    .map((d) => Expanded(
                          child: Center(
                            child: Text(
                              d,
                              style: GoogleFonts.nunito(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textLight,
                              ),
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ),

            const SizedBox(height: 6),

            // Takvim ızgarası
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    childAspectRatio: 1,
                  ),
                  itemCount: (firstWeekday - 1) + daysInMonth,
                  itemBuilder: (_, i) {
                    if (i < firstWeekday - 1) return const SizedBox();
                    final day = i - (firstWeekday - 1) + 1;
                    final key =
                        seriDateKey(DateTime(_month.year, _month.month, day));
                    final hasLog = _logDays.contains(key);
                    final isFrozen =
                        _frozenDates.contains(key) && !hasLog;
                    final isToday =
                        isCurrentMonth && day == today.day;
                    final isFuture =
                        isCurrentMonth && day > today.day;

                    return _CalendarCell(
                      day: day,
                      hasLog: hasLog,
                      isFrozen: isFrozen,
                      isToday: isToday,
                      isFuture: isFuture,
                    );
                  },
                ),
              ),

            const SizedBox(height: 12),

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

            const SizedBox(height: 12),

            // Hasanat ile satın al (disabled — yakında)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _BuyFreezeButton(),
            ),

            const SizedBox(height: 28),
          ],
        ),
        ),
      ),
    );
  }
}

// ─── Calendar Cell ────────────────────────────────────────────────────────────

class _CalendarCell extends StatelessWidget {
  final int day;
  final bool hasLog;
  final bool isFrozen;
  final bool isToday;
  final bool isFuture;

  const _CalendarCell({
    required this.day,
    required this.hasLog,
    required this.isFrozen,
    required this.isToday,
    required this.isFuture,
  });

  @override
  Widget build(BuildContext context) {
    Color? bgColor;
    BoxBorder? border;
    Color textColor = AppColors.textDark;
    FontWeight fontWeight = FontWeight.w500;
    Widget? overlay;

    if (isFuture) {
      textColor = AppColors.borderGrey;
    } else if (hasLog) {
      bgColor = AppColors.orange;
      textColor = Colors.white;
      fontWeight = FontWeight.w800;
    } else if (isFrozen) {
      bgColor = _kIceBg;
      textColor = _kIceDark;
      fontWeight = FontWeight.w700;
      overlay = const Text('❄️', style: TextStyle(fontSize: 8));
    } else if (isToday) {
      border = Border.all(color: AppColors.orange, width: 1.5);
      textColor = AppColors.orange;
      fontWeight = FontWeight.w700;
    }

    Widget cell = Center(
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: bgColor,
          border: border,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(
              '$day',
              style: GoogleFonts.nunito(
                fontSize: 12,
                fontWeight: fontWeight,
                color: textColor,
              ),
            ),
            if (overlay != null)
              Positioned(bottom: 2, right: 2, child: overlay),
          ],
        ),
      ),
    );

    return cell;
  }
}

// ─── Freeze chip (üst sağ, hak sayısı) ───────────────────────────────────────

class _FreezeChip extends StatelessWidget {
  final int count;
  const _FreezeChip({required this.count});

  void _showInfo(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _FreezeInfoSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasFreeze = count > 0;
    return GestureDetector(
      onTap: () => _showInfo(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: hasFreeze ? _kIceBg : AppColors.lightGrey,
          borderRadius: BorderRadius.circular(999),
          border: hasFreeze ? Border.all(color: _kIceBorder, width: 1) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shield_rounded,
                size: 13,
                color: hasFreeze ? _kIce : AppColors.textLight),
            const SizedBox(width: 4),
            Text(
              '$count hak',
              style: GoogleFonts.nunito(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: hasFreeze ? _kIceDark : AppColors.textLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Freeze bilgi bottom sheet ────────────────────────────────────────────────

class _FreezeInfoSheet extends StatelessWidget {
  const _FreezeInfoSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tutamaç
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.lightGrey,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Başlık
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _kIceBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _kIceBorder),
                ),
                child: const Icon(Icons.shield_rounded,
                    color: _kIce, size: 22),
              ),
              const SizedBox(width: 12),
              Text(
                'Seri Dondurma',
                style: GoogleFonts.nunito(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Açıklama
          Text(
            'Bir gün okuma yapamazsan serinizi kurtarır. '
            'Hakkın varsa, eksik günler uygulamayı açtığında otomatik olarak dondurulur — takvimde ❄️ olarak görünür.',
            style: GoogleFonts.nunito(
              fontSize: 14,
              height: 1.55,
              color: AppColors.textMid,
            ),
          ),
          const SizedBox(height: 24),

          // Nasıl kazanılır
          Text(
            'Nasıl kazanılır?',
            style: GoogleFonts.nunito(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 10),
          ..._milestones.map((m) => _MilestoneRow(
                days: m.days,
                label: m.label,
                grants: m.grants,
              )),
          const SizedBox(height: 20),

          // Limit notu
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF6F8FA),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.lightGrey),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    size: 16, color: AppColors.textLight),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Maksimum 2 hak birikilebilir (Pro: 5 hak).',
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      color: AppColors.textMid,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Hasanat ile satın al (yakında)
          Opacity(
            opacity: 0.45,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBF0),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFFD166)),
              ),
              child: Row(
                children: [
                  const Text('✨', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Hasanat ile satın al',
                      style: GoogleFonts.nunito(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD166).withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      'yakında',
                      style: GoogleFonts.nunito(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMid,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Kapat butonu
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(
                'Tamam',
                style: GoogleFonts.nunito(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _kIceDark,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MilestoneData {
  final int days;
  final String label;
  final int grants;
  const _MilestoneData(this.days, this.label, this.grants);
}

const _milestones = [
  _MilestoneData(7,  '7 günlük seri',  1),
  _MilestoneData(14, '14 günlük seri', 1),
  _MilestoneData(21, '21 günlük seri', 1),
  _MilestoneData(40, '40 günlük seri', 2),
];

class _MilestoneRow extends StatelessWidget {
  final int days;
  final String label;
  final int grants;

  const _MilestoneRow({
    required this.days,
    required this.label,
    required this.grants,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _kIceBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                '$days',
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: _kIceDark,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.nunito(
                fontSize: 13,
                color: AppColors.textDark,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _kIceBg,
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: _kIceBorder),
            ),
            child: Text(
              '+$grants hak',
              style: GoogleFonts.nunito(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: _kIceDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}


// ─── Buy Freeze Button (disabled — yakında) ───────────────────────────────────

class _BuyFreezeButton extends StatelessWidget {
  const _BuyFreezeButton();

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.55,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.lightGrey,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderGrey),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('💎', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Text(
                  'Hasanat ile Seri Dondurma Satın Al',
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMid,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: -8,
            right: 12,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.orange,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'Yakında',
                style: GoogleFonts.nunito(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Summary Chip ─────────────────────────────────────────────────────────────

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
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.lightGrey,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            if (!hideIcon) Text(icon, style: const TextStyle(fontSize: 16)),
            if (!hideIcon) const SizedBox(height: 2),
            Text(
              value,
              style: GoogleFonts.nunito(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.nunito(
                fontSize: 11,
                color: AppColors.textLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
