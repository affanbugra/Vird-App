import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app_colors.dart';
import '../utils/name_utils.dart';
import 'kullanici_profil_screen.dart';

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
      backgroundColor: const Color(0xFFF8FAFC),
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
                    style: GoogleFonts.nunito(color: AppColors.textMid),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 16),
                itemCount: docs.length,
                itemBuilder: (context, index) {
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

  List<Map<String, dynamic>> get _displayed {
    if (!_showLow) return widget.rankings;
    return widget.rankings
        .where((r) => (r['periodHasanat'] as int? ?? 0) < 100)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final displayed = _displayed;
    final totalCount = widget.rankings.length;
    final count = displayed.length;
    final showRedZone = !_showLow && count > 3;
    final redStartIdx = count - 3;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.borderGrey.withValues(alpha: 0.5)),
      ),
      color: Colors.white,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: widget.isFirst,
        title: Text(
          widget.dateStr,
          style: GoogleFonts.nunito(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AppColors.textDark,
          ),
        ),
        subtitle: Text(
          _showLow ? '$count / $totalCount kişi' : '$totalCount üye',
          style: GoogleFonts.nunito(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textMid,
          ),
        ),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.tealLight,
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
                style: GoogleFonts.nunito(color: AppColors.textMid),
              ),
            )
          else ...[
            // Filtre chip
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: Row(
                children: [
                  const Spacer(),
                  _FilterChip(
                    selected: _showLow,
                    onTap: () => setState(() => _showLow = !_showLow),
                  ),
                ],
              ),
            ),

            if (displayed.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: Text(
                  'Herkes bu hafta 100 puanı aştı 🎉',
                  style: GoogleFonts.nunito(
                      color: AppColors.textMid, fontSize: 13),
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

  const _GecmisRow({
    required this.rank,
    required this.name,
    this.avatarSeed,
    required this.hasanat,
    required this.isTop,
    required this.isRed,
    this.isDeepRed = false,
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

  Color get _bgColor {
    if (isDeepRed) return AppColors.errorRed.withValues(alpha: 0.48);
    if (isRed) return AppColors.errorBg;
    if (rank == 1) return AppColors.successBg;
    if (rank == 2) return AppColors.successBg.withValues(alpha: 0.6);
    if (rank == 3) return AppColors.successBg.withValues(alpha: 0.3);
    return AppColors.white;
  }

  Color get _borderColor {
    if (isDeepRed) return AppColors.errorRed.withValues(alpha: 0.85);
    if (isRed) return AppColors.errorRed.withValues(alpha: 0.3);
    if (rank == 1) return AppColors.successGreen.withValues(alpha: 0.5);
    if (rank == 2) return AppColors.successGreen.withValues(alpha: 0.3);
    if (rank == 3) return AppColors.successGreen.withValues(alpha: 0.15);
    return AppColors.borderGrey;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _bgColor,
        border: Border.all(color: _borderColor),
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
                      color: isRed ? AppColors.errorRed : AppColors.textMid,
                    ),
                  ),
          ),
          const SizedBox(width: 8),
          // Avatar
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.tealLight,
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
          const SizedBox(width: 10),
          // İsim ve kullanıcı adı
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
              ],
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
                  color: hasanat > 0 ? AppColors.gold : AppColors.textLight,
                ),
              ),
              Text(
                'hasanat',
                style: GoogleFonts.nunito(
                  fontSize: 9,
                  color: AppColors.textLight,
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

class _FilterChip extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.errorRed.withValues(alpha: 0.12)
              : AppColors.lightGrey,
          border: Border.all(
            color: selected ? AppColors.errorRed : AppColors.borderGrey,
            width: selected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          '⚠️ <100 Puan',
          style: GoogleFonts.nunito(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected ? AppColors.errorRed : AppColors.textMid,
          ),
        ),
      ),
    );
  }
}
