import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import '../app_colors.dart';
import '../providers/auth_provider.dart';
import '../data/quran_cuz.dart';

enum HeatFilter { month, year, all, meal }

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
  HeatFilter _filter = HeatFilter.all;
  int? _selectedPage;
  // MVP: boş — Firestore log modülünde doldurulacak
  final Map<int, int> _readings = {};

  void _showSettings(BuildContext context) {
    final auth = context.read<AuthProvider>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _SettingsSheet(
        onSignOut: () {
          Navigator.of(context).pop();
          auth.signOut();
        },
      ),
    );
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
        final streak = (data?['streak'] as int?) ?? 0;
        final hasanat = (data?['hasanat'] as int?) ?? 0;
        final hatimCount = (data?['hatimCount'] as int?) ?? 0;
        final totalPages = (data?['totalPages'] as int?) ?? 0;

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
                onSettingsTap: () => _showSettings(context),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    _StatGrid(
                      streak: streak,
                      hasanat: hasanat,
                      hatimCount: hatimCount,
                      totalPages: totalPages,
                    ),
                    const SizedBox(height: 12),
                    _KuranHaritasiCard(
                      filter: _filter,
                      readings: _readings,
                      selectedPage: _selectedPage,
                      onFilterChanged: (f) => setState(() {
                        _filter = f;
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
  final int streak;
  final int hasanat;
  final int hatimCount;
  final int totalPages;

  const _StatGrid({
    required this.streak,
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
          Expanded(child: _StatCard(icon: '🔥', value: _fmt(streak), label: 'STREAK', color: AppColors.orange)),
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
  final HeatFilter filter;
  final Map<int, int> readings;
  final int? selectedPage;
  final ValueChanged<HeatFilter> onFilterChanged;
  final ValueChanged<int> onPageTap;

  const _KuranHaritasiCard({
    required this.filter,
    required this.readings,
    required this.selectedPage,
    required this.onFilterChanged,
    required this.onPageTap,
  });

  @override
  Widget build(BuildContext context) {
    final isMeal = filter == HeatFilter.meal;
    final readPages = readings.values.where((v) => v > 0).length;
    final totalReadings = readings.values.fold(0, (a, b) => a + b);
    final coveragePct = readPages == 0 ? 0 : ((readPages / 604.0) * 100).round();

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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.tealLight,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  isMeal ? 'MEAL' : 'ARAPÇA',
                  style: GoogleFonts.nunito(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.teal,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Filtre chip'leri
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(label: 'Son 1 ay', value: HeatFilter.month, selected: filter, onTap: onFilterChanged),
                const SizedBox(width: 6),
                _FilterChip(label: 'Son 1 yıl', value: HeatFilter.year, selected: filter, onTap: onFilterChanged),
                const SizedBox(width: 6),
                _FilterChip(label: 'Tüm zamanlar', value: HeatFilter.all, selected: filter, onTap: onFilterChanged),
                const SizedBox(width: 6),
                _FilterChip(label: 'Meal', value: HeatFilter.meal, selected: filter, onTap: onFilterChanged),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // İstatistik şeridi
          IntrinsicHeight(
            child: Row(
              children: [
                _StatStrip(value: _fmt(totalReadings), label: 'OKUMA'),
                const VerticalDivider(color: AppColors.borderGrey, thickness: 1, width: 32),
                _StatStrip(value: '%$coveragePct', label: 'KAPSAM'),
                const VerticalDivider(color: AppColors.borderGrey, thickness: 1, width: 32),
                _StatStrip(value: _fmt(readPages), label: 'SAYFA'),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Isı haritası
          _HeatGrid(readings: readings, selectedPage: selectedPage, onPageTap: onPageTap),
          // Lejant
          _Legend(),
          // Detay paneli
          _DetailPanel(page: selectedPage, readings: readings),
        ],
      ),
    );
  }
}

// ─── Filtre Chip ──────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final HeatFilter value;
  final HeatFilter selected;
  final ValueChanged<HeatFilter> onTap;

  const _FilterChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = value == selected;
    return GestureDetector(
      onTap: () => onTap(value),
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

// ─── İstatistik Şeridi ────────────────────────────────────────────────────────

class _StatStrip extends StatelessWidget {
  final String value;
  final String label;

  const _StatStrip({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          children: [
            Text(
              value,
              style: GoogleFonts.nunito(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.teal,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.nunito(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textLight,
                letterSpacing: 0.4,
              ),
            ),
          ],
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

  Widget _buildSquare(int page, double sq, double radius) {
    final count = readings[page] ?? 0;
    final isSelected = selectedPage == page;
    return GestureDetector(
      onTap: () => onPageTap(page),
      child: Container(
        width: sq,
        height: sq,
        margin: const EdgeInsets.only(right: _squareGap),
        decoration: BoxDecoration(
          color: QuranData.heatColor(count),
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
        final fatihaCount = readings[0] ?? 0;
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
                    color: QuranData.heatColor(fatihaCount),
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
                  ...List.generate(cuz.pageCount, (i) => _buildSquare(cuz.startPage + i, sq, radius)),
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
                  ...List.generate(20, (i) => _buildSquare(581 + i, sq, radius)),
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
                  ...List.generate(4, (i) => _buildSquare(601 + i, sq, radius)),
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

  const _DetailPanel({required this.page, required this.readings});

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
          : _PageDetail(page: page!, count: readings[page] ?? 0),
    );
  }
}

class _PageDetail extends StatelessWidget {
  final int page;
  final int count;

  const _PageDetail({required this.page, required this.count});

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
              color: count == 0 ? AppColors.textLight : QuranData.heatColor(count),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Ayarlar Bottom Sheet ─────────────────────────────────────────────────────

class _SettingsSheet extends StatelessWidget {
  final VoidCallback onSignOut;

  const _SettingsSheet({required this.onSignOut});

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
