import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app_colors.dart';
import '../app_theme.dart';
import '../utils/name_utils.dart';
import 'kullanici_profil_screen.dart';

enum _HafizFilter { none, hafizOnly, nonHafiz }

class EkipGecmisScreen extends StatelessWidget {
  final String teamId;
  final String teamName;
  final bool isAdmin;

  const EkipGecmisScreen({
    super.key,
    required this.teamId,
    required this.teamName,
    this.isAdmin = false,
  });

  String _formatDate(String yyyyMmDd, [DateTime? teamCreatedAtDay]) {
    final parts = yyyyMmDd.split('-');
    if (parts.length != 3) return yyyyMmDd;
    final yearInt = int.tryParse(parts[0]) ?? 2026;
    final monthInt = int.tryParse(parts[1]) ?? 1;
    final dayInt = int.tryParse(parts[2]) ?? 1;

    DateTime startDt = DateTime(yearInt, monthInt, dayInt);
    final endDt = startDt.add(const Duration(days: 6));

    if (teamCreatedAtDay != null && startDt.isBefore(teamCreatedAtDay)) {
      startDt = teamCreatedAtDay;
    }

    const months = [
      '', 'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
      'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'
    ];

    final startStr = '${startDt.day} ${months[startDt.month]}';
    final endStr = '${endDt.day} ${months[endDt.month]}';

    if (startDt.year == endDt.year) {
      return '$startStr – $endStr ${startDt.year}';
    } else {
      return '$startStr ${startDt.year} – $endStr ${endDt.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.teal,
        foregroundColor: Colors.white,
        title: Text(
          'Geçmiş Sıralamalar',
          style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
        ),
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('teams').doc(teamId).get(),
        builder: (context, teamSnap) {
          if (teamSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final teamData = teamSnap.data?.data() as Map<String, dynamic>?;
          final createdAtTs = teamData?['createdAt'] as Timestamp?;
          final createdDate = createdAtTs?.toDate() ?? DateTime(2020, 1, 1);
          final teamCreatedAtDay = DateTime(
              createdDate.year, createdDate.month, createdDate.day);

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('teams')
                .doc(teamId)
                .collection('history')
                .orderBy('date', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                    child: Text('Bir hata oluştu.',
                        style: GoogleFonts.nunito()));
              }

              final allDocs = snapshot.data?.docs ?? [];

              var docs = allDocs.where((doc) {
                final parts = doc.id.split('-');
                if (parts.length == 3) {
                  final docDate = DateTime(
                    int.tryParse(parts[0]) ?? 1970,
                    int.tryParse(parts[1]) ?? 1,
                    int.tryParse(parts[2]) ?? 1,
                  );
                  final docEndDate = docDate.add(const Duration(days: 6));
                  if (!docEndDate.isAfter(teamCreatedAtDay)) return false;
                }
                return true;
              }).toList();

              if (!isAdmin && docs.isNotEmpty) {
                docs = [docs.first];
              }

              if (docs.isEmpty) {
                return Center(
                  child: Text(
                    'Henüz geçmiş sıralama bulunmuyor.',
                    style: GoogleFonts.nunito(color: context.colors.textSecondary),
                  ),
                );
              }

              // non-admin için son öğe olarak lider notu eklenir
              final itemCount = docs.length + (isAdmin ? 0 : 1);

              return ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 16),
                itemCount: itemCount,
                itemBuilder: (context, index) {
                  if (!isAdmin && index == docs.length) {
                    return _LeaderNote();
                  }
                  final doc = docs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final rankings = (data['rankings'] as List<dynamic>? ?? [])
                      .cast<Map<String, dynamic>>();
                  final dateStr = _formatDate(doc.id, teamCreatedAtDay);

                  return _GecmisWeekCard(
                    dateStr: dateStr,
                    rankings: rankings,
                    isFirst: index == 0,
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

// ─── Lider Notu (non-admin) ───────────────────────────────────────────────────

class _LeaderNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 14, color: context.colors.textTertiary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Tüm geçmiş hafta sıralamalarını ekip liderleri görebilir.',
              style: GoogleFonts.nunito(
                fontSize: 12,
                color: context.colors.textTertiary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Haftalık Kart ────────────────────────────────────────────────────────────

class _GecmisWeekCard extends StatefulWidget {
  final String dateStr;
  final List<Map<String, dynamic>> rankings;
  final bool isFirst;

  const _GecmisWeekCard({
    required this.dateStr,
    required this.rankings,
    this.isFirst = false,
  });

  @override
  State<_GecmisWeekCard> createState() => _GecmisWeekCardState();
}

class _GecmisWeekCardState extends State<_GecmisWeekCard> {
  bool _showLow = false;
  _HafizFilter _hafizFilter = _HafizFilter.none;

  List<Map<String, dynamic>> get _displayed {
    var list = widget.rankings;

    if (_hafizFilter == _HafizFilter.hafizOnly) {
      list = list.where((r) => (r['isHafiz'] as bool?) == true).toList();
    } else if (_hafizFilter == _HafizFilter.nonHafiz) {
      list = list.where((r) => (r['isHafiz'] as bool?) != true).toList();
    }

    if (_showLow) {
      list = list.where((r) => (r['periodHasanat'] as int? ?? 0) < 100).toList();
    }

    return list;
  }

  String get _hafizLabel {
    switch (_hafizFilter) {
      case _HafizFilter.hafizOnly:
        return '📖 Sadece Hafız';
      case _HafizFilter.nonHafiz:
        return '📖 Hafız Hariç';
      case _HafizFilter.none:
        return '📖 Hafız';
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayed = _displayed;
    final totalCount = widget.rankings.length;
    final count = displayed.length;
    final filtered = _hafizFilter != _HafizFilter.none || _showLow;
    final showRedZone = !_showLow && count > 3;
    final redStartIdx = count - 3;

    final subtitleText = filtered
        ? '$count / $totalCount kişi'
        : '$totalCount üye';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: context.colors.border.withValues(alpha: 0.5)),
      ),
      color: context.colors.surface,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: widget.isFirst,
        title: Text(
          widget.dateStr,
          style: GoogleFonts.nunito(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: context.colors.textPrimary,
          ),
        ),
        subtitle: Text(
          subtitleText,
          style: GoogleFonts.nunito(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: context.colors.textSecondary,
          ),
        ),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: context.colors.tealSurface,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.history, color: AppColors.teal, size: 20),
        ),
        children: [
          const Divider(height: 1),
          if (widget.rankings.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Bu hafta hiç okuma yapılmamış.',
                style: GoogleFonts.nunito(color: context.colors.textSecondary),
              ),
            )
          else ...[
            // Filtre satırı
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: Row(
                children: [
                  _GecmisFilterChip(
                    label: _hafizLabel,
                    selected: _hafizFilter != _HafizFilter.none,
                    selectedColor: AppColors.emeraldGreen,
                    onTap: () => setState(() {
                      _hafizFilter = switch (_hafizFilter) {
                        _HafizFilter.none      => _HafizFilter.hafizOnly,
                        _HafizFilter.hafizOnly => _HafizFilter.nonHafiz,
                        _HafizFilter.nonHafiz  => _HafizFilter.none,
                      };
                    }),
                  ),
                  const Spacer(),
                  _GecmisFilterChip(
                    label: '⚠️ <100 Puan',
                    selected: _showLow,
                    selectedColor: AppColors.errorRed,
                    onTap: () => setState(() => _showLow = !_showLow),
                  ),
                ],
              ),
            ),

            if (displayed.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: Text(
                  _showLow
                      ? 'Herkes bu hafta 100 puanı aştı 🎉'
                      : 'Bu filtreye uyan üye yok.',
                  style: GoogleFonts.nunito(
                      color: context.colors.textSecondary, fontSize: 13),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                child: Column(
                  children: List.generate(count, (i) {
                    final r = displayed[i];
                    final rank = i + 1;
                    final hasanat = r['periodHasanat'] as int? ?? 0;
                    final isTop = !_showLow && i < 3;
                    final isDeepRed = _showLow && hasanat == 0;
                    final isRed = isDeepRed ||
                        hasanat == 0 ||
                        _showLow ||
                        (!isTop && showRedZone && i >= redStartIdx);
                    final uid = r['uid'] as String?;
                    final isHafiz = (r['isHafiz'] as bool?) ?? false;

                    return GestureDetector(
                      onTap: uid != null
                          ? () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        KullaniciProfilScreen(uid: uid)),
                              )
                          : null,
                      child: _GecmisRow(
                        rank: rank,
                        name: r['name'] as String? ?? 'İsimsiz',
                        avatarSeed: r['avatarSeed'] as String?,
                        hasanat: hasanat,
                        isTop: isTop,
                        isRed: isRed,
                        isDeepRed: isDeepRed,
                        isHafiz: isHafiz,
                      ),
                    );
                  }),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

// ─── Satır ────────────────────────────────────────────────────────────────────

class _GecmisRow extends StatelessWidget {
  final int rank;
  final String name;
  final String? avatarSeed;
  final int hasanat;
  final bool isTop;
  final bool isRed;
  final bool isDeepRed;
  final bool isHafiz;

  const _GecmisRow({
    required this.rank,
    required this.name,
    this.avatarSeed,
    required this.hasanat,
    required this.isTop,
    required this.isRed,
    this.isDeepRed = false,
    this.isHafiz = false,
  });

  String get _medal {
    switch (rank) {
      case 1:
        return '🥇';
      case 2:
        return '🥈';
      case 3:
        return '🥉';
      default:
        return '';
    }
  }

  Color _bgColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark) {
      if (isDeepRed) return AppColors.errorRed.withValues(alpha: 0.22);
      if (isRed) return AppColors.errorRed.withValues(alpha: 0.10);
      if (rank == 1) return AppColors.successGreen.withValues(alpha: 0.18);
      if (rank == 2) return AppColors.successGreen.withValues(alpha: 0.12);
      if (rank == 3) return AppColors.successGreen.withValues(alpha: 0.07);
      return Colors.transparent;
    }
    if (isDeepRed) return AppColors.errorRed.withValues(alpha: 0.48);
    if (isRed) return AppColors.errorBg;
    if (rank == 1) return AppColors.successBg;
    if (rank == 2) return AppColors.successBg.withValues(alpha: 0.6);
    if (rank == 3) return AppColors.successBg.withValues(alpha: 0.3);
    return Colors.transparent;
  }

Color _resolvedBorderColor(BuildContext context) {
    if (isDeepRed) return AppColors.errorRed.withValues(alpha: 0.85);
    if (isRed) return AppColors.errorRed.withValues(alpha: 0.3);
    if (rank == 1) return AppColors.successGreen.withValues(alpha: 0.5);
    if (rank == 2) return AppColors.successGreen.withValues(alpha: 0.3);
    if (rank == 3) return AppColors.successGreen.withValues(alpha: 0.15);
    return context.colors.border;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _bgColor(context),
        border: Border.all(color: _resolvedBorderColor(context)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Sıra / madalya
          SizedBox(
            width: 32,
            child: isTop
                ? Text(
                    _medal,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 20),
                  )
                : Text(
                    '$rank',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: isRed ? AppColors.errorRed : context.colors.textSecondary,
                    ),
                  ),
          ),
          const SizedBox(width: 8),
          // Avatar (hafız halkası)
          Container(
            padding: isHafiz ? const EdgeInsets.all(2) : EdgeInsets.zero,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: isHafiz
                  ? Border.all(color: AppColors.emeraldGreen, width: 2)
                  : null,
            ),
            child: CircleAvatar(
              radius: 18,
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
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.teal,
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 10),
          // İsim
          Expanded(
            child: Text(
              name,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.nunito(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: context.colors.textPrimary,
              ),
            ),
          ),
          // Hasanat
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$hasanat',
                style: GoogleFonts.nunito(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: hasanat > 0 ? AppColors.gold : context.colors.textTertiary,
                ),
              ),
              Text(
                'hasanat',
                style: GoogleFonts.nunito(
                  fontSize: 9,
                  color: context.colors.textTertiary,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Filtre Chip ──────────────────────────────────────────────────────────────

class _GecmisFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color selectedColor;

  const _GecmisFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.selectedColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? selectedColor.withValues(alpha: 0.12)
              : context.colors.surfaceVariant,
          border: Border.all(
            color: selected ? selectedColor : context.colors.border,
            width: selected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: GoogleFonts.nunito(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected ? selectedColor : context.colors.textSecondary,
          ),
        ),
      ),
    );
  }
}
