import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:dropdown_search/dropdown_search.dart';
import '../app_colors.dart';
import '../app_theme.dart';
import '../constants/app_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../data/quran_cuz.dart';
import '../utils/name_utils.dart';
import '../widgets/duolingo_button.dart';
import '../widgets/log_history_sheet.dart';
import '../widgets/seri_calendar_sheet.dart';
import '../widgets/seri_fire_effect.dart';
import '../widgets/hasanat_star_effect.dart';
import 'vird_screen.dart';
import 'dev_panel_screen.dart';
import '../utils/seri_calculator.dart';
import '../utils/text_utils.dart';
import '../providers/user_provider.dart';

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

  void _showHafizSheetDirectly(BuildContext context, Map<String, dynamic> userData, User user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _HafizSheet(
        uid: user.uid,
        isHafiz: (userData['isHafiz'] as bool?) ?? false,
        name: (userData['name'] as String?) ?? '',
        username: (userData['username'] as String?) ?? '',
        avatarSeed: userData['avatarSeed'] as String?,
      ),
    );
  }

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
        final isDeveloper = (data?['isDeveloper'] as bool?) ?? false;
        final seriRaw = (data?['seri'] as int?) ?? 0;
        final lastLogTs = data?['lastLogDate'] as Timestamp?;
        final seriState = seriDisplayState(seriRaw, lastLogTs);
        final seri = seriState.value;
        final seriAtRisk = seriState.atRisk;
        final streakFreezes = (data?['streakFreezes'] as int?) ?? 0;
        final hasanat = (data?['hasanat'] as int?) ?? 0;
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
                    isDeveloper: isDeveloper,
                    onSettingsTap: () => _showSettings(context, data ?? {}, user),
                    onHafizTap: isHafiz ? () => _showHafizSheetDirectly(context, data ?? {}, user) : null,
                    onDevTap: isDeveloper ? () => DevPanelScreen.show(context) : null,
                    onVirdTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const VirdScreen()),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 12),
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('users')
                              .doc(user.uid)
                              .collection('hatims')
                              .where('isCompleted', isEqualTo: true)
                              .snapshots(),
                          builder: (context, hatimSnap) {
                            final completedCount = hatimSnap.data?.size ?? 0;
                            return _StatGrid(
                              seri: seri,
                              seriAtRisk: seriAtRisk,
                              streakFreezes: streakFreezes,
                              hasanat: hasanat,
                              hatimCount: completedCount,
                              totalPages: totalPages,
                              onSeriTap: () => SeriCalendarSheet.show(
                                context,
                                uid: user.uid,
                                seri: seri,
                              ),
                            );
                          },
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
  final bool isDeveloper;
  final VoidCallback onSettingsTap;
  final VoidCallback onVirdTap;
  final VoidCallback? onHafizTap;
  final VoidCallback? onDevTap;

  const _ProfileHeader({
    required this.name,
    required this.username,
    required this.city,
    required this.university,
    required this.avatarSeed,
    required this.isPro,
    required this.isHafiz,
    required this.isDeveloper,
    required this.onSettingsTap,
    required this.onVirdTap,
    this.onHafizTap,
    this.onDevTap,
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
              bottom: 8,
              right: 12,
              child: Row(
                children: [
                  GestureDetector(
                    onTap: onVirdTap,
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                      ),
                      child: Image.asset(
                        'assets/images/v_logo.png',
                        height: 19,
                        width: 19,
                        color: Colors.white,
                        colorBlendMode: BlendMode.srcIn,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
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
                ],
              ),
            ),
            Positioned(
              bottom: -avatarR,
              left: 16,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isHafiz ? AppColors.emeraldGreen : context.colors.surface,
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
                  backgroundColor: context.colors.tealSurface,
                  backgroundImage: avatarSeed != null
                      ? NetworkImage(
                          'https://api.dicebear.com/7.x/micah/png?seed=$avatarSeed&backgroundColor=transparent',
                        )
                      : null,
                  child: avatarSeed == null
                      ? Text(
                          nameInitials(name),
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
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: context.colors.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isPro) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.gold.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: AppColors.gold.withValues(alpha: 0.35),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.star_rounded, size: 9, color: AppColors.gold),
                                const SizedBox(width: 2),
                                Text(
                                  'PRO',
                                  style: GoogleFonts.nunito(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.gold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (isHafiz) ...[
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: onHafizTap,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.emeraldGreen.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: AppColors.emeraldGreen.withValues(alpha: 0.35),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.menu_book_rounded, size: 9, color: AppColors.emeraldGreen),
                                  const SizedBox(width: 2),
                                  Text(
                                    'HAFIZ',
                                    style: GoogleFonts.nunito(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.emeraldGreen,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        if (isDeveloper) ...[
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: onDevTap,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E293B),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                'DEV',
                                style: GoogleFonts.nunito(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
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
                          color: context.colors.textSecondary,
                        ),
                      ),
                    ],
                    if (locationParts.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        locationParts.join(' · '),
                        style: GoogleFonts.nunito(
                          fontSize: 11,
                          color: context.colors.textTertiary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
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
  final bool seriAtRisk;
  final int streakFreezes;
  final int hasanat;
  final int hatimCount;
  final int totalPages;
  final VoidCallback? onSeriTap;

  const _StatGrid({
    required this.seri,
    this.seriAtRisk = false,
    this.streakFreezes = 0,
    required this.hasanat,
    required this.hatimCount,
    required this.totalPages,
    this.onSeriTap,
  });

  @override
  Widget build(BuildContext context) {
    final seriColor = seriAtRisk ? AppColors.errorRed : AppColors.orange;
    final seriLabel = seriAtRisk ? 'TEHLİKEDE' : 'SERİ';
    final freezeBadge = streakFreezes > 0 ? '🛡️ $streakFreezes' : null;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: SeriFireEffect(
            seriValue: seri,
            borderRadius: BorderRadius.circular(12),
            child: GestureDetector(
              onTap: onSeriTap,
              child: _StatCard(icon: '🔥', value: _fmt(seri), label: seriLabel, color: seriColor, badge: freezeBadge),
            ),
          )),
          const SizedBox(width: 8),
          Expanded(child: HasanatStarEffect(
            hasanatValue: hasanat,
            borderRadius: BorderRadius.circular(12),
            child: _StatCard(icon: '✨', value: _fmt(hasanat), label: 'HASANAT', color: AppColors.gold),
          )),
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
  final String? badge;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border.all(color: context.colors.border),
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
              color: context.colors.textTertiary,
              letterSpacing: 0.4,
            ),
          ),
          if (badge != null) ...[
            const SizedBox(height: 2),
            Text(
              badge!,
              style: GoogleFonts.nunito(
                fontSize: 7.5,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF3A9AC4),
              ),
            ),
          ],
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
        color: context.colors.surface,
        border: Border.all(color: context.colors.border),
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
                        color: context.colors.textPrimary,
                      ),
                    ),
                    Text(
                      'Her kare bir sayfa — 604 sayfa, 30 cüz',
                      style: GoogleFonts.nunito(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: context.colors.textSecondary,
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
                        color: !isMeal ? AppColors.teal : context.colors.surfaceVariant,
                        borderRadius: const BorderRadius.horizontal(left: Radius.circular(999)),
                      ),
                      child: Text('ARAPÇA', style: GoogleFonts.nunito(
                        fontSize: 10, fontWeight: FontWeight.w700,
                        color: !isMeal ? Colors.white : context.colors.textSecondary,
                      )),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => onTypeFilterChanged(HeatTypeFilter.meal),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: isMeal ? AppColors.teal : context.colors.surfaceVariant,
                        borderRadius: const BorderRadius.horizontal(right: Radius.circular(999)),
                      ),
                      child: Text('MEAL', style: GoogleFonts.nunito(
                        fontSize: 10, fontWeight: FontWeight.w700,
                        color: isMeal ? Colors.white : context.colors.textSecondary,
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
          color: isSelected ? context.colors.tealSurface : context.colors.surface,
          border: Border.all(
            color: isSelected ? AppColors.teal : context.colors.border,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: GoogleFonts.nunito(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: isSelected ? AppColors.teal : context.colors.textSecondary,
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

  Widget _buildSquare(BuildContext context, int page, double sq, double radius, int maxCount) {
    final count = readings[page] ?? 0;
    final isSelected = selectedPage == page;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () => onPageTap(page),
      child: Container(
        width: sq,
        height: sq,
        margin: const EdgeInsets.only(right: _squareGap),
        decoration: BoxDecoration(
          color: QuranData.heatColorRelative(count, maxCount, isDark: isDark),
          borderRadius: BorderRadius.circular(radius),
          border: isSelected ? Border.all(color: context.colors.textPrimary, width: 1) : null,
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
        final isDark = Theme.of(context).brightness == Brightness.dark;

        final labelStyle = GoogleFonts.nunito(
          fontSize: 8,
          fontWeight: FontWeight.w700,
          color: context.colors.textTertiary,
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
                    color: QuranData.heatColorRelative(fatihaCount, maxCount, isDark: isDark),
                    borderRadius: BorderRadius.circular(radius),
                    border: fatihaSelected
                        ? Border.all(color: context.colors.textPrimary, width: 1)
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
                  ...List.generate(cuz.pageCount, (i) => _buildSquare(context, cuz.startPage + i, sq, radius, maxCount)),
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
                  ...List.generate(20, (i) => _buildSquare(context, 581 + i, sq, radius, maxCount)),
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
                  ...List.generate(4, (i) => _buildSquare(context, 601 + i, sq, radius, maxCount)),
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
              Text('Az', style: GoogleFonts.nunito(fontSize: 10, color: context.colors.textSecondary)),
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
              Text('Çok', style: GoogleFonts.nunito(fontSize: 10, color: context.colors.textSecondary)),
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
        color: context.colors.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: page == null
          ? Text(
              'Detay için bir sayfaya dokun',
              style: GoogleFonts.nunito(fontSize: 11, color: context.colors.textTertiary),
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
                  color: context.colors.textPrimary,
                ),
              ),
              if (surahText.isNotEmpty)
                Text(
                  surahText,
                  style: GoogleFonts.nunito(fontSize: 10, color: context.colors.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
          decoration: BoxDecoration(
            color: context.colors.surface,
            border: Border.all(color: context.colors.border),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '$count okuma',
            style: GoogleFonts.nunito(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: count == 0 ? context.colors.textTertiary : QuranData.heatColorRelative(count, maxCount, isDark: Theme.of(context).brightness == Brightness.dark),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Ayarlar Bottom Sheet ─────────────────────────────────────────────────────

class _SettingsSheet extends StatefulWidget {
  final Map<String, dynamic> userData;
  final User user;
  final VoidCallback onSignOut;

  const _SettingsSheet({
    required this.userData,
    required this.user,
    required this.onSignOut,
  });

  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  void _showProfileAccountSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _ProfileAccountSheet(
        userData: widget.userData,
        user: widget.user,
        onBack: () => Navigator.pop(context),
      ),
    );
  }

  void _showHafizSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _HafizSheet(
        uid: widget.user.uid,
        isHafiz: (widget.userData['isHafiz'] as bool?) ?? false,
        name: (widget.userData['name'] as String?) ?? '',
        username: (widget.userData['username'] as String?) ?? '',
        avatarSeed: widget.userData['avatarSeed'] as String?,
        onBack: () => Navigator.pop(context),
      ),
    );
  }

  void _showKaynakcaSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _KaynakcaSheet(),
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
                color: context.colors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            'Ayarlar',
            style: GoogleFonts.nunito(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: context.colors.textPrimary,
            ),
          ),
          const SizedBox(height: 20),
          _SettingsItem(
            icon: Icons.manage_accounts_outlined,
            title: 'Profil & Hesap İşlemleri',
            onTap: () => _showProfileAccountSheet(context),
          ),
          const SizedBox(height: 20),
          Text(
            'Uygulama',
            style: GoogleFonts.nunito(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: context.colors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          _SettingsItem(
            icon: Icons.history,
            title: 'Okuma Geçmişi',
            onTap: () {
              LogHistorySheet.show(context);
            },
          ),
          const SizedBox(height: 12),
          _SettingsItem(
            icon: Icons.menu_book_outlined,
            title: 'Hafız Doğrulaması',
            onTap: () => _showHafizSheet(context),
          ),
          const SizedBox(height: 12),
          _SettingsItem(
            icon: Icons.bookmark_border_rounded,
            title: 'Kaynakça',
            onTap: () {
              final navContext = context;
              Navigator.pop(context);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _showKaynakcaSheet(navContext);
              });
            },
          ),
          const SizedBox(height: 12),
          // Dark mode toggle
          Consumer<ThemeProvider>(
            builder: (context, theme, _) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: context.colors.border),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      theme.isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                      color: context.colors.textPrimary,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Karanlık Mod',
                        style: GoogleFonts.nunito(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: context.colors.textPrimary,
                        ),
                      ),
                    ),
                    Switch(
                      value: theme.isDark,
                      onChanged: (_) => theme.toggle(),
                      activeColor: AppColors.teal,
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          Text(
            'Gizlilik',
            style: GoogleFonts.nunito(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: context.colors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.colors.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Harita ve istatistiklerin kimler tarafından görülebileceğini belirle.\nYakında eklenecek.',
              style: GoogleFonts.nunito(
                fontSize: 13,
                color: context.colors.textTertiary,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: widget.onSignOut,
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
          border: Border.all(color: context.colors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: context.colors.textPrimary, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.nunito(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: context.colors.textPrimary,
                ),
              ),
            ),
            Icon(Icons.chevron_right, color: context.colors.textSecondary),
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
  String? _selectedCity;
  String? _selectedUniversity;
  bool _isLoading = false;

  late final List<String> _sortedCities;
  late final List<String> _sortedUniversities;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.userData['name'] ?? widget.user.displayName ?? '');
    _usernameCtrl = TextEditingController(text: widget.userData['username'] ?? '');

    final cityRaw = widget.userData['city'] as String?;
    _selectedCity = (cityRaw == null || cityRaw.isEmpty || cityRaw == 'Şehir belirtilmedi') ? null : cityRaw;

    final uniRaw = widget.userData['university'] as String?;
    _selectedUniversity = (uniRaw == null || uniRaw.isEmpty || uniRaw == 'Üniversite belirtilmedi') ? null : uniRaw;

    _sortedCities = List.from(AppConstants.cities)..sort(_turkishCompare);
    _sortedUniversities = List.from(AppConstants.universities)..sort(_turkishCompare);
  }

  int _turkishCompare(String a, String b) {
    String norm(String t) => t.toLowerCase()
        .replaceAll('ç', 'cz').replaceAll('ğ', 'gz').replaceAll('ı', 'hz')
        .replaceAll('ö', 'oz').replaceAll('ş', 'sz').replaceAll('ü', 'uz');
    return norm(a).compareTo(norm(b));
  }

  bool _turkishFilter(String item, String filter) => turkishContains(item, filter);

  @override
  void dispose() {
    _nameCtrl.dispose();
    _usernameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance.collection('users').doc(widget.user.uid).update({
        'name': _nameCtrl.text.trim(),
        'username': _usernameCtrl.text.trim(),
        'city': _selectedCity ?? '',
        'university': _selectedUniversity ?? '',
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
        child: SingleChildScrollView(
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
                    color: context.colors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'Profili Düzenle',
                style: GoogleFonts.nunito(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: context.colors.textPrimary,
                ),
              ),
              const SizedBox(height: 20),
              _buildTextField(_nameCtrl, 'Ad Soyad', isRequired: true, textInputAction: TextInputAction.next),
              const SizedBox(height: 12),
              _buildTextField(_usernameCtrl, 'Kullanıcı Adı (Opsiyonel)', textInputAction: TextInputAction.done, onSubmitted: _save),
              const SizedBox(height: 12),
              DropdownSearch<String>(
                items: (filter, _) => _sortedCities,
                filterFn: _turkishFilter,
                selectedItem: _selectedCity,
                onSelected: (v) => setState(() => _selectedCity = v),
                popupProps: const PopupProps.menu(
                  showSearchBox: true,
                  searchFieldProps: TextFieldProps(
                    decoration: InputDecoration(
                      hintText: 'Şehir ara...',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
                decoratorProps: DropDownDecoratorProps(
                  decoration: InputDecoration(
                    labelText: 'Şehir (Opsiyonel)',
                    labelStyle: GoogleFonts.nunito(color: context.colors.textSecondary),
                    prefixIcon: const Icon(Icons.location_city, color: AppColors.teal),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.teal, width: 2),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              DropdownSearch<String>(
                items: (filter, _) => _sortedUniversities,
                filterFn: _turkishFilter,
                selectedItem: _selectedUniversity,
                onSelected: (v) => setState(() => _selectedUniversity = v),
                popupProps: const PopupProps.menu(
                  showSearchBox: true,
                  searchFieldProps: TextFieldProps(
                    decoration: InputDecoration(
                      hintText: 'Üniversite ara...',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
                decoratorProps: DropDownDecoratorProps(
                  decoration: InputDecoration(
                    labelText: 'Üniversite (Opsiyonel)',
                    labelStyle: GoogleFonts.nunito(color: context.colors.textSecondary),
                    prefixIcon: const Icon(Icons.school, color: AppColors.teal),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.teal, width: 2),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: DuolingoButton(
                  color: AppColors.teal,
                  bottomColor: AppColors.tealDark,
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
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, {bool isRequired = false, TextInputAction? textInputAction, VoidCallback? onSubmitted, int maxLength = 80}) {
    return TextFormField(
      controller: controller,
      textInputAction: textInputAction,
      onFieldSubmitted: onSubmitted != null ? (_) => onSubmitted() : null,
      maxLength: maxLength,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.nunito(color: context.colors.textSecondary),
        counterText: '',
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

// ─── Profil & Hesap Sheet ─────────────────────────────────────────────────────

class _ProfileAccountSheet extends StatefulWidget {
  final Map<String, dynamic> userData;
  final User user;
  final VoidCallback? onBack;
  const _ProfileAccountSheet({required this.userData, required this.user, this.onBack});

  @override
  State<_ProfileAccountSheet> createState() => _ProfileAccountSheetState();
}

class _ProfileAccountSheetState extends State<_ProfileAccountSheet> {
  final _profileFormKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _usernameCtrl;
  String? _selectedCity;
  String? _selectedUniversity;
  bool _profileLoading = false;

  final _passwordFormKey = GlobalKey<FormState>();
  final _oldPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  bool _passwordLoading = false;
  bool _deleteLoading = false;
  late bool _hasPassword;

  late final List<String> _sortedCities;
  late final List<String> _sortedUniversities;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(
      text: widget.userData['name'] ?? widget.user.displayName ?? '',
    );
    _usernameCtrl = TextEditingController(
      text: widget.userData['username'] ?? '',
    );
    final cityRaw = widget.userData['city'] as String?;
    _selectedCity = (cityRaw == null || cityRaw.isEmpty || cityRaw == 'Şehir belirtilmedi')
        ? null : cityRaw;
    final uniRaw = widget.userData['university'] as String?;
    _selectedUniversity = (uniRaw == null || uniRaw.isEmpty || uniRaw == 'Üniversite belirtilmedi')
        ? null : uniRaw;
    _sortedCities = List.from(AppConstants.cities)..sort(_turkishCompare);
    _sortedUniversities = List.from(AppConstants.universities)..sort(_turkishCompare);
    _hasPassword = widget.user.providerData.any((p) => p.providerId == 'password');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _usernameCtrl.dispose();
    _oldPassCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  int _turkishCompare(String a, String b) {
    String norm(String t) => t.toLowerCase()
        .replaceAll('ç', 'cz').replaceAll('ğ', 'gz').replaceAll('ı', 'hz')
        .replaceAll('ö', 'oz').replaceAll('ş', 'sz').replaceAll('ü', 'uz');
    return norm(a).compareTo(norm(b));
  }

  Future<void> _saveProfile() async {
    if (!_profileFormKey.currentState!.validate()) return;
    setState(() => _profileLoading = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(widget.user.uid).update({
        'name': _nameCtrl.text.trim(),
        'username': _usernameCtrl.text.trim(),
        'city': _selectedCity ?? '',
        'university': _selectedUniversity ?? '',
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil güncellendi')),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    } finally {
      if (mounted) setState(() => _profileLoading = false);
    }
  }

  Future<void> _savePassword() async {
    if (!_passwordFormKey.currentState!.validate()) return;
    setState(() => _passwordLoading = true);
    try {
      if (_hasPassword) {
        final cred = EmailAuthProvider.credential(
          email: widget.user.email!,
          password: _oldPassCtrl.text.trim(),
        );
        await widget.user.reauthenticateWithCredential(cred);
        await widget.user.updatePassword(_newPassCtrl.text.trim());
      } else {
        await widget.user.updatePassword(_newPassCtrl.text.trim());
      }
      if (mounted) {
        _oldPassCtrl.clear();
        _newPassCtrl.clear();
        _confirmPassCtrl.clear();
        setState(() => _hasPassword = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Şifre güncellendi')),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    } finally {
      if (mounted) setState(() => _passwordLoading = false);
    }
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Hesabı Sil',
            style: GoogleFonts.nunito(fontWeight: FontWeight.w800, color: context.colors.textPrimary)),
        content: Text(
          'Hesabının tüm bilgileri ve ilerlemelerin kalıcı olarak silinecektir. Bu işlem geri alınamaz.\n\nOnaylıyor musun?',
          style: GoogleFonts.nunito(fontSize: 14, color: context.colors.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Vazgeç',
                style: GoogleFonts.nunito(color: context.colors.textSecondary, fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Evet, Sil',
                style: GoogleFonts.nunito(color: AppColors.errorRed, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deleteLoading = true);

    // Firestore silme sırasında MandatorySetup tetiklenmesin
    try { context.read<UserProvider>().suppressSetup(); } catch (_) {}

    final uid = widget.user.uid;
    final authProvider = context.read<AuthProvider>();
    // Navigator ve ScaffoldMessenger'ı async öncesinde yakala:
    // user.delete() auth state'i değiştirince context stale olabilir,
    // NavigatorState referansı ise her zaman geçerli kalır.
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      // 1. Token'ı tazele — hesap dışarıdan silinmişse veya oturum tamamen geçersizse
      //    burada hata fırlatır. requires-recent-login yalnızca user.delete()'te yakalanır.
      await widget.user.reload();

      // 2. Firestore verisini sil — hâlâ authenticated olduğumuz için kurallar geçerli.
      final logsSnap = await FirebaseFirestore.instance
          .collection('users').doc(uid).collection('logs').get();
      for (final doc in logsSnap.docs) await doc.reference.delete();

      final hatimsSnap = await FirebaseFirestore.instance
          .collection('users').doc(uid).collection('hatims').get();
      for (final doc in hatimsSnap.docs) await doc.reference.delete();

      await FirebaseFirestore.instance.collection('users').doc(uid).delete();

      // 3. Auth hesabını sil — Firestore temizlendi, artık güvenli.
      await widget.user.delete();

      // 4. Sheet'leri kapat — navigator önceden alındığı için context stale olsa da güvenli.
      // signOut() çağrılmıyor: user.delete() zaten auth state'i null yapıyor,
      // AuthWrapper LoginScreen'e otomatik geçer ve çift auth event oluşmaz.
      navigator.popUntil((route) => route.isFirst);

    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _deleteLoading = false);
      if (e.code == 'requires-recent-login') {
        navigator.popUntil((route) => route.isFirst);
        authProvider.signOut(); // fire-and-forget — AuthWrapper geçişini tetikler
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Güvenlik nedeniyle hesabınızı silmeden önce tekrar giriş yapmalısınız.'),
            backgroundColor: AppColors.errorRed,
            duration: Duration(seconds: 5),
          ),
        );
      } else {
        messenger.showSnackBar(
          SnackBar(content: Text('Hata: ${e.message}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _deleteLoading = false);
      messenger.showSnackBar(
        SnackBar(content: Text('Hata: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: context.colors.border, borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                if (widget.onBack != null)
                  GestureDetector(
                    onTap: widget.onBack,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        color: context.colors.surfaceVariant,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: context.colors.textSecondary),
                    ),
                  ),
                Text('Profil & Hesap',
                  style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w800, color: context.colors.textPrimary)),
              ],
            ),

            const SizedBox(height: 24),
            // ── Profil ──────────────────────────────────────────────
            Text('Profil Bilgileri',
              style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w700, color: context.colors.textSecondary)),
            const SizedBox(height: 12),
            Form(
              key: _profileFormKey,
              child: Column(
                children: [
                  _buildTextField(_nameCtrl, 'Ad Soyad', isRequired: true, textInputAction: TextInputAction.next),
                  const SizedBox(height: 12),
                  _buildTextField(_usernameCtrl, 'Kullanıcı Adı (Opsiyonel)', textInputAction: TextInputAction.done, onSubmitted: _saveProfile),
                  const SizedBox(height: 12),
                  DropdownSearch<String>(
                    items: (filter, _) => _sortedCities,
                    filterFn: (item, filter) => turkishContains(item, filter),
                    selectedItem: _selectedCity,
                    onSelected: (v) => setState(() => _selectedCity = v),
                    popupProps: const PopupProps.menu(
                      showSearchBox: true,
                      searchFieldProps: TextFieldProps(
                        decoration: InputDecoration(hintText: 'Şehir ara...', prefixIcon: Icon(Icons.search)),
                      ),
                    ),
                    decoratorProps: DropDownDecoratorProps(
                      decoration: InputDecoration(
                        labelText: 'Şehir (Opsiyonel)',
                        labelStyle: GoogleFonts.nunito(color: context.colors.textSecondary),
                        prefixIcon: const Icon(Icons.location_city, color: AppColors.teal),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.teal, width: 2),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownSearch<String>(
                    items: (filter, _) => _sortedUniversities,
                    filterFn: (item, filter) => turkishContains(item, filter),
                    selectedItem: _selectedUniversity,
                    onSelected: (v) => setState(() => _selectedUniversity = v),
                    popupProps: const PopupProps.menu(
                      showSearchBox: true,
                      searchFieldProps: TextFieldProps(
                        decoration: InputDecoration(hintText: 'Üniversite ara...', prefixIcon: Icon(Icons.search)),
                      ),
                    ),
                    decoratorProps: DropDownDecoratorProps(
                      decoration: InputDecoration(
                        labelText: 'Üniversite (Opsiyonel)',
                        labelStyle: GoogleFonts.nunito(color: context.colors.textSecondary),
                        prefixIcon: const Icon(Icons.school, color: AppColors.teal),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.teal, width: 2),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // ── Cinsiyet — sadece görüntüleme, düzenlenemez ──────────
                  Builder(
                    builder: (_) {
                      final cinsiyet = widget.userData['cinsiyet'] as String?;
                      final label = cinsiyet == 'hanim'
                          ? 'Hanımefendi'
                          : cinsiyet == 'bey'
                              ? 'Beyefendi'
                              : 'Belirtilmemiş';
                      return InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Cinsiyet (Değiştirilemez)',
                          labelStyle: GoogleFonts.nunito(color: context.colors.textSecondary),
                          prefixIcon: const Icon(Icons.wc, color: AppColors.teal),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          enabled: false,
                        ),
                        child: Text(
                          label,
                          style: GoogleFonts.nunito(fontSize: 15, color: context.colors.textPrimary, fontWeight: FontWeight.w600),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity, height: 50,
              child: DuolingoButton(
                color: AppColors.teal, bottomColor: AppColors.tealDark,
                isLoading: _profileLoading,
                onPressed: _profileLoading ? null : _saveProfile,
                child: Text('PROFİLİ KAYDET',
                  style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
              ),
            ),

            const SizedBox(height: 28),
            const Divider(),
            const SizedBox(height: 20),

            // ── Hesap ────────────────────────────────────────────────
            Text('Hesap Ayarları',
              style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w700, color: context.colors.textSecondary)),
            const SizedBox(height: 12),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: context.colors.surfaceVariant, borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.email_outlined, color: context.colors.textTertiary, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(widget.user.email ?? '—',
                      style: GoogleFonts.nunito(fontSize: 14, color: context.colors.textSecondary)),
                  ),
                  Text('e-posta',
                    style: GoogleFonts.nunito(fontSize: 12, color: context.colors.textTertiary)),
                ],
              ),
            ),

            const SizedBox(height: 20),
            Text(
              _hasPassword ? 'Şifre Değiştir' : 'Şifre Belirle',
              style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w700, color: context.colors.textSecondary),
            ),
            if (!_hasPassword) ...[
              const SizedBox(height: 6),
              Text(
                'Google ile giriş yaptığın için henüz bir şifren yok. Belirleyerek e-posta & şifreyle de giriş yapabilirsin.',
                style: GoogleFonts.nunito(fontSize: 12, color: context.colors.textTertiary, height: 1.4),
              ),
            ],
            const SizedBox(height: 12),
            Form(
              key: _passwordFormKey,
              child: Column(
                children: [
                  if (_hasPassword) ...[
                    _buildPassField(_oldPassCtrl, 'Mevcut Şifre'),
                    const SizedBox(height: 12),
                  ],
                  _buildPassField(_newPassCtrl, 'Yeni Şifre'),
                  const SizedBox(height: 12),
                  _buildPassField(_confirmPassCtrl, 'Yeni Şifreyi Onayla', isConfirm: true),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity, height: 50,
              child: DuolingoButton(
                color: AppColors.teal, bottomColor: AppColors.tealDark,
                isLoading: _passwordLoading,
                onPressed: _passwordLoading ? null : _savePassword,
                child: Text(
                  _hasPassword ? 'ŞİFREYİ DEĞİŞTİR' : 'ŞİFRE BELİRLE',
                  style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
              ),
            ),

            const SizedBox(height: 16),
            Row(children: [
              const Expanded(child: Divider()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('veya', style: GoogleFonts.nunito(fontSize: 12, color: context.colors.textTertiary)),
              ),
              const Expanded(child: Divider()),
            ]),
            const SizedBox(height: 4),
            TextButton.icon(
              onPressed: () async {
                await showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  builder: (_) => _MagicLinkSheet(email: widget.user.email ?? ''),
                );
              },
              icon: const Icon(Icons.link_rounded, size: 18, color: AppColors.teal),
              label: Text('Başka cihazdan giriş linki gönder',
                style: GoogleFonts.nunito(fontSize: 14, color: AppColors.teal, fontWeight: FontWeight.w600)),
            ),

            // ── Hesabı Sil ─────────────────────────────────────────
            const SizedBox(height: 8),
            Center(
              child: _deleteLoading
                  ? const SizedBox(
                      height: 20, width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : TextButton(
                      onPressed: _deleteAccount,
                      style: TextButton.styleFrom(padding: EdgeInsets.zero),
                      child: Text(
                        'Hesabımı Kalıcı Olarak Sil',
                        style: GoogleFonts.nunito(
                          fontSize: 12,
                          color: context.colors.textTertiary,
                          decoration: TextDecoration.underline,
                          decorationColor: context.colors.textTertiary,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String label, {bool isRequired = false, TextInputAction? textInputAction, VoidCallback? onSubmitted, int maxLength = 80}) {
    return TextFormField(
      controller: ctrl,
      textInputAction: textInputAction,
      onFieldSubmitted: onSubmitted != null ? (_) => onSubmitted() : null,
      maxLength: maxLength,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.nunito(color: context.colors.textSecondary),
        counterText: '',
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

  Widget _buildPassField(TextEditingController ctrl, String label, {bool isConfirm = false}) {
    return TextFormField(
      controller: ctrl,
      obscureText: true,
      maxLength: 64,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.nunito(color: context.colors.textSecondary),
        counterText: '',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.teal, width: 2),
        ),
      ),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return 'Bu alan zorunludur';
        if (v.trim().length < 6) return 'En az 6 karakter olmalıdır';
        if (isConfirm && v.trim() != _newPassCtrl.text.trim()) return 'Şifreler eşleşmiyor';
        return null;
      },
    );
  }
}

// ─── Hafız Doğrulama Sheet ────────────────────────────────────────────────────

class _HafizSheet extends StatefulWidget {
  final String uid;
  final bool isHafiz;
  final String name;
  final String username;
  final String? avatarSeed;
  final VoidCallback? onBack;

  const _HafizSheet({
    required this.uid,
    required this.isHafiz,
    required this.name,
    required this.username,
    this.avatarSeed,
    this.onBack,
  });

  @override
  State<_HafizSheet> createState() => _HafizSheetState();
}

class _HafizSheetState extends State<_HafizSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  final _linkCtrl = TextEditingController();
  bool _consentGiven = false;
  bool _loading = false;
  bool _resubmitting = false;
  late final Stream<DocumentSnapshot> _requestStream;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.name);
    _requestStream = FirebaseFirestore.instance
        .collection('hafiz_requests')
        .doc(widget.uid)
        .snapshots();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _linkCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_consentGiven) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen onay kutusunu işaretleyin.')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      final link = _linkCtrl.text.trim();
      await FirebaseFirestore.instance
          .collection('hafiz_requests')
          .doc(widget.uid)
          .set({
        'uid': widget.uid,
        'name': _nameCtrl.text.trim(),
        'username': widget.username,
        'avatarSeed': widget.avatarSeed,
        'type': 'verify',
        if (link.isNotEmpty) 'driveLink': link,
        'status': 'pending',
        'note': null,
        'requestedAt': FieldValue.serverTimestamp(),
        'reviewedAt': null,
        'consentGiven': true,
        'consentAt': FieldValue.serverTimestamp(),
      });
      if (mounted) setState(() { _loading = false; _resubmitting = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      final msg = e.toString().contains('permission-denied')
          ? 'Yetki hatası oluştu. Uygulamayı güncelleyip tekrar deneyin.'
          : 'Bağlantı hatası oluştu, tekrar deneyin.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<void> _submitRevokeRequest() async {
    final noteCtrl = TextEditingController();
    final String? userNote;
    try {
      userNote = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Hafız Statüsünü Kaldır', style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Yönetici inceledikten sonra rozetiniz kaldırılacaktır.',
                style: GoogleFonts.nunito(fontSize: 13, color: ctx.colors.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 14),
              Text('Açıklama (opsiyonel)',
                  style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w700, color: ctx.colors.textPrimary)),
              const SizedBox(height: 6),
              TextField(
                controller: noteCtrl,
                maxLines: 3,
                autofocus: false,
                decoration: InputDecoration(
                  hintText: 'Neden iptal etmek istediğinizi yazabilirsiniz…',
                  hintStyle: GoogleFonts.nunito(color: ctx.colors.textTertiary, fontSize: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.teal, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  isDense: true,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Vazgeç'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, noteCtrl.text.trim()),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.errorRed, elevation: 0),
              child: const Text('Başvuru Gönder', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    } finally {
      noteCtrl.dispose();
    }
    if (userNote == null) return;
    setState(() => _loading = true);
    try {
      await FirebaseFirestore.instance
          .collection('hafiz_requests')
          .doc(widget.uid)
          .set({
        'uid': widget.uid,
        'name': widget.name,
        'username': widget.username,
        'avatarSeed': widget.avatarSeed,
        'type': 'revoke',
        'status': 'pending',
        if (userNote.isNotEmpty) 'userNote': userNote,
        'note': null,
        'requestedAt': FieldValue.serverTimestamp(),
        'reviewedAt': null,
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bir hata oluştu, tekrar deneyin.')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildRevokePendingState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          const Icon(Icons.hourglass_top_rounded, color: AppColors.gold, size: 32),
          const SizedBox(height: 10),
          Text(
            'İptal Başvurunuz İnceleniyor',
            style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.gold),
          ),
          const SizedBox(height: 6),
          Text(
            'Hafız statünüzü kaldırma başvurunuz yönetici tarafından inceleniyor. Rozetiniz bu süreçte aktif kalmaya devam edecektir.',
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(fontSize: 13, color: context.colors.textSecondary, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildRevokeRejectedState(String? note) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.errorBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.errorRed.withValues(alpha: 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.cancel_outlined, color: AppColors.errorRed, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    'İptal Başvurunuz Reddedildi',
                    style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.errorRed),
                  ),
                ],
              ),
              if (note != null && note.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(note, style: GoogleFonts.nunito(fontSize: 13, color: context.colors.textPrimary, height: 1.5)),
              ],
              const SizedBox(height: 8),
              Text(
                'Hafız statünüz korundu.',
                style: GoogleFonts.nunito(fontSize: 13, color: AppColors.emeraldGreen, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _loading ? null : _submitRevokeRequest,
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: context.colors.textTertiary),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              'Tekrar Başvur',
              style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w700, color: context.colors.textSecondary),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: context.colors.border,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                if (widget.onBack != null)
                  GestureDetector(
                    onTap: widget.onBack,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        color: context.colors.surfaceVariant,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: context.colors.textSecondary),
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.emeraldGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.menu_book_rounded, color: AppColors.emeraldGreen, size: 20),
                ),
                const SizedBox(width: 10),
                Text(
                  'Hafız Doğrulaması',
                  style: GoogleFonts.nunito(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: context.colors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            StreamBuilder<DocumentSnapshot>(
              stream: _requestStream,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ));
                }
                if (snap.hasError) return _buildStreamError();
                final data = snap.data?.data() as Map<String, dynamic>?;
                final type = data?['type'] as String?;
                final status = data?['status'] as String?;
                // UserProvider'dan gerçek zamanlı isHafiz — widget.isHafiz stale olabilir
                final isHafizNow = context.select<UserProvider, bool>((p) => p.isHafiz);
                if (isHafizNow) {
                  if (type == 'revoke' && status == 'pending') return _buildRevokePendingState();
                  if (type == 'revoke' && status == 'rejected') return _buildRevokeRejectedState(data?['note'] as String?);
                  return _buildApprovedState();
                }
                // Hafız değil — sadece verify tipi başvuruları işle
                final isVerify = type == null || type == 'verify';
                if (data != null && isVerify && !_resubmitting) {
                  if (status == 'pending') return _buildPendingState();
                  if (status == 'rejected') return _buildRejectedState(data['note'] as String?);
                }
                return _buildForm();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStreamError() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.errorBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const Icon(Icons.wifi_off_rounded, color: AppColors.errorRed, size: 28),
          const SizedBox(height: 8),
          Text(
            'Bağlantı hatası oluştu.',
            style: GoogleFonts.nunito(fontSize: 13, color: AppColors.errorRed, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Lütfen internet bağlantınızı kontrol edip sayfayı kapatıp tekrar açın.',
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(fontSize: 12, color: context.colors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildApprovedState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.emeraldGreen.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.emeraldGreen.withValues(alpha: 0.25)),
          ),
          child: Column(
            children: [
              Icon(Icons.verified_rounded, color: AppColors.emeraldGreen, size: 36),
              const SizedBox(height: 10),
              Text(
                'Hafızlığınız doğrulandı',
                style: GoogleFonts.nunito(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.emeraldGreen,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Profilinizde HAFIZ rozeti görünmektedir.',
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(fontSize: 13, color: context.colors.textSecondary),
              ),
              const SizedBox(height: 12),
              Text(
                'Hafızlara özel içerikler için takipte kalın.',
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  color: AppColors.emeraldGreen.withValues(alpha: 0.75),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: _loading ? null : _submitRevokeRequest,
          child: Text(
            'Hafız statümü kaldırmak istiyorum',
            style: GoogleFonts.nunito(
              fontSize: 12,
              color: context.colors.textTertiary,
              decoration: TextDecoration.underline,
              decorationColor: context.colors.textTertiary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPendingState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.infoBlue.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.infoBlue.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Icon(Icons.hourglass_top_rounded, color: AppColors.infoBlue, size: 32),
          const SizedBox(height: 10),
          Text(
            'Başvurunuz İnceleniyor',
            style: GoogleFonts.nunito(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.infoBlue,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Hafızlık belgeniz incelendikten sonra hesabınıza HAFIZ rozeti eklenecektir.',
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(fontSize: 13, color: context.colors.textSecondary, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildRejectedState(String? note) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.errorBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.errorRed.withValues(alpha: 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.cancel_outlined, color: AppColors.errorRed, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    'Başvurunuz Reddedildi',
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.errorRed,
                    ),
                  ),
                ],
              ),
              if (note != null && note.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  note,
                  style: GoogleFonts.nunito(fontSize: 13, color: context.colors.textPrimary, height: 1.5),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => setState(() {
              _resubmitting = true;
              _linkCtrl.clear();
              _consentGiven = false;
            }),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: AppColors.emeraldGreen),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              'Tekrar Başvur',
              style: GoogleFonts.nunito(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.emeraldGreen,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBenefitRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: AppColors.emeraldGreen),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.nunito(fontSize: 12.5, color: context.colors.textPrimary, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Faydalar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.emeraldGreen.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.emeraldGreen.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hafız rozetinin getirdikleri',
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.emeraldGreen,
                  ),
                ),
                const SizedBox(height: 10),
                _buildBenefitRow(Icons.verified_rounded, 'Profilinizde yeşil HAFIZ rozeti görünür'),
                _buildBenefitRow(Icons.radio_button_checked_rounded, 'Profil fotoğrafınız yeşil halkayla çerçevelenir'),
                _buildBenefitRow(Icons.people_outline_rounded, 'Ekip listesinde Hafız filtresiyle öne çıkarsınız'),
                _buildBenefitRow(Icons.lock_clock_outlined, 'Hafızlara özel görev ve etkinlikler (yakında)'),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // Gizlilik bilgilendirmesi
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.colors.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Başvurunuzu inceleyebilmemiz için hafızlık belgenizi Google Drive üzerinden paylaşabilir ya da ek bir not bırakabilirsiniz. Bu alan zorunlu değildir.\n\nPaylaştığınız bilgiler yalnızca hafızlık durumunuzu doğrulamak amacıyla kullanılacak; inceleme tamamlandıktan sonra sistemimizden kalıcı olarak silinecektir. Verileriniz herhangi bir üçüncü tarafla paylaşılmayacaktır.',
              style: GoogleFonts.nunito(
                fontSize: 12.5,
                color: context.colors.textSecondary,
                height: 1.55,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Ad Soyad',
            style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w700, color: context.colors.textPrimary),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _nameCtrl,
            style: GoogleFonts.nunito(fontSize: 14, color: context.colors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Belgedeki adınız',
              hintStyle: GoogleFonts.nunito(color: context.colors.textTertiary),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.teal, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Ad soyad zorunludur' : null,
          ),
          const SizedBox(height: 16),
          Text(
            'Belge veya Not (Opsiyonel)',
            style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w700, color: context.colors.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            'Drive linki paylaşıyorsanız "Bağlantıya sahip olan herkes görüntüleyebilir" ayarını seçin.',
            style: GoogleFonts.nunito(fontSize: 11.5, color: context.colors.textTertiary),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _linkCtrl,
            style: GoogleFonts.nunito(fontSize: 13, color: context.colors.textPrimary),
            keyboardType: TextInputType.multiline,
            maxLines: 3,
            minLines: 1,
            decoration: InputDecoration(
              hintText: 'Drive linki veya iletmek istediğiniz bir not…',
              hintStyle: GoogleFonts.nunito(color: context.colors.textTertiary, fontSize: 13),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.teal, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () => setState(() => _consentGiven = !_consentGiven),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: Checkbox(
                    value: _consentGiven,
                    onChanged: (v) => setState(() => _consentGiven = v ?? false),
                    activeColor: AppColors.teal,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Paylaştığım bilgilerin yalnızca hafızlık doğrulaması amacıyla kullanılacağını ve inceleme sonrasında kalıcı olarak silineceğini anlıyorum.',
                    style: GoogleFonts.nunito(fontSize: 12.5, color: context.colors.textSecondary, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _loading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.emeraldGreen,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: _loading
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : Text(
                      'Başvuruyu Gönder',
                      style: GoogleFonts.nunito(
                        fontSize: 15,
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

// ─── Magic Link Sheet ─────────────────────────────────────────────────────────

class _MagicLinkSheet extends StatefulWidget {
  final String email;
  const _MagicLinkSheet({required this.email});

  @override
  State<_MagicLinkSheet> createState() => _MagicLinkSheetState();
}

class _MagicLinkSheetState extends State<_MagicLinkSheet> {
  bool _isLoading = false;
  bool _sent = false;

  Future<void> _send() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('emailForSignIn', widget.email);
      final actionCodeSettings = ActionCodeSettings(
        url: 'https://virdapp.com',
        handleCodeInApp: true,
        androidPackageName: 'com.example.virdApp',
        androidInstallApp: false,
        iOSBundleId: 'com.example.virdApp',
      );
      await FirebaseAuth.instance.setLanguageCode('tr');
      await FirebaseAuth.instance.sendSignInLinkToEmail(
        email: widget.email,
        actionCodeSettings: actionCodeSettings,
      );
      if (mounted) setState(() { _isLoading = false; _sent = true; });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bir hata oluştu. Tekrar dene.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: context.colors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          if (_sent) ...[
            Container(
              width: 64, height: 64,
              decoration: const BoxDecoration(
                color: AppColors.successBg, shape: BoxShape.circle,
              ),
              child: const Icon(Icons.mark_email_read_outlined,
                  color: AppColors.successGreen, size: 32),
            ),
            const SizedBox(height: 16),
            Text('Link Gönderildi!',
                style: GoogleFonts.nunito(fontSize: 20,
                    fontWeight: FontWeight.w800, color: context.colors.textPrimary)),
            const SizedBox(height: 8),
            Text(
              '${widget.email} adresine giriş linki gönderildi.\nLinke tıkladığında o cihazda otomatik giriş yapılır.',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(fontSize: 14, color: context.colors.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 14, color: Color(0xFFB45309)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Mailı göremiyorsan spam / gereksiz klasörünü de kontrol etmeyi unutma.',
                      style: GoogleFonts.nunito(
                          fontSize: 12, color: const Color(0xFF92400E), height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: DuolingoButton(
                color: AppColors.teal,
                bottomColor: AppColors.tealDark,
                isLoading: false,
                onPressed: () => Navigator.pop(context),
                child: Text('TAMAM',
                    style: GoogleFonts.nunito(fontSize: 16,
                        fontWeight: FontWeight.w800, color: Colors.white)),
              ),
            ),
          ] else ...[
            Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                      color: context.colors.tealSurface, shape: BoxShape.circle),
                  child: const Icon(Icons.link_rounded,
                      color: AppColors.teal, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Başka Cihazdan Giriş',
                          style: GoogleFonts.nunito(fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: context.colors.textPrimary)),
                      Text('Tek tıkla giriş linki al',
                          style: GoogleFonts.nunito(
                              fontSize: 13, color: context.colors.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: context.colors.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.mail_outline_rounded,
                      color: context.colors.textTertiary, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(widget.email,
                        style: GoogleFonts.nunito(fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: context.colors.textPrimary)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Bu adrese bir giriş linki gönderilecek. Linki almak istediğin cihazda e-postanı aç ve linke tıkla — şifre gerekmeden otomatik giriş yapılır.',
              style: GoogleFonts.nunito(fontSize: 13,
                  color: context.colors.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: DuolingoButton(
                color: AppColors.teal,
                bottomColor: AppColors.tealDark,
                isLoading: _isLoading,
                onPressed: _isLoading ? null : _send,
                child: Text('GİRİŞ LİNKİ GÖNDER',
                    style: GoogleFonts.nunito(fontSize: 15,
                        fontWeight: FontWeight.w800, color: Colors.white)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Kaynakça Bottom Sheet ────────────────────────────────────────────────────
class _KaynakcaSheet extends StatelessWidget {
  const _KaynakcaSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      padding: const EdgeInsets.only(top: 12, bottom: 24),
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: AppColors.borderGrey,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Kaynakça',
                  style: GoogleFonts.nunito(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textMid, size: 20),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── GİRİŞ ──────────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.tealLight,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: AppColors.teal.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.shield_outlined,
                                color: AppColors.tealDark, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Metin ve Kaynak Güvencesi',
                              style: GoogleFonts.nunito(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: AppColors.tealDark,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Uygulamadaki tüm hadis ve ayet alıntıları aşağıda tanıtılan birincil İslâmî kaynaklardan derlenmiştir. Her alıntının kaynağı ilgili içeriğin altında belirtilmiştir. Şahsi hükümler ve daha geniş bilgi için bu kaynaklara veya bir ilim ehline başvurulması tavsiye olunur.',
                          style: GoogleFonts.nunito(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                            height: 1.55,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // ── HADİS KOLEKSİYONLARI ───────────────────────────────
                  _kaynakSection(
                    'Hadis Koleksiyonları',
                    [
                      _Kaynak('Sahîh-i Buhârî',
                          'İmam Muhammed b. İsmâil el-Buhârî (ö. 256/870). Hadis ilminin en güvenilir ve muteber kaynağı; "Sahîhayn"ın birincisi.'),
                      _Kaynak('Sahîh-i Müslim',
                          'İmam Müslim b. Haccâc el-Kuşeyrî (ö. 261/875). Buhârî ile birlikte "Sahîhayn" adıyla anılır; İslam dünyasının en temel iki hadis külliyatından biri.'),
                      _Kaynak('Sünen-i Tirmizî',
                          'İmam Muhammed b. Îsâ et-Tirmizî (ö. 279/892). Kütüb-i Sitte\'nin önemli sünen koleksiyonu; her hadisin sıhhat derecesini de değerlendirir.'),
                      _Kaynak('Sünen-i Ebû Dâvûd',
                          'İmam Ebû Dâvûd Süleymân b. el-Eş\'as es-Sicistânî (ö. 275/889). Fıkhî hadislere zengin yer veren güvenilir sünen koleksiyonu.'),
                      _Kaynak('Sünen-i İbn Mâce',
                          'İmam Muhammed b. Yezîd İbn Mâce el-Kazvînî (ö. 273/887). Kütüb-i Sitte\'yi tamamlayan koleksiyon.'),
                      _Kaynak('Sünen-i Nesâî',
                          'İmam Ahmed b. Şuayb en-Nesâî (ö. 303/915). Kütüb-i Sitte\'nin en sahih sünen koleksiyonlarından biri; özellikle Amelü\'l-Yevm ve\'l-Leyle bölümü günlük zikir ve duaların kaynağıdır.'),
                      _Kaynak('Ahmed b. Hanbel — Müsned & Fedâilü\'s-Sahâbe',
                          'İmam Ahmed b. Hanbel (ö. 241/855). Müsned, en kapsamlı hadis derlemelerinden biridir. Fedâilü\'s-Sahâbe sahâbenin faziletlerini aktarır.'),
                      _Kaynak('Hâkim — el-Müstedrek',
                          'Hâkim en-Nîsâbûrî (ö. 405/1014). Buhârî ve Müslim\'in almadığı sahih hadisleri derlemiştir; sıhhat değerlendirmesi için Zehebî\'nin telhisi ile birlikte değerlendirilir.'),
                      _Kaynak('Beyhakî — es-Sünenü\'l-Kübrâ',
                          'İmam Beyhakî (ö. 458/1066). Fıkıh ve hadis konularında kapsamlı bir sünen koleksiyonu.'),
                    ],
                  ),

                  // ── KUR'AN MEALİ ────────────────────────────────────────
                  _kaynakSection(
                    'Kur\'an-ı Kerîm Meali',
                    [
                      _Kaynak('Diyanet İşleri Başkanlığı Meali',
                          'Uygulamada yer alan tüm ayet mealleri Diyanet İşleri Başkanlığı\'nın resmî Türkçe meali esas alınarak verilmiştir.'),
                    ],
                  ),

                  // ── FETVA KAYNAKLARI ────────────────────────────────────
                  _kaynakSection(
                    'Fetva ve Fıkıh Kaynakları',
                    [
                      _Kaynak('Kerahat Vakitleri',
                          'Alışkanlıklar → Namaz Bilgileri → Kerahat Vakitleri bölümündeki fıkhî kurallar şu kaynaklara dayanmaktadır:\n• diyanet.gov.tr — Din İşleri Yüksek Kurulu fetvaları\n• islamansiklopedisi.org.tr — "Vakit" ve "Kerahat" maddeleri'),
                      _Kaynak('Vird Faziletleri',
                          'Alışkanlıklar → Virdlerim bölümündeki sure, zikir ve dua faziletleri için ek kaynak:\n• islamansiklopedisi.org.tr — "Nebe\'", "Vâkıa", "Kehf", "Yâsîn" ve ilgili sure maddeleri (sure faziletleri ve hadis sıhhati değerlendirmeleri)'),
                    ],
                  ),

                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.lightGrey,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline_rounded,
                            size: 14, color: AppColors.textMid),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Mezhep odağı: Hanefi fıkhı esas alınmış; ihtilaflı meselelerde Diyanet İşleri Başkanlığı görüşü tercih edilmiştir.',
                            style: GoogleFonts.nunito(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textMid,
                              height: 1.5,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kaynakSection(String title, List<_Kaynak> items) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              title.toUpperCase(),
              style: GoogleFonts.nunito(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.teal,
                letterSpacing: 1.2,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderGrey),
            ),
            child: Column(
              children: [
                for (int i = 0; i < items.length; i++) ...[
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 4,
                          height: 28,
                          decoration: BoxDecoration(
                            color: AppColors.teal,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                items[i].name,
                                style: GoogleFonts.nunito(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textDark,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                items[i].desc,
                                style: GoogleFonts.nunito(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textMid,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (i < items.length - 1)
                    Divider(
                      height: 1,
                      color: AppColors.borderGrey.withValues(alpha: 0.6),
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

class _Kaynak {
  final String name;
  final String desc;
  const _Kaynak(this.name, this.desc);
}
