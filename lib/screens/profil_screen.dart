import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import '../app_colors.dart';
import '../providers/auth_provider.dart';
import '../data/quran_cuz.dart';
import '../widgets/duolingo_button.dart';

enum HeatTypeFilter { arapca, meal }
enum HeatTimeFilter { all, month, year }

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

// ─── Ana ekran ───────────────────────────────────────────────────────────────

class ProfilScreen extends StatefulWidget {
  const ProfilScreen({super.key});

  @override
  State<ProfilScreen> createState() => _ProfilScreenState();
}

class _ProfilScreenState extends State<ProfilScreen> {
  HeatTypeFilter _typeFilter = HeatTypeFilter.arapca;
  HeatTimeFilter _timeFilter = HeatTimeFilter.all;
  int? _selectedPage;

  void _showSettings(BuildContext context, Map<String, dynamic> userData, User user) {
    final auth = context.read<AuthProvider>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _SettingsSheet(
        userData: userData,
        user: user,
        onSignOut: () {
          Navigator.of(context).pop();
          auth.signOut();
        },
      ),
    );
  }

  /// Firestore loglarından sayfa bazlı okuma sayılarını hesaplar (zaman filtresi client-side)
  Map<int, int> _buildReadingsFromLogs(List<QueryDocumentSnapshot> logs) {
    final Map<int, int> readings = {};
    final now = DateTime.now();
    final DateTime? cutoff = _timeFilter == HeatTimeFilter.month
        ? now.subtract(const Duration(days: 30))
        : _timeFilter == HeatTimeFilter.year
            ? now.subtract(const Duration(days: 365))
            : null;

    for (final doc in logs) {
      final data = doc.data() as Map<String, dynamic>;
      if (cutoff != null) {
        final ts = data['createdAt'] as Timestamp?;
        if (ts == null || ts.toDate().isBefore(cutoff)) continue;
      }
      final startPage = data['startPage'] as int?;
      final endPage = data['endPage'] as int?;
      if (startPage != null && endPage != null) {
        for (int p = startPage; p <= endPage && p <= 604; p++) {
          readings[p] = (readings[p] ?? 0) + 1;
        }
      }
    }
    return readings;
  }

  /// Tür filtresine göre Firestore query — zaman filtresi client-side yapılır
  Query<Map<String, dynamic>> _buildLogsQuery(String uid) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('logs')
        .where('type', isEqualTo: _typeFilter == HeatTypeFilter.meal ? 'meal' : 'arapca');
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('Kullanıcı bulunamadı'));
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (context, snapshot) {
        Map<String, dynamic>? data;
        if (snapshot.hasData && snapshot.data!.exists) {
          data = snapshot.data!.data() as Map<String, dynamic>;
        }

        final name = (data?['name'] as String?) ?? user.displayName ?? 'İsimsiz Kullanıcı';
        final username = (data?['username'] as String?) ?? '';
        final cityRaw = data?['city'] as String?;
        final uniRaw = data?['university'] as String?;
        final city = (cityRaw == 'Şehir belirtilmedi' || cityRaw == null || cityRaw.isEmpty) ? null : cityRaw;
        final uni = (uniRaw == 'Üniversite belirtilmedi' || uniRaw == null || uniRaw.isEmpty) ? null : uniRaw;
        final avatarSeed = data?['avatarSeed'] as String?;
        final isPro = (data?['isPro'] as bool?) ?? false;
        final isHafiz = (data?['isHafiz'] as bool?) ?? false;
        final seri = (data?['seri'] as int?) ?? 0;
        final hasanat = (data?['hasanat'] as int?) ?? 0;
        final hatimCount = (data?['hatimCount'] as int?) ?? 0;
        final totalPages = (data?['totalPages'] as int?) ?? 0;

        return StreamBuilder<QuerySnapshot>(
          stream: _buildLogsQuery(user.uid).snapshots(),
          builder: (context, logsSnapshot) {
            final readings = logsSnapshot.hasData
                ? _buildReadingsFromLogs(logsSnapshot.data!.docs)
                : <int, int>{};

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ProfileHeader(
                    name: name,
                    username: username,
                    city: city,
                    university: uni,
                    avatarSeed: avatarSeed,
                    isPro: isPro,
                    isHafiz: isHafiz,
                    onSettingsTap: () => _showSettings(context, data ?? {}, user),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 12),
                        _StatGrid(
                          seri: seri,
                          hasanat: hasanat,
                          hatimCount: hatimCount,
                          totalPages: totalPages,
                        ),
                        const SizedBox(height: 12),
                        _KuranHaritasiCard(
                          typeFilter: _typeFilter,
                          timeFilter: _timeFilter,
                          readings: readings,
                          selectedPage: _selectedPage,
                          onTypeFilterChanged: (f) => setState(() {
                            _typeFilter = f;
                            _selectedPage = null;
                          }),
                          onTimeFilterChanged: (f) => setState(() {
                            _timeFilter = f;
                            _selectedPage = null;
                          }),
                          onPageTap: (p) => setState(() => _selectedPage = p),
                        ),
                        const SizedBox(height: 24),
                      ],
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
}

// ─── Profil Header ────────────────────────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  final String name;
  final String username;
  final String? city;
  final String? university;
  final String? avatarSeed;
  final bool isPro;
  final bool isHafiz;
  final VoidCallback onSettingsTap;

  const _ProfileHeader({
    required this.name,
    required this.username,
    required this.city,
    required this.university,
    required this.avatarSeed,
    required this.isPro,
    required this.isHafiz,
    required this.onSettingsTap,
  });

  @override
  Widget build(BuildContext context) {
    const double bannerH = 96;
    const double avatarR = 39;

    final locationParts = [city, university].where((e) => e != null && e.isNotEmpty).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              height: bannerH,
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF2A7F8C), Color(0xFF236D79)],
                ),
              ),
            ),
            Positioned(
              top: 10,
              right: 12,
              child: GestureDetector(
                onTap: onSettingsTap,
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.settings_outlined, color: Colors.white, size: 19),
                ),
              ),
            ),
            Positioned(
              bottom: -avatarR,
              left: 16,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isHafiz ? AppColors.gold : Colors.white,
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
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
                          name.isNotEmpty ? name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase() : '?',
                          style: GoogleFonts.nunito(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.teal,
                          ),
                        )
                      : null,
                ),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: 49, left: 16, right: 16, bottom: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    name,
                    style: GoogleFonts.nunito(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                  ),
                  if (isPro) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
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
                    fontSize: 12.5,
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
          Expanded(child: _StatCard(icon: '🔥', value: _fmt(seri), label: 'SERİ', color: AppColors.orange)),
          const SizedBox(width: 8),
          Expanded(child: _StatCard(icon: '✨', value: _fmt(hasanat), label: 'HASANAT', color: AppColors.gold)),
          const SizedBox(width: 8),
          Expanded(child: _StatCard(icon: '📖', value: _fmt(hatimCount), label: 'HATİM', color: AppColors.teal)),
          const SizedBox(width: 8),
          Expanded(child: _StatCard(icon: '📄', value: _fmt(totalPages), label: 'SAYFA', color: AppColors.teal)),
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

class _KuranHaritasiCard extends StatelessWidget {
  final HeatTypeFilter typeFilter;
  final HeatTimeFilter timeFilter;
  final Map<int, int> readings;
  final int? selectedPage;
  final ValueChanged<HeatTypeFilter> onTypeFilterChanged;
  final ValueChanged<HeatTimeFilter> onTimeFilterChanged;
  final ValueChanged<int> onPageTap;

  const _KuranHaritasiCard({
    required this.typeFilter,
    required this.timeFilter,
    required this.readings,
    required this.selectedPage,
    required this.onTypeFilterChanged,
    required this.onTimeFilterChanged,
    required this.onPageTap,
  });

  @override
  Widget build(BuildContext context) {
    final isMeal = typeFilter == HeatTypeFilter.meal;

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
          // Başlık satırı
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
                    onTap: () => onTypeFilterChanged(HeatTypeFilter.arapca),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: !isMeal ? AppColors.teal : AppColors.lightGrey,
                        borderRadius: const BorderRadius.horizontal(left: Radius.circular(999)),
                      ),
                      child: Text('ARAPÇA', style: GoogleFonts.nunito(
                        fontSize: 10, fontWeight: FontWeight.w700,
                        color: !isMeal ? Colors.white : AppColors.textMid,
                      )),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => onTypeFilterChanged(HeatTypeFilter.meal),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: isMeal ? AppColors.teal : AppColors.lightGrey,
                        borderRadius: const BorderRadius.horizontal(right: Radius.circular(999)),
                      ),
                      child: Text('MEAL', style: GoogleFonts.nunito(
                        fontSize: 10, fontWeight: FontWeight.w700,
                        color: isMeal ? Colors.white : AppColors.textMid,
                      )),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Zaman filtresi
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(
                  label: 'Tüm zamanlar',
                  isSelected: timeFilter == HeatTimeFilter.all,
                  onTap: () => onTimeFilterChanged(HeatTimeFilter.all),
                ),
                const SizedBox(width: 6),
                _FilterChip(
                  label: 'Son 1 ay',
                  isSelected: timeFilter == HeatTimeFilter.month,
                  onTap: () => onTimeFilterChanged(HeatTimeFilter.month),
                ),
                const SizedBox(width: 6),
                _FilterChip(
                  label: 'Son 1 yıl',
                  isSelected: timeFilter == HeatTimeFilter.year,
                  onTap: () => onTimeFilterChanged(HeatTimeFilter.year),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Isı haritası
          _HeatGrid(readings: readings, selectedPage: selectedPage, onPageTap: onPageTap),
          // Lejant
          _Legend(),
          // Detay paneli
          _DetailPanel(page: selectedPage, readings: readings, maxCount: readings.isEmpty ? 0 : readings.values.fold(0, (a, b) => a > b ? a : b)),
        ],
      ),
    );
  }
}

// ─── Filtre Chip ──────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.tealLight : AppColors.white,
          border: Border.all(
            color: isSelected ? AppColors.teal : AppColors.borderGrey,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: GoogleFonts.nunito(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: isSelected ? AppColors.teal : AppColors.textMid,
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

  // Her cüz tam 20 sayfa — en geniş satır 20 kare, tam ekran dolacak şekilde.
  static const double _labelW = 14;
  static const double _labelGap = 5;
  static const double _squareGap = 2;
  static const int _maxPages = 20;

  static double _squareSize(double availableWidth) {
    final squaresArea = availableWidth - _labelW - _labelGap;
    return (squaresArea - _maxPages * _squareGap) / _maxPages;
  }

  Widget _buildSquare(int page, double sq, double radius, int maxCount) {
    final count = readings[page] ?? 0;
    final isSelected = selectedPage == page;
    return GestureDetector(
      onTap: () => onPageTap(page),
      child: Container(
        width: sq,
        height: sq,
        margin: const EdgeInsets.only(right: _squareGap),
        decoration: BoxDecoration(
          color: QuranData.heatColorRelative(count, maxCount),
          borderRadius: BorderRadius.circular(radius),
          border: isSelected ? Border.all(color: AppColors.textDark, width: 1) : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final sq = _squareSize(constraints.maxWidth);
        final radius = (sq * 0.22).clamp(1.5, 4.0);
        final maxCount = readings.isEmpty ? 0 : readings.values.fold(0, (a, b) => a > b ? a : b);
        final fatihaCount = readings[1] ?? 0; // Fatiha rengi Bakara 1. sayfayla aynı
        final fatihaSelected = selectedPage == 0;

        final labelStyle = GoogleFonts.nunito(
          fontSize: 8,
          fontWeight: FontWeight.w700,
          color: AppColors.textLight,
        );

        final rows = <Widget>[];

        // ── Fatiha: 1 kare + "Fâtiha" etiketi sağda ──────────────────────
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
                    borderRadius: BorderRadius.circular(radius),
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

        // ── Cüz 1–29: her biri tam 20 sayfa ──────────────────────────────
        for (final cuz in QuranData.cuzler) {
          if (cuz.cuzNo < 30) {
            rows.add(Padding(
              padding: const EdgeInsets.only(bottom: _squareGap),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: _labelW,
                    child: Text('${cuz.cuzNo}', textAlign: TextAlign.right, style: labelStyle),
                  ),
                  const SizedBox(width: _labelGap),
                  ...List.generate(cuz.pageCount, (i) => _buildSquare(cuz.startPage + i, sq, radius, maxCount)),
                ],
              ),
            ));
          } else {
            // ── Cüz 30 — satır 1: label "30" + sayfa 581–600 (20 kare) ───
            rows.add(Padding(
              padding: const EdgeInsets.only(bottom: _squareGap),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: _labelW,
                    child: Text('30', textAlign: TextAlign.right, style: labelStyle),
                  ),
                  const SizedBox(width: _labelGap),
                  ...List.generate(20, (i) => _buildSquare(581 + i, sq, radius, maxCount)),
                ],
              ),
            ));
            // ── Cüz 30 — satır 2: sayfa 601–604 (4 kare) + etiket sağda ─
            rows.add(Padding(
              padding: const EdgeInsets.only(bottom: _squareGap),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(width: _labelW + _labelGap),
                  ...List.generate(4, (i) => _buildSquare(601 + i, sq, radius, maxCount)),
                  const SizedBox(width: 3),
                  Text('İhlâs · Felak · Nâs', style: labelStyle),
                ],
              ),
            ));
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: rows,
        );
      },
    );
  }
}

// ─── Lejant ───────────────────────────────────────────────────────────────────

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    const levels = [0, 1, 3, 6, 11, 21];
    return LayoutBuilder(
      builder: (context, constraints) {
        final sq = (_HeatGrid._squareSize(constraints.maxWidth)).clamp(8.0, 14.0);
        final radius = (sq * 0.22).clamp(1.5, 4.0);
        return Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text('Az', style: GoogleFonts.nunito(fontSize: 10, color: AppColors.textMid)),
              const SizedBox(width: 4),
              ...levels.map(
                (c) => Container(
                  width: sq,
                  height: sq,
                  margin: const EdgeInsets.only(right: 3),
                  decoration: BoxDecoration(
                    color: QuranData.heatColor(c),
                    borderRadius: BorderRadius.circular(radius),
                  ),
                ),
              ),
              const SizedBox(width: 1),
              Text('Çok', style: GoogleFonts.nunito(fontSize: 10, color: AppColors.textMid)),
            ],
          ),
        );
      },
    );
  }
}

// ─── Detay Paneli ─────────────────────────────────────────────────────────────

class _DetailPanel extends StatelessWidget {
  final int? page;
  final Map<int, int> readings;
  final int maxCount;

  const _DetailPanel({required this.page, required this.readings, required this.maxCount});

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
              style: GoogleFonts.nunito(fontSize: 11, color: AppColors.textLight),
            )
          : _PageDetail(page: page!, count: readings[page] ?? 0, maxCount: maxCount),
    );
  }
}

class _PageDetail extends StatelessWidget {
  final int page;
  final int count;
  final int maxCount;

  const _PageDetail({required this.page, required this.count, required this.maxCount});

  @override
  Widget build(BuildContext context) {
    final cuz = QuranData.cuzForPage(page);
    final surahText = QuranData.surahsOnPage(page);
    final pageLabel = page == 0 ? 'Fâtiha · Cüz 1' : 'Sayfa $page · Cüz ${cuz?.cuzNo ?? '?'}';

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
                  style: GoogleFonts.nunito(fontSize: 10, color: AppColors.textMid),
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
              color: count == 0 ? AppColors.textLight : QuranData.heatColorRelative(count, maxCount),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Ayarlar Bottom Sheet ─────────────────────────────────────────────────────

class _SettingsSheet extends StatelessWidget {
  final Map<String, dynamic> userData;
  final User user;
  final VoidCallback onSignOut;

  const _SettingsSheet({
    required this.userData,
    required this.user,
    required this.onSignOut,
  });

  void _showEditProfile(BuildContext context) {
    Navigator.pop(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _EditProfileSheet(userData: userData, user: user),
    );
  }

  void _showPasswordSheet(BuildContext context) {
    Navigator.pop(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _PasswordSheet(user: user),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppColors.borderGrey,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            'Ayarlar',
            style: GoogleFonts.nunito(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 20),
          _SettingsItem(
            icon: Icons.person_outline,
            title: 'Profili Düzenle',
            onTap: () => _showEditProfile(context),
          ),
          const SizedBox(height: 12),
          _SettingsItem(
            icon: Icons.lock_outline,
            title: 'Şifre İşlemleri',
            onTap: () => _showPasswordSheet(context),
          ),
          const SizedBox(height: 20),
          Text(
            'Gizlilik',
            style: GoogleFonts.nunito(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textMid,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.lightGrey,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Harita ve istatistiklerin kimler tarafından görülebileceğini belirle.\nYakında eklenecek.',
              style: GoogleFonts.nunito(
                fontSize: 13,
                color: AppColors.textLight,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onSignOut,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.errorRed),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
              ),
              child: Text(
                'ÇIKIŞ YAP',
                style: GoogleFonts.nunito(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.errorRed,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _SettingsItem({required this.icon, required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.borderGrey),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.textDark, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.nunito(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textMid),
          ],
        ),
      ),
    );
  }
}

// ─── Profil Düzenleme Sheet ───────────────────────────────────────────────────

class _EditProfileSheet extends StatefulWidget {
  final Map<String, dynamic> userData;
  final User user;

  const _EditProfileSheet({required this.userData, required this.user});

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _usernameCtrl;
  late TextEditingController _cityCtrl;
  late TextEditingController _uniCtrl;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.userData['name'] ?? widget.user.displayName ?? '');
    _usernameCtrl = TextEditingController(text: widget.userData['username'] ?? '');
    _cityCtrl = TextEditingController(text: (widget.userData['city'] == 'Şehir belirtilmedi') ? '' : widget.userData['city']);
    _uniCtrl = TextEditingController(text: (widget.userData['university'] == 'Üniversite belirtilmedi') ? '' : widget.userData['university']);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _usernameCtrl.dispose();
    _cityCtrl.dispose();
    _uniCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance.collection('users').doc(widget.user.uid).update({
        'name': _nameCtrl.text.trim(),
        'username': _usernameCtrl.text.trim(),
        'city': _cityCtrl.text.trim(),
        'university': _uniCtrl.text.trim(),
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.borderGrey,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'Profili Düzenle',
              style: GoogleFonts.nunito(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 20),
            _buildField(_nameCtrl, 'Ad Soyad', isRequired: true),
            const SizedBox(height: 12),
            _buildField(_usernameCtrl, 'Kullanıcı Adı (Opsiyonel)'),
            const SizedBox(height: 12),
            _buildField(_cityCtrl, 'Şehir (Opsiyonel)'),
            const SizedBox(height: 12),
            _buildField(_uniCtrl, 'Üniversite (Opsiyonel)'),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: DuolingoButton(
                color: AppColors.teal,
                bottomColor: AppColors.tealDark,
                disabledColor: AppColors.borderGrey,
                isLoading: _isLoading,
                onPressed: _isLoading ? null : _save,
                child: Text(
                  'KAYDET',
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(TextEditingController controller, String label, {bool isRequired = false}) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.nunito(color: AppColors.textMid),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.teal, width: 2),
        ),
      ),
      validator: isRequired
          ? (v) => (v == null || v.trim().isEmpty) ? 'Bu alan zorunludur' : null
          : null,
    );
  }
}

// ─── Şifre İşlemleri Sheet ────────────────────────────────────────────────────

class _PasswordSheet extends StatefulWidget {
  final User user;
  const _PasswordSheet({required this.user});

  @override
  State<_PasswordSheet> createState() => _PasswordSheetState();
}

class _PasswordSheetState extends State<_PasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _oldPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  
  bool _isLoading = false;
  late bool _hasPassword;

  @override
  void initState() {
    super.initState();
    _hasPassword = widget.user.providerData.any((p) => p.providerId == 'password');
  }

  @override
  void dispose() {
    _oldPassCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      if (_hasPassword) {
        // Eski şifre ile doğrula ve güncelle
        final cred = EmailAuthProvider.credential(
          email: widget.user.email!,
          password: _oldPassCtrl.text.trim(),
        );
        await widget.user.reauthenticateWithCredential(cred);
        await widget.user.updatePassword(_newPassCtrl.text.trim());
      } else {
        // Şifre yoksa (örn: sadece google) doğrudan ekle (link) veya update
        await widget.user.updatePassword(_newPassCtrl.text.trim());
      }
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Şifre başarıyla güncellendi')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.borderGrey,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              _hasPassword ? 'Şifre Değiştir' : 'Şifre Belirle',
              style: GoogleFonts.nunito(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
            if (!_hasPassword)
              Text(
                'Google ile giriş yaptığınız için henüz bir şifreniz yok. Şifre belirleyerek e-posta ve şifre ile de giriş yapabilirsiniz.',
                style: GoogleFonts.nunito(fontSize: 13, color: AppColors.textMid),
              ),
            const SizedBox(height: 16),
            if (_hasPassword) ...[
              _buildField(_oldPassCtrl, 'Mevcut Şifre'),
              const SizedBox(height: 12),
            ],
            _buildField(_newPassCtrl, 'Yeni Şifre'),
            const SizedBox(height: 12),
            _buildField(_confirmPassCtrl, 'Yeni Şifreyi Onayla', isConfirm: true),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: DuolingoButton(
                color: AppColors.teal,
                bottomColor: AppColors.tealDark,
                disabledColor: AppColors.borderGrey,
                isLoading: _isLoading,
                onPressed: _isLoading ? null : _submit,
                child: Text(
                  _hasPassword ? 'ŞİFREYİ DEĞİŞTİR' : 'ŞİFRE BELİRLE',
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(TextEditingController controller, String label, {bool isConfirm = false}) {
    return TextFormField(
      controller: controller,
      obscureText: true,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.nunito(color: AppColors.textMid),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.teal, width: 2),
        ),
      ),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return 'Bu alan zorunludur';
        if (v.trim().length < 6) return 'En az 6 karakter olmalıdır';
        if (isConfirm && v.trim() != _newPassCtrl.text.trim()) {
          return 'Şifreler eşleşmiyor';
        }
        return null;
      },
    );
  }
}
