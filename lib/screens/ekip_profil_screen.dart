import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../app_colors.dart';
import '../app_assets.dart';
import '../models/team_model.dart';
import '../widgets/duolingo_button.dart';
import 'kullanici_profil_screen.dart';

// ─── Veri modeli ───────────────────────────────────────────────────────────────

class _MemberEntry {
  final String uid;
  final String name;
  final String username;
  final String? avatarSeed;
  final int todayHasanat;

  const _MemberEntry({
    required this.uid,
    required this.name,
    required this.username,
    required this.avatarSeed,
    required this.todayHasanat,
  });
}

// ─── Ana ekran ─────────────────────────────────────────────────────────────────

class EkipProfilScreen extends StatefulWidget {
  final String teamId;
  final String currentUid;

  const EkipProfilScreen({
    super.key,
    required this.teamId,
    required this.currentUid,
  });

  @override
  State<EkipProfilScreen> createState() => _EkipProfilScreenState();
}

class _EkipProfilScreenState extends State<EkipProfilScreen> {
  List<_MemberEntry> _leaderboard = [];
  bool _leaderboardLoading = true;
  Timer? _countdownTimer;
  Duration _untilMidnight = Duration.zero;

  @override
  void initState() {
    super.initState();
    _loadLeaderboard();
    _startCountdown();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _tick();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    if (mounted) setState(() => _untilMidnight = tomorrow.difference(now));
  }

  Future<void> _loadLeaderboard() async {
    if (!mounted) return;
    setState(() => _leaderboardLoading = true);

    try {
      final now = DateTime.now();
      final todayMidnight = DateTime(now.year, now.month, now.day);

      final membersSnap = await FirebaseFirestore.instance
          .collection('users')
          .where('teamId', isEqualTo: widget.teamId)
          .get();

      final entries = <_MemberEntry>[];

      for (final memberDoc in membersSnap.docs) {
        final uid = memberDoc.id;
        final data = memberDoc.data();

        final logsSnap = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('logs')
            .where('createdAt',
                isGreaterThanOrEqualTo: Timestamp.fromDate(todayMidnight))
            .get();

        int todayHasanat = 0;
        for (final log in logsSnap.docs) {
          final logData = log.data();
          todayHasanat += ((logData['pagesRead'] as int? ?? 0) * 10);
        }

        entries.add(_MemberEntry(
          uid: uid,
          name: data['name'] as String? ?? 'İsimsiz',
          username: data['username'] as String? ?? '',
          avatarSeed: data['avatarSeed'] as String?,
          todayHasanat: todayHasanat,
        ));
      }

      entries.sort((a, b) => b.todayHasanat.compareTo(a.todayHasanat));

      if (mounted) {
        setState(() {
          _leaderboard = entries;
          _leaderboardLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _leaderboardLoading = false);
    }
  }

  Future<void> _joinTeam() async {
    final db = FirebaseFirestore.instance;
    final batch = db.batch();
    batch.update(db.collection('users').doc(widget.currentUid), {
      'teamId': widget.teamId,
    });
    batch.update(db.collection('teams').doc(widget.teamId), {
      'memberCount': FieldValue.increment(1),
    });
    await batch.commit();
    _loadLeaderboard();
  }

  Future<void> _leaveTeam() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Ekipten Ayrıl',
          style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
        ),
        content: Text(
          'Ekipten ayrılmak istediğine emin misin?',
          style: GoogleFonts.nunito(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('İptal',
                style: GoogleFonts.nunito(color: AppColors.textMid)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Ayrıl',
                style: GoogleFonts.nunito(
                    color: AppColors.errorRed,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final db = FirebaseFirestore.instance;
    final batch = db.batch();
    batch.update(db.collection('users').doc(widget.currentUid), {
      'teamId': FieldValue.delete(),
    });
    batch.update(db.collection('teams').doc(widget.teamId), {
      'memberCount': FieldValue.increment(-1),
    });
    await batch.commit();
    _loadLeaderboard();
  }

  void _showEditSheet(BuildContext context, TeamModel team, String field) {
    final current =
        field == 'description' ? team.description : team.penaltyNote;
    final label =
        field == 'description' ? 'Açıklama' : 'Ceza Notu';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _EditFieldSheet(
        teamId: widget.teamId,
        field: field,
        label: label,
        current: current,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('teams')
            .doc(widget.teamId)
            .snapshots(),
        builder: (context, teamSnap) {
          if (!teamSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!teamSnap.data!.exists) {
            return const Center(child: Text('Ekip bulunamadı'));
          }

          final team = TeamModel.fromFirestore(teamSnap.data!);
          final isAdmin = team.adminUid == widget.currentUid;

          return StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(widget.currentUid)
                .snapshots(),
            builder: (context, userSnap) {
              final userData =
                  userSnap.data?.data() as Map<String, dynamic>?;
              final currentTeamId = userData?['teamId'] as String?;
              final isMember = currentTeamId == widget.teamId;

              return CustomScrollView(
                slivers: [
                  // ── Başlık ──────────────────────────────────────────────
                  SliverAppBar(
                    pinned: true,
                    expandedHeight: 140,
                    backgroundColor: AppColors.teal,
                    foregroundColor: Colors.white,
                    actions: [
                      if (isAdmin)
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, color: Colors.white),
                          onSelected: (v) =>
                              _showEditSheet(context, team, v),
                          itemBuilder: (_) => [
                            PopupMenuItem(
                              value: 'description',
                              child: Text('Açıklamayı Düzenle',
                                  style: GoogleFonts.nunito()),
                            ),
                            PopupMenuItem(
                              value: 'penaltyNote',
                              child: Text('Ceza Notunu Düzenle',
                                  style: GoogleFonts.nunito()),
                            ),
                          ],
                        ),
                    ],
                    flexibleSpace: FlexibleSpaceBar(
                      centerTitle: false,
                      titlePadding: const EdgeInsets.fromLTRB(56, 0, 48, 16),
                      title: Text(
                        team.name,
                        style: GoogleFonts.nunito(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      background: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF2A7F8C), Color(0xFF1F6370)],
                          ),
                        ),
                        child: Center(
                          child: team.logoAsset == 'rical_i_fark'
                              ? Opacity(
                                  opacity: 0.25,
                                  child: Image.asset(
                                    AppAssets.ricalIFarkLogo,
                                    height: 90,
                                    fit: BoxFit.contain,
                                  ),
                                )
                              : Icon(
                                  Icons.shield,
                                  size: 56,
                                  color: Colors.white.withValues(alpha: 0.15),
                                ),
                        ),
                      ),
                    ),
                  ),

                  // ── İçerik ──────────────────────────────────────────────
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 48),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        // Üye sayısı + üyelik butonu
                        Row(
                          children: [
                            const Icon(Icons.people_outline,
                                size: 15, color: AppColors.textMid),
                            const SizedBox(width: 4),
                            Text(
                              '${team.memberCount} üye',
                              style: GoogleFonts.nunito(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textMid,
                              ),
                            ),
                            const Spacer(),
                            if (!isAdmin)
                              _MembershipButton(
                                isMember: isMember,
                                onJoin: _joinTeam,
                                onLeave: _leaveTeam,
                              ),
                          ],
                        ),

                        // Açıklama
                        if (team.description.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _InfoCard(
                            icon: Icons.info_outline,
                            text: team.description,
                          ),
                        ],

                        // Ceza notu
                        if (team.penaltyNote.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _PenaltyCard(note: team.penaltyNote),
                        ],

                        const SizedBox(height: 20),

                        // Liderboard
                        _LeaderboardSection(
                          leaderboard: _leaderboard,
                          loading: _leaderboardLoading,
                          untilMidnight: _untilMidnight,
                          currentUid: widget.currentUid,
                          onRefresh: _loadLeaderboard,
                          onMemberTap: (uid) => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => KullaniciProfilScreen(uid: uid),
                            ),
                          ),
                        ),
                      ]),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

// ─── Üyelik Butonu ─────────────────────────────────────────────────────────────

class _MembershipButton extends StatelessWidget {
  final bool isMember;
  final VoidCallback onJoin;
  final VoidCallback onLeave;

  const _MembershipButton({
    required this.isMember,
    required this.onJoin,
    required this.onLeave,
  });

  @override
  Widget build(BuildContext context) {
    if (isMember) {
      return OutlinedButton(
        onPressed: onLeave,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.borderGrey),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(
          'Ayrıl',
          style: GoogleFonts.nunito(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textMid,
          ),
        ),
      );
    }

    return SizedBox(
      height: 36,
      child: DuolingoButton(
        color: AppColors.teal,
        bottomColor: AppColors.tealDark,
        height: 36,
        onPressed: onJoin,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Katıl',
            style: GoogleFonts.nunito(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Bilgi Kartı ───────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoCard({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.lightGrey,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.textMid),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.nunito(
                fontSize: 13,
                color: AppColors.textMid,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Ceza Notu Kartı ───────────────────────────────────────────────────────────

class _PenaltyCard extends StatelessWidget {
  final String note;

  const _PenaltyCard({required this.note});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        border: Border.all(color: const Color(0xFFFFE082)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded,
              size: 16, color: Color(0xFFF59E0B)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ceza Notu',
                  style: GoogleFonts.nunito(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFF59E0B),
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  note,
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    color: const Color(0xFF92400E),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Liderboard Bölümü ─────────────────────────────────────────────────────────

class _LeaderboardSection extends StatelessWidget {
  final List<_MemberEntry> leaderboard;
  final bool loading;
  final Duration untilMidnight;
  final String currentUid;
  final VoidCallback onRefresh;
  final void Function(String uid) onMemberTap;

  const _LeaderboardSection({
    required this.leaderboard,
    required this.loading,
    required this.untilMidnight,
    required this.currentUid,
    required this.onRefresh,
    required this.onMemberTap,
  });

  String _fmtDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  String _fmtHasanat(int n) {
    if (n == 0) return '0';
    final s = n.toString();
    if (s.length <= 3) return s;
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Başlık satırı
        Row(
          children: [
            Text(
              'Günlük Liderboard',
              style: GoogleFonts.nunito(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: onRefresh,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.lightGrey,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.refresh,
                    size: 18, color: AppColors.textMid),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        // Geri sayım
        Row(
          children: [
            const Icon(Icons.access_time,
                size: 13, color: AppColors.textLight),
            const SizedBox(width: 4),
            Text(
              'Sıfırlanmaya ${_fmtDuration(untilMidnight)} kaldı',
              style: GoogleFonts.nunito(
                fontSize: 12,
                color: AppColors.textLight,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (loading)
          const Center(
              child: Padding(
            padding: EdgeInsets.all(32),
            child: CircularProgressIndicator(),
          ))
        else if (leaderboard.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.lightGrey,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                'Bugün henüz okuma kaydedilmedi.',
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  color: AppColors.textLight,
                ),
              ),
            ),
          )
        else
          _buildList(),
      ],
    );
  }

  Widget _buildList() {
    final count = leaderboard.length;
    final showRedZone = count > 3;
    final redStartIdx = count - 3;

    return Column(
      children: List.generate(count, (i) {
        final entry = leaderboard[i];
        final isTop = i < 3;
        final isRed = showRedZone && i >= redStartIdx;
        final isMe = entry.uid == currentUid;

        return GestureDetector(
          onTap: () => onMemberTap(entry.uid),
          child: _LeaderboardRow(
            rank: i + 1,
            entry: entry,
            isTop: isTop,
            isRed: isRed,
            isMe: isMe,
            fmtHasanat: _fmtHasanat,
          ),
        );
      }),
    );
  }
}

// ─── Liderboard Satırı ─────────────────────────────────────────────────────────

class _LeaderboardRow extends StatelessWidget {
  final int rank;
  final _MemberEntry entry;
  final bool isTop;
  final bool isRed;
  final bool isMe;
  final String Function(int) fmtHasanat;

  const _LeaderboardRow({
    required this.rank,
    required this.entry,
    required this.isTop,
    required this.isRed,
    required this.isMe,
    required this.fmtHasanat,
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
    if (isMe) return AppColors.tealLight;
    if (isRed) return const Color(0xFFFFF0F0);
    if (rank == 1) return const Color(0xFFFFFBE6);
    return AppColors.white;
  }

  Color get _borderColor {
    if (isMe) return AppColors.teal;
    if (isRed) return const Color(0xFFFFCDD2);
    if (rank == 1) return const Color(0xFFFFE57F);
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
                      color: isRed
                          ? AppColors.errorRed
                          : AppColors.textMid,
                    ),
                  ),
          ),
          const SizedBox(width: 8),
          // Avatar
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.tealLight,
            backgroundImage: entry.avatarSeed != null
                ? NetworkImage(
                    'https://api.dicebear.com/7.x/micah/png?seed=${entry.avatarSeed}&backgroundColor=transparent',
                  )
                : null,
            child: entry.avatarSeed == null
                ? Text(
                    entry.name.isNotEmpty
                        ? entry.name.substring(0, 1).toUpperCase()
                        : '?',
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.teal,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 10),
          // İsim
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        entry.name,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.nunito(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 4),
                      Text(
                        '(sen)',
                        style: GoogleFonts.nunito(
                          fontSize: 11,
                          color: AppColors.teal,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
                if (entry.username.isNotEmpty)
                  Text(
                    '@${entry.username}',
                    style: GoogleFonts.nunito(
                      fontSize: 11,
                      color: AppColors.textLight,
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
                fmtHasanat(entry.todayHasanat),
                style: GoogleFonts.nunito(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: entry.todayHasanat > 0
                      ? AppColors.gold
                      : AppColors.textLight,
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

// ─── Alan Düzenleme Sheet ──────────────────────────────────────────────────────

class _EditFieldSheet extends StatefulWidget {
  final String teamId;
  final String field;
  final String label;
  final String current;

  const _EditFieldSheet({
    required this.teamId,
    required this.field,
    required this.label,
    required this.current,
  });

  @override
  State<_EditFieldSheet> createState() => _EditFieldSheetState();
}

class _EditFieldSheetState extends State<_EditFieldSheet> {
  late TextEditingController _ctrl;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.current);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance
          .collection('teams')
          .doc(widget.teamId)
          .update({widget.field: _ctrl.text.trim()});
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Hata: $e')));
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
            '${widget.label} Düzenle',
            style: GoogleFonts.nunito(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _ctrl,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: widget.label,
              labelStyle: GoogleFonts.nunito(color: AppColors.textMid),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.teal, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 20),
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
    );
  }
}
