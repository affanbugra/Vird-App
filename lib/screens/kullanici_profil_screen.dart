import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../app_colors.dart';
import '../data/quran_cuz.dart';

String _fmt(int n) {
  final s = n.toString();
  if (s.length <= 3) return s;
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
    buf.write(s[i]);
  }
  return buf.toString();
}

// ─── Ana ekran ─────────────────────────────────────────────────────────────────

class KullaniciProfilScreen extends StatefulWidget {
  final String uid;

  const KullaniciProfilScreen({super.key, required this.uid});

  @override
  State<KullaniciProfilScreen> createState() => _KullaniciProfilScreenState();
}

enum _HeatType { arapca, meal }
enum _HeatTime { all, month, year }

class _KullaniciProfilScreenState extends State<KullaniciProfilScreen> {
  _HeatType _typeFilter = _HeatType.arapca;
  _HeatTime _timeFilter = _HeatTime.all;
  int? _selectedPage;

  Query<Map<String, dynamic>> _logsQuery() {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(widget.uid)
        .collection('logs')
        .where('type',
            isEqualTo: _typeFilter == _HeatType.meal ? 'meal' : 'arapca');
  }

  Map<int, int> _buildReadings(List<QueryDocumentSnapshot> logs) {
    final Map<int, int> readings = {};
    final now = DateTime.now();
    final DateTime? cutoff = _timeFilter == _HeatTime.month
        ? now.subtract(const Duration(days: 30))
        : _timeFilter == _HeatTime.year
            ? now.subtract(const Duration(days: 365))
            : null;

    for (final doc in logs) {
      final data = doc.data() as Map<String, dynamic>;
      if (cutoff != null) {
        final ts = data['createdAt'] as Timestamp?;
        if (ts == null || ts.toDate().isBefore(cutoff)) continue;
      }
      final start = data['startPage'] as int?;
      final end = data['endPage'] as int?;
      if (start != null && end != null) {
        for (int p = start; p <= end && p <= 604; p++) {
          readings[p] = (readings[p] ?? 0) + 1;
        }
      }
    }
    return readings;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(widget.uid)
            .snapshots(),
        builder: (context, snap) {
          Map<String, dynamic>? data;
          if (snap.hasData && snap.data!.exists) {
            data = snap.data!.data() as Map<String, dynamic>;
          }

          final name =
              (data?['name'] as String?) ?? 'İsimsiz Kullanıcı';
          final username = (data?['username'] as String?) ?? '';
          final cityRaw = data?['city'] as String?;
          final uniRaw = data?['university'] as String?;
          final city = (cityRaw == 'Şehir belirtilmedi' ||
                  cityRaw == null ||
                  cityRaw.isEmpty)
              ? null
              : cityRaw;
          final uni = (uniRaw == 'Üniversite belirtilmedi' ||
                  uniRaw == null ||
                  uniRaw.isEmpty)
              ? null
              : uniRaw;
          final avatarSeed = data?['avatarSeed'] as String?;
          final isPro = (data?['isPro'] as bool?) ?? false;
          final isHafiz = (data?['isHafiz'] as bool?) ?? false;
          final seri = (data?['seri'] as int?) ?? 0;
          final hasanat = (data?['hasanat'] as int?) ?? 0;
          final totalPages = (data?['totalPages'] as int?) ?? 0;

          return StreamBuilder<QuerySnapshot>(
            stream: _logsQuery().snapshots(),
            builder: (context, logsSnap) {
              final readings = logsSnap.hasData
                  ? _buildReadings(logsSnap.data!.docs)
                  : <int, int>{};

              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(widget.uid)
                    .collection('hatims')
                    .where('isCompleted', isEqualTo: true)
                    .snapshots(),
                builder: (context, hatimSnap) {
                  final hatimCount = hatimSnap.data?.size ?? 0;

                  return CustomScrollView(
                    slivers: [
                      // AppBar + banner
                      SliverAppBar(
                        pinned: true,
                        expandedHeight: 96,
                        backgroundColor: AppColors.teal,
                        foregroundColor: Colors.white,
                        flexibleSpace: FlexibleSpaceBar(
                          background: Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Color(0xFF2A7F8C),
                                  Color(0xFF236D79)
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Avatar + isim
                      SliverToBoxAdapter(
                        child: _UserHeader(
                          name: name,
                          username: username,
                          city: city,
                          university: uni,
                          avatarSeed: avatarSeed,
                          isPro: isPro,
                          isHafiz: isHafiz,
                        ),
                      ),

                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            // İstatistikler
                            _StatGrid(
                              seri: seri,
                              hasanat: hasanat,
                              hatimCount: hatimCount,
                              totalPages: totalPages,
                            ),
                            const SizedBox(height: 12),
                            // Kuran haritası
                            _HeatMapCard(
                              typeFilter: _typeFilter,
                              timeFilter: _timeFilter,
                              readings: readings,
                              selectedPage: _selectedPage,
                              onTypeChanged: (f) => setState(() {
                                _typeFilter = f;
                                _selectedPage = null;
                              }),
                              onTimeChanged: (f) => setState(() {
                                _timeFilter = f;
                                _selectedPage = null;
                              }),
                              onPageTap: (p) =>
                                  setState(() => _selectedPage = p),
                            ),
                            const SizedBox(height: 24),
                          ]),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

// ─── Kullanıcı başlığı ─────────────────────────────────────────────────────────

class _UserHeader extends StatelessWidget {
  final String name;
  final String username;
  final String? city;
  final String? university;
  final String? avatarSeed;
  final bool isPro;
  final bool isHafiz;

  const _UserHeader({
    required this.name,
    required this.username,
    required this.city,
    required this.university,
    required this.avatarSeed,
    required this.isPro,
    required this.isHafiz,
  });

  @override
  Widget build(BuildContext context) {
    const double avatarR = 36;
    final locationParts =
        [city, university].where((e) => e != null && e.isNotEmpty).toList();

    return Padding(
      padding: const EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isHafiz ? AppColors.gold : Colors.white,
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: CircleAvatar(
              radius: avatarR,
              backgroundColor: AppColors.tealLight,
              backgroundImage: avatarSeed != null
                  ? NetworkImage(
                      'https://api.dicebear.com/7.x/micah/png?seed=$avatarSeed&backgroundColor=transparent',
                    )
                  : null,
              child: avatarSeed == null
                  ? Text(
                      name.isNotEmpty
                          ? name
                              .substring(0, name.length >= 2 ? 2 : 1)
                              .toUpperCase()
                          : '?',
                      style: GoogleFonts.nunito(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.teal,
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        style: GoogleFonts.nunito(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                    if (isPro) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.tealLight,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'PRO',
                          style: GoogleFonts.nunito(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: AppColors.teal,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (username.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    '@$username',
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMid,
                    ),
                  ),
                ],
                if (locationParts.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    locationParts.join(' · '),
                    style: GoogleFonts.nunito(
                      fontSize: 11,
                      color: AppColors.textLight,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── İstatistik Grid ──────────────────────────────────────────────────────────

class _StatGrid extends StatelessWidget {
  final int seri;
  final int hasanat;
  final int hatimCount;
  final int totalPages;

  const _StatGrid({
    required this.seri,
    required this.hasanat,
    required this.hatimCount,
    required this.totalPages,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
              child: _StatCard(
                  icon: '🔥',
                  value: _fmt(seri),
                  label: 'SERİ',
                  color: AppColors.orange)),
          const SizedBox(width: 8),
          Expanded(
              child: _StatCard(
                  icon: '✨',
                  value: _fmt(hasanat),
                  label: 'HASANAT',
                  color: AppColors.gold)),
          const SizedBox(width: 8),
          Expanded(
              child: _StatCard(
                  icon: '📖',
                  value: _fmt(hatimCount),
                  label: 'HATİM',
                  color: AppColors.teal)),
          const SizedBox(width: 8),
          Expanded(
              child: _StatCard(
                  icon: '📄',
                  value: _fmt(totalPages),
                  label: 'SAYFA',
                  color: AppColors.teal)),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String icon;
  final String value;
  final String label;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(color: AppColors.borderGrey),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 3),
          Text(
            value,
            style: GoogleFonts.nunito(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: 7.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textLight,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Kuran Haritası Kartı ─────────────────────────────────────────────────────

class _HeatMapCard extends StatelessWidget {
  final _HeatType typeFilter;
  final _HeatTime timeFilter;
  final Map<int, int> readings;
  final int? selectedPage;
  final ValueChanged<_HeatType> onTypeChanged;
  final ValueChanged<_HeatTime> onTimeChanged;
  final ValueChanged<int> onPageTap;

  const _HeatMapCard({
    required this.typeFilter,
    required this.timeFilter,
    required this.readings,
    required this.selectedPage,
    required this.onTypeChanged,
    required this.onTimeChanged,
    required this.onPageTap,
  });

  @override
  Widget build(BuildContext context) {
    final isMeal = typeFilter == _HeatType.meal;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(color: AppColors.borderGrey),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kuran Haritası',
                      style: GoogleFonts.nunito(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                    Text(
                      'Her kare bir sayfa — 604 sayfa, 30 cüz',
                      style: GoogleFonts.nunito(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMid,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () => onTypeChanged(_HeatType.arapca),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: !isMeal ? AppColors.teal : AppColors.lightGrey,
                        borderRadius: const BorderRadius.horizontal(
                            left: Radius.circular(999)),
                      ),
                      child: Text(
                        'ARAPÇA',
                        style: GoogleFonts.nunito(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: !isMeal ? Colors.white : AppColors.textMid,
                        ),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => onTypeChanged(_HeatType.meal),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: isMeal ? AppColors.teal : AppColors.lightGrey,
                        borderRadius: const BorderRadius.horizontal(
                            right: Radius.circular(999)),
                      ),
                      child: Text(
                        'MEAL',
                        style: GoogleFonts.nunito(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isMeal ? Colors.white : AppColors.textMid,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _Chip(
                  label: 'Tüm zamanlar',
                  selected: timeFilter == _HeatTime.all,
                  onTap: () => onTimeChanged(_HeatTime.all),
                ),
                const SizedBox(width: 6),
                _Chip(
                  label: 'Son 1 ay',
                  selected: timeFilter == _HeatTime.month,
                  onTap: () => onTimeChanged(_HeatTime.month),
                ),
                const SizedBox(width: 6),
                _Chip(
                  label: 'Son 1 yıl',
                  selected: timeFilter == _HeatTime.year,
                  onTap: () => onTimeChanged(_HeatTime.year),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _HeatGrid(
              readings: readings,
              selectedPage: selectedPage,
              onPageTap: onPageTap),
          _Legend(),
          _DetailPanel(
            page: selectedPage,
            readings: readings,
            maxCount: readings.isEmpty
                ? 0
                : readings.values.fold(0, (a, b) => a > b ? a : b),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Chip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.tealLight : AppColors.white,
          border: Border.all(
            color: selected ? AppColors.teal : AppColors.borderGrey,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: GoogleFonts.nunito(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: selected ? AppColors.teal : AppColors.textMid,
          ),
        ),
      ),
    );
  }
}

// ─── Isı Haritası Grid ────────────────────────────────────────────────────────

class _HeatGrid extends StatelessWidget {
  final Map<int, int> readings;
  final int? selectedPage;
  final ValueChanged<int> onPageTap;

  const _HeatGrid({
    required this.readings,
    required this.selectedPage,
    required this.onPageTap,
  });

  static const double _labelW = 14;
  static const double _labelGap = 5;
  static const double _squareGap = 2;
  static const int _maxPages = 20;

  static double _sq(double w) {
    return (w - _labelW - _labelGap - _maxPages * _squareGap) / _maxPages;
  }

  Widget _square(int page, double sq, double r, int maxCount) {
    final count = readings[page] ?? 0;
    final sel = selectedPage == page;
    return GestureDetector(
      onTap: () => onPageTap(page),
      child: Container(
        width: sq,
        height: sq,
        margin: const EdgeInsets.only(right: _squareGap),
        decoration: BoxDecoration(
          color: QuranData.heatColorRelative(count, maxCount),
          borderRadius: BorderRadius.circular(r),
          border: sel ? Border.all(color: AppColors.textDark, width: 1) : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final sq = _sq(constraints.maxWidth);
      final r = (sq * 0.22).clamp(1.5, 4.0);
      final maxCount = readings.isEmpty
          ? 0
          : readings.values.fold(0, (a, b) => a > b ? a : b);
      final fatihaCount = readings[1] ?? 0;
      final fatihaSelected = selectedPage == 0;

      final labelStyle = GoogleFonts.nunito(
        fontSize: 8,
        fontWeight: FontWeight.w700,
        color: AppColors.textLight,
      );

      final rows = <Widget>[];

      rows.add(Padding(
        padding: const EdgeInsets.only(bottom: _squareGap),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(width: _labelW + _labelGap),
            GestureDetector(
              onTap: () => onPageTap(0),
              child: Container(
                width: sq,
                height: sq,
                decoration: BoxDecoration(
                  color: QuranData.heatColorRelative(fatihaCount, maxCount),
                  borderRadius: BorderRadius.circular(r),
                  border: fatihaSelected
                      ? Border.all(color: AppColors.textDark, width: 1)
                      : null,
                ),
              ),
            ),
            const SizedBox(width: 5),
            Text('Fâtiha', style: labelStyle),
          ],
        ),
      ));

      for (final cuz in QuranData.cuzler) {
        if (cuz.cuzNo < 30) {
          rows.add(Padding(
            padding: const EdgeInsets.only(bottom: _squareGap),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: _labelW,
                  child: Text('${cuz.cuzNo}',
                      textAlign: TextAlign.right, style: labelStyle),
                ),
                const SizedBox(width: _labelGap),
                ...List.generate(
                    cuz.pageCount,
                    (i) => _square(cuz.startPage + i, sq, r, maxCount)),
              ],
            ),
          ));
        } else {
          rows.add(Padding(
            padding: const EdgeInsets.only(bottom: _squareGap),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: _labelW,
                  child: Text('30',
                      textAlign: TextAlign.right, style: labelStyle),
                ),
                const SizedBox(width: _labelGap),
                ...List.generate(20, (i) => _square(581 + i, sq, r, maxCount)),
              ],
            ),
          ));
          rows.add(Padding(
            padding: const EdgeInsets.only(bottom: _squareGap),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(width: _labelW + _labelGap),
                ...List.generate(4, (i) => _square(601 + i, sq, r, maxCount)),
                const SizedBox(width: 3),
                Text('İhlâs · Felak · Nâs', style: labelStyle),
              ],
            ),
          ));
        }
      }

      return Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: rows);
    });
  }
}

// ─── Lejant ───────────────────────────────────────────────────────────────────

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    const levels = [0, 1, 3, 6, 11, 21];
    return LayoutBuilder(builder: (context, constraints) {
      final sq =
          (_HeatGrid._sq(constraints.maxWidth)).clamp(8.0, 14.0);
      final r = (sq * 0.22).clamp(1.5, 4.0);
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text('Az',
                style: GoogleFonts.nunito(
                    fontSize: 10, color: AppColors.textMid)),
            const SizedBox(width: 4),
            ...levels.map((c) => Container(
                  width: sq,
                  height: sq,
                  margin: const EdgeInsets.only(right: 3),
                  decoration: BoxDecoration(
                    color: QuranData.heatColor(c),
                    borderRadius: BorderRadius.circular(r),
                  ),
                )),
            const SizedBox(width: 1),
            Text('Çok',
                style: GoogleFonts.nunito(
                    fontSize: 10, color: AppColors.textMid)),
          ],
        ),
      );
    });
  }
}

// ─── Detay Paneli ─────────────────────────────────────────────────────────────

class _DetailPanel extends StatelessWidget {
  final int? page;
  final Map<int, int> readings;
  final int maxCount;

  const _DetailPanel(
      {required this.page, required this.readings, required this.maxCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.lightGrey,
        borderRadius: BorderRadius.circular(8),
      ),
      child: page == null
          ? Text(
              'Detay için bir sayfaya dokun',
              style:
                  GoogleFonts.nunito(fontSize: 11, color: AppColors.textLight),
            )
          : _PageDetail(
              page: page!,
              count: readings[page] ?? 0,
              maxCount: maxCount),
    );
  }
}

class _PageDetail extends StatelessWidget {
  final int page;
  final int count;
  final int maxCount;

  const _PageDetail(
      {required this.page, required this.count, required this.maxCount});

  @override
  Widget build(BuildContext context) {
    final cuz = QuranData.cuzForPage(page);
    final surahText = QuranData.surahsOnPage(page);
    final pageLabel =
        page == 0 ? 'Fâtiha · Cüz 1' : 'Sayfa $page · Cüz ${cuz?.cuzNo ?? '?'}';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                pageLabel,
                style: GoogleFonts.nunito(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
              if (surahText.isNotEmpty)
                Text(
                  surahText,
                  style:
                      GoogleFonts.nunito(fontSize: 10, color: AppColors.textMid),
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.white,
            border: Border.all(color: AppColors.borderGrey),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '$count okuma',
            style: GoogleFonts.nunito(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: count == 0
                  ? AppColors.textLight
                  : QuranData.heatColorRelative(count, maxCount),
            ),
          ),
        ),
      ],
    );
  }
}
