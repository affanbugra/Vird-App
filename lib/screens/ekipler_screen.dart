import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../app_colors.dart';
import '../app_assets.dart';
import '../app_theme.dart';
import '../config/team_limits.dart';
import '../models/team_model.dart';
import '../widgets/duolingo_button.dart';
import 'ekip_profil_screen.dart';

String _generateInviteCode() {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final random = Random.secure();
  return List.generate(6, (_) => chars[random.nextInt(chars.length)]).join();
}

// ─── Ana ekran ────────────────────────────────────────────────────────────────

class EkiplerScreen extends StatelessWidget {
  const EkiplerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    return Scaffold(
      backgroundColor: context.colors.surface,
      appBar: AppBar(
        backgroundColor: context.colors.surface,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Ekipler',
          style: GoogleFonts.nunito(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: context.colors.textPrimary,
          ),
        ),
      ),
      body: _EkiplerBody(uid: uid),
    );
  }
}

// ─── Ana gövde ────────────────────────────────────────────────────────────────

class _EkiplerBody extends StatelessWidget {
  final String uid;
  const _EkiplerBody({required this.uid});

  void _openCreateSheet(
    BuildContext context,
    bool isPro,
    bool isDeveloper,
    List<String> adminTeamIds,
    String cinsiyet,
  ) {
    if (!TeamLimits.canCreate(
        isPro: isPro, isDev: isDeveloper, adminCount: adminTeamIds.length)) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Ekip Limiti',
            style: GoogleFonts.nunito(
                fontWeight: FontWeight.w800, color: context.colors.textPrimary),
          ),
          content: Text(
            TeamLimits.createLimitMessage(isPro: isPro, isDev: isDeveloper),
            style: GoogleFonts.nunito(color: context.colors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Tamam',
                  style: GoogleFonts.nunito(
                      color: AppColors.teal, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _CreateTeamSheet(
        uid: uid,
        isDeveloper: isDeveloper,
        isPro: isPro,
        cinsiyet: cinsiyet,
        adminTeamIds: adminTeamIds,
        onCreated: (teamId) => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => EkipProfilScreen(teamId: teamId, currentUid: uid)),
        ),
      ),
    );
  }

  void _openInviteCodeSheet(
    BuildContext context,
    bool isPro,
    bool isDeveloper,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _InviteCodeSheet(
        uid: uid,
        isDeveloper: isDeveloper,
        isPro: isPro,
        onTeamFound: (teamId) => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => EkipProfilScreen(teamId: teamId, currentUid: uid)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, userSnap) {
        final userData = userSnap.data?.data() as Map<String, dynamic>?;
        final isPro = (userData?['isPro'] as bool?) ?? false;
        final isDeveloper = (userData?['isDeveloper'] as bool?) ?? false;
        final teamIds = ((userData?['teamIds']) as List?)
                ?.map((e) => e.toString())
                .toList() ??
            const <String>[];
        final adminTeamIds = ((userData?['adminTeamIds']) as List?)
                ?.map((e) => e.toString())
                .toList() ??
            const <String>[];
        final pendingTeamIds = ((userData?['pendingTeamIds']) as List?)
                ?.map((e) => e.toString())
                .toList() ??
            const <String>[];
        final cinsiyet = (userData?['cinsiyet'] as String?) ?? '';

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('teams')
              .orderBy('memberCount', descending: true)
              .snapshots(),
          builder: (context, teamsSnap) {
            final allTeams = teamsSnap.data?.docs
                    .map((d) => TeamModel.fromFirestore(d))
                    .toList() ??
                [];

            // Stale adminTeamIds temizliği: gerçekte var olmayan ekipleri anında filtrele + Firestore'dan sil
            final existingIds = allTeams.map((t) => t.id).toSet();
            final validAdminTeamIds = teamsSnap.hasData
                ? adminTeamIds.where((id) => existingIds.contains(id)).toList()
                : adminTeamIds;
            if (teamsSnap.hasData && validAdminTeamIds.length < adminTeamIds.length) {
              final staleIds = adminTeamIds.where((id) => !existingIds.contains(id)).toList();
              FirebaseFirestore.instance.collection('users').doc(uid).update({
                'adminTeamIds': FieldValue.arrayRemove(staleIds),
                'teamIds': FieldValue.arrayRemove(staleIds),
              });
            }

            final teams = allTeams.where((t) {
              // Cinsiyet politikası: yanlış cinsiyete tamamen görünmez (dev bypass)
              if (cinsiyet.isNotEmpty) {
                if (t.genderPolicy == 'men' && cinsiyet == 'hanim') return false;
                if (t.genderPolicy == 'women' && cinsiyet == 'bey') return false;
              }
              // Gizli ekipler: sadece üye veya pending olanlar görür
              if (t.isPrivate && !teamIds.contains(t.id) && !pendingTeamIds.contains(t.id)) return false;
              return true;
            }).toList();

            if (teamsSnap.connectionState == ConnectionState.waiting &&
                teams.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            return Column(
              children: [
                Expanded(
                  child: teams.isEmpty
                      ? const _EmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                          itemCount: teams.length,
                          itemBuilder: (ctx, i) {
                            final team = teams[i];
                            final isMyTeam = teamIds.contains(team.id);
                            final isAdmin = adminTeamIds.contains(team.id);
                            final isPending = pendingTeamIds.contains(team.id);

                            void openProfile() => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => EkipProfilScreen(
                                      teamId: team.id,
                                      currentUid: uid,
                                      isAdmin: isAdmin,
                                    ),
                                  ),
                                );

                            void handleTap() {
                              if (isPending && team.isPrivate) {
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (_) => _PendingTeamSheet(
                                    teamId: team.id,
                                    teamName: team.name,
                                    currentUid: uid,
                                  ),
                                );
                                return;
                              }
                              openProfile();
                            }

                            if (isAdmin) {
                              return StreamBuilder<QuerySnapshot>(
                                stream: FirebaseFirestore.instance
                                    .collection('teams')
                                    .doc(team.id)
                                    .collection('requests')
                                    .snapshots(),
                                builder: (ctx, reqSnap) {
                                  final pendingCount = reqSnap.data?.docs.length ?? 0;
                                  return _TeamCard(
                                    team: team,
                                    isMyTeam: isMyTeam,
                                    isAdmin: true,
                                    isPending: false,
                                    pendingCount: pendingCount,
                                    onTap: openProfile,
                                  );
                                },
                              );
                            }
                            return _TeamCard(
                              team: team,
                              isMyTeam: isMyTeam,
                              isAdmin: false,
                              isPending: isPending,
                              pendingCount: null,
                              onTap: handleTap,
                            );
                          },
                        ),
                ),

                // ── Alt aksiyon çubuğu ──────────────────────────────────────
                Container(
                  decoration: BoxDecoration(
                    color: context.colors.surface,
                    border: Border(top: BorderSide(color: context.colors.border)),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: () =>
                                  _openInviteCodeSheet(context, isPro, isDeveloper),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppColors.teal),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              child: Text(
                                'Davet Koduyla Katıl',
                                style: GoogleFonts.nunito(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.teal,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: DuolingoButton(
                              color: AppColors.teal,
                              bottomColor: AppColors.tealDark,
                              onPressed: () => _openCreateSheet(
                                  context, isPro, isDeveloper, validAdminTeamIds, cinsiyet),
                              child: Text(
                                'Yeni Ekip Kur',
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
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// ─── Boş durum ────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shield_outlined,
                size: 64, color: context.colors.border),
            const SizedBox(height: 16),
            Text(
              'Henüz hiç ekip yok',
              style: GoogleFonts.nunito(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: context.colors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'İlk ekibi sen kur.',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 14,
                color: context.colors.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Ekip Kartı ───────────────────────────────────────────────────────────────

class _TeamCard extends StatelessWidget {
  final TeamModel team;
  final bool isMyTeam;
  final bool isAdmin;
  final bool isPending;
  final int? pendingCount;
  final VoidCallback onTap;

  const _TeamCard({
    required this.team,
    required this.isMyTeam,
    required this.isAdmin,
    required this.isPending,
    required this.onTap,
    this.pendingCount,
  });

  Widget _buildLogo() {
    final logoKey = (team.logoAsset ?? '').replaceAll('"', '').trim();
    if (logoKey.startsWith('rical_i_fark')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.asset(
          AppAssets.ricalIFarkLogo,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
        ),
      );
    }
    return Builder(
      builder: (context) => Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: isMyTeam
              ? AppColors.teal.withValues(alpha: 0.15)
              : context.colors.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          Icons.shield_outlined,
          color: isMyTeam ? AppColors.teal : context.colors.textSecondary,
          size: 24,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isMyTeam ? context.colors.tealSurface : context.colors.surface,
          border: Border.all(
            color: isMyTeam ? AppColors.teal : context.colors.border,
            width: isMyTeam ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            _buildLogo(),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          team.name,
                          style: GoogleFonts.nunito(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: context.colors.textPrimary,
                          ),
                        ),
                      ),
                      if (isAdmin)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.teal,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'Liderim',
                            style: GoogleFonts.nunito(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        )
                      else if (isMyTeam)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.teal.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'Ekibim',
                            style: GoogleFonts.nunito(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        )
                      else if (isPending)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.gold.withValues(alpha: 0.15),
                            border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'Beklemede',
                            style: GoogleFonts.nunito(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.gold,
                            ),
                          ),
                        ),
                      if (team.isPrivate && !isMyTeam && !isPending)
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Icon(Icons.lock_outline,
                              size: 14, color: context.colors.textTertiary),
                        ),
                    ],
                  ),
                  if (team.description.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      team.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.nunito(
                          fontSize: 12, color: context.colors.textSecondary),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.people_outline,
                          size: 13, color: context.colors.textTertiary),
                      const SizedBox(width: 3),
                      Text(
                        '${team.memberCount} üye',
                        style: GoogleFonts.nunito(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: context.colors.textTertiary,
                        ),
                      ),
                      if (pendingCount != null && pendingCount! > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.orange.withValues(alpha: 0.15),
                            border: Border.all(color: AppColors.orange.withValues(alpha: 0.4), width: 0.8),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            '$pendingCount bekleyen',
                            style: GoogleFonts.nunito(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.orange,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: context.colors.textTertiary),
          ],
        ),
      ),
    );
  }
}

// ─── Bekleyen İstek Sheet (gizli ekip, onay bekleniyor) ──────────────────────

class _PendingTeamSheet extends StatefulWidget {
  final String teamId;
  final String teamName;
  final String currentUid;

  const _PendingTeamSheet({
    required this.teamId,
    required this.teamName,
    required this.currentUid,
  });

  @override
  State<_PendingTeamSheet> createState() => _PendingTeamSheetState();
}

class _PendingTeamSheetState extends State<_PendingTeamSheet> {
  bool _isLoading = false;

  Future<void> _cancelRequest() async {
    setState(() => _isLoading = true);
    try {
      final db = FirebaseFirestore.instance;
      final batch = db.batch();
      batch.delete(
        db.collection('teams').doc(widget.teamId).collection('requests').doc(widget.currentUid),
      );
      batch.update(db.collection('users').doc(widget.currentUid), {
        'pendingTeamIds': FieldValue.arrayRemove([widget.teamId]),
      });
      await batch.commit();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Hata: $e', style: GoogleFonts.nunito()),
          backgroundColor: AppColors.errorRed,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: context.colors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.gold.withValues(alpha: 0.4), width: 1.5),
              ),
              child: const Icon(Icons.hourglass_empty_rounded, color: AppColors.gold, size: 28),
            ),
            const SizedBox(height: 16),
            Text(
              'İsteğin Beklemede',
              style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w800, color: context.colors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              '"${widget.teamName}" ekibine katılma isteğin gönderildi. Ekip lideri isteğini inceleyip onaylayacak.',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(fontSize: 13, color: context.colors.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _isLoading ? null : _cancelRequest,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.errorRed),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.errorRed))
                    : Text('İsteği İptal Et', style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.errorRed)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Yeni Ekip Kur Sheet ──────────────────────────────────────────────────────

class _CreateTeamSheet extends StatefulWidget {
  final String uid;
  final bool isDeveloper;
  final bool isPro;
  final String cinsiyet;
  final List<String> adminTeamIds;
  final void Function(String teamId) onCreated;

  const _CreateTeamSheet({
    required this.uid,
    required this.isDeveloper,
    required this.isPro,
    required this.cinsiyet,
    required this.adminTeamIds,
    required this.onCreated,
  });

  @override
  State<_CreateTeamSheet> createState() => _CreateTeamSheetState();
}

class _CreateTeamSheetState extends State<_CreateTeamSheet> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool? _isPrivate;
  String? _genderPolicy;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _showError(String msg) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Eksik bilgi', style: GoogleFonts.nunito(fontWeight: FontWeight.w800, color: context.colors.textPrimary)),
        content: Text(msg, style: GoogleFonts.nunito(color: context.colors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Tamam', style: GoogleFonts.nunito(color: AppColors.teal, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Future<void> _create() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) { _showError('Ekip adı gerekli.'); return; }
    if (_isPrivate == null) { _showError('Görünürlüğü seçin.'); return; }
    if (_genderPolicy == null) { _showError('Katılım politikasını seçin.'); return; }
    if (_isPrivate == false && _genderPolicy == 'all') {
      _showError('Herkese açık ekip karışık olamaz. Gizli yapmak için "Sadece Davet" seçin.');
      return;
    }
    final c = widget.cinsiyet;
    if (c == 'bey' && _genderPolicy == 'women') {
      _showError('Beyler yalnızca hanımlara özel ekip açamaz.');
      return;
    }
    if (c == 'hanim' && _genderPolicy == 'men') {
      _showError('Hanımlar yalnızca beylere özel ekip açamaz.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final db = FirebaseFirestore.instance;

      // Açık ekiplerde davet kodu olmaz
      final inviteCode = (_isPrivate == true) ? _generateInviteCode() : '';
      final teamRef = db.collection('teams').doc();

      final batch = db.batch();
      batch.set(teamRef, {
        'name': name,
        'description': _descCtrl.text.trim(),
        'penaltyNote': '',
        'adminUid': widget.uid,
        'memberCount': 1,
        'isPrivate': _isPrivate,
        'genderPolicy': _genderPolicy,
        'inviteCode': inviteCode,
        'createdAt': FieldValue.serverTimestamp(),
      });
      batch.update(db.collection('users').doc(widget.uid), {
        'teamIds': FieldValue.arrayUnion([teamRef.id]),
        'adminTeamIds': FieldValue.arrayUnion([teamRef.id]),
      });
      await batch.commit();

      if (mounted) {
        Navigator.pop(context);
        widget.onCreated(teamRef.id);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Hata: $e', style: GoogleFonts.nunito()),
          backgroundColor: AppColors.errorRed,
        ));
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
                color: context.colors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            'Yeni Ekip Kur',
            style: GoogleFonts.nunito(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: context.colors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _nameCtrl,
            textInputAction: TextInputAction.next,
            maxLength: 50,
            decoration: InputDecoration(
              labelText: 'Ekip Adı *',
              labelStyle: GoogleFonts.nunito(color: context.colors.textSecondary),
              counterText: '',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.teal, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _descCtrl,
            maxLines: 3,
            maxLength: 300,
            decoration: InputDecoration(
              labelText: 'Açıklama (opsiyonel)',
              labelStyle: GoogleFonts.nunito(color: context.colors.textSecondary),
              counterText: '',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.teal, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Görünürlük',
            style: GoogleFonts.nunito(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: context.colors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          _PrivacyToggle(
            secili: _isPrivate,
            onChanged: (v) => setState(() {
              _isPrivate = v;
              // Açık seçilince karışık seçeneği geçersiz — temizle
              if (v == false && _genderPolicy == 'all') _genderPolicy = null;
            }),
          ),
          const SizedBox(height: 20),
          Text(
            'Katılım Politikası',
            style: GoogleFonts.nunito(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: context.colors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          _GenderPolicyToggle(
            secili: _genderPolicy,
            cinsiyet: widget.cinsiyet,
            isPublic: _isPrivate == false,
            onChanged: (v) => setState(() {
              _genderPolicy = v;
              // Karışık seçilince gizli zorunlu
              if (v == 'all') _isPrivate = true;
            }),
          ),
          if (_genderPolicy == 'all') ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.lock_outline, size: 11, color: AppColors.teal),
                const SizedBox(width: 4),
                Text(
                  'Karışık ekip otomatik olarak "Sadece Davet" yapıldı.',
                  style: GoogleFonts.nunito(fontSize: 10, color: AppColors.teal),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline,
                  size: 11, color: AppColors.gold),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Bu ayarlar bir kez belirlenir ve sonradan değiştirilemez. Dikkatle seçin.',
                  style: GoogleFonts.nunito(
                    fontSize: 10,
                    color: AppColors.gold,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: DuolingoButton(
              color: AppColors.teal,
              bottomColor: AppColors.tealDark,
              isLoading: _isLoading,
              onPressed: _isLoading ? null : _create,
              child: Text(
                'OLUŞTUR',
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

// ─── Davet Koduyla Katıl Sheet ────────────────────────────────────────────────

class _InviteCodeSheet extends StatefulWidget {
  final String uid;
  final bool isDeveloper;
  final bool isPro;
  final void Function(String teamId) onTeamFound;

  const _InviteCodeSheet({
    required this.uid,
    required this.isDeveloper,
    required this.isPro,
    required this.onTeamFound,
  });

  @override
  State<_InviteCodeSheet> createState() => _InviteCodeSheetState();
}

class _InviteCodeSheetState extends State<_InviteCodeSheet> {
  final _codeCtrl = TextEditingController();
  bool _isLoading = false;
  String? _error;
  bool _requestSent = false;
  String? _foundTeamId;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _codeCtrl.text.trim().toUpperCase();
    if (code.length != 6) {
      setState(() => _error = 'Kod 6 haneli olmalı.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final db = FirebaseFirestore.instance;

      // 1. Kullanıcı verisini oku
      final userDoc = await db.collection('users').doc(widget.uid).get();
      final userData = userDoc.data() ?? {};
      final teamIds = ((userData['teamIds']) as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const <String>[];
      final adminTeamIds = ((userData['adminTeamIds']) as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const <String>[];
      final joinedCount = teamIds.length - adminTeamIds.length;

      // 2. Join limiti kontrolü
      if (!TeamLimits.canJoin(
          isPro: widget.isPro,
          isDev: widget.isDeveloper,
          joinedCount: joinedCount)) {
        if (mounted) {
          setState(() {
            _error = TeamLimits.joinLimitMessage(
                isPro: widget.isPro, isDev: widget.isDeveloper);
            _isLoading = false;
          });
        }
        return;
      }

      // 3. Ekibi bul
      final snap = await db
          .collection('teams')
          .where('inviteCode', isEqualTo: code)
          .limit(1)
          .get();

      if (snap.docs.isEmpty) {
        if (mounted) {
          setState(() {
            _error = 'Geçersiz kod. Tekrar dene.';
            _isLoading = false;
          });
        }
        return;
      }

      if (!mounted) return;

      final teamDoc = snap.docs.first;
      final teamId = teamDoc.id;
      final teamData = teamDoc.data();
      final isPrivate = teamData['isPrivate'] as bool? ?? true;
      final genderPolicy = teamData['genderPolicy'] as String? ?? 'all';

      // 4. Zaten bu ekipte mi?
      if (teamIds.contains(teamId)) {
        if (mounted) {
          setState(() {
            _error = 'Zaten bu ekibin üyesisin.';
            _isLoading = false;
          });
        }
        return;
      }

      // 5. Cinsiyet politikası kontrolü — developer dahil herkes uymak zorunda
      if (genderPolicy != 'all') {
        final cinsiyet = userData['cinsiyet'] as String? ?? '';
        if (genderPolicy == 'men' && cinsiyet != 'bey') {
          if (mounted) setState(() { _error = 'Bu ekip yalnızca erkek üyelere açık.'; _isLoading = false; });
          return;
        }
        if (genderPolicy == 'women' && cinsiyet != 'hanim') {
          if (mounted) setState(() { _error = 'Bu ekip yalnızca hanım üyelere açık.'; _isLoading = false; });
          return;
        }
      }

      // 6a. Gizli ekip (developer dahil herkes) → istek gönder
      if (isPrivate) {
        final existingReq = await db
            .collection('teams')
            .doc(teamId)
            .collection('requests')
            .doc(widget.uid)
            .get();
        if (existingReq.exists) {
          if (mounted) {
            setState(() {
              _error = 'Bu ekibe zaten istek attın, lider inceliyor.';
              _isLoading = false;
            });
          }
          return;
        }

        await db
            .collection('teams')
            .doc(teamId)
            .collection('requests')
            .doc(widget.uid)
            .set({
          'name': userData['name'] as String? ?? 'İsimsiz',
          'username': userData['username'] as String? ?? '',
          'avatarSeed': userData['avatarSeed'] as String?,
          'city': userData['city'] as String? ?? '',
          'university': userData['university'] as String? ?? '',
          'cinsiyet': userData['cinsiyet'] as String? ?? '',
          'requestedAt': FieldValue.serverTimestamp(),
        });

        // pendingTeamIds'e ekle
        await db.collection('users').doc(widget.uid).update({
          'pendingTeamIds': FieldValue.arrayUnion([teamId]),
        });

        final adminUid = teamData['adminUid'] as String? ?? '';
        if (adminUid.isNotEmpty) {
          final requesterName = userData['name'] as String? ?? 'Biri';
          final teamName = teamData['name'] as String? ?? 'Ekip';
          await db
              .collection('users')
              .doc(adminUid)
              .collection('notifications')
              .add({
            'type': 'join_request',
            'title': 'Yeni katılım isteği',
            'body': '$requesterName "$teamName" ekibine katılmak istiyor.',
            'teamId': teamId,
            'requesterUid': widget.uid,
            'isRead': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }

        if (mounted) setState(() { _foundTeamId = teamId; _requestSent = true; _isLoading = false; });
        return;
      }

      // 6b. Açık ekip → direkt katıl
      final batch = db.batch();
      batch.update(db.collection('users').doc(widget.uid), {
        'teamIds': FieldValue.arrayUnion([teamId]),
        'teamJoinedAt.$teamId': FieldValue.serverTimestamp(),
      });
      batch.update(db.collection('teams').doc(teamId), {
        'memberCount': FieldValue.increment(1),
      });
      await batch.commit();

      if (!mounted) return;

      final cb = widget.onTeamFound;
      Navigator.pop(context);
      WidgetsBinding.instance.addPostFrameCallback((_) => cb(teamId));
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Bir hata oluştu. Tekrar dene.';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_requestSent) {
      return Padding(
        padding: EdgeInsets.fromLTRB(
            24, 24, 24, MediaQuery.of(context).padding.bottom + 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                  color: context.colors.tealSurface, shape: BoxShape.circle),
              child: const Icon(Icons.check_circle_outline,
                  size: 34, color: AppColors.teal),
            ),
            const SizedBox(height: 16),
            Text('İsteğin Gönderildi!',
                style: GoogleFonts.nunito(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: context.colors.textPrimary)),
            const SizedBox(height: 8),
            Text(
                'Ekip lideri isteğini inceleyecek.\nKabul edilirse bildirim alacaksın.',
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                    fontSize: 13, color: context.colors.textSecondary, height: 1.5)),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: DuolingoButton(
                color: AppColors.teal,
                bottomColor: AppColors.tealDark,
                onPressed: () {
                  final teamId = _foundTeamId;
                  Navigator.pop(context);
                  if (teamId != null) {
                    WidgetsBinding.instance.addPostFrameCallback(
                      (_) => widget.onTeamFound(teamId),
                    );
                  }
                },
                child: Text(
                  'Ekibi Görüntüle',
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
            'Davet Koduyla Katıl',
            style: GoogleFonts.nunito(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: context.colors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Lider tarafından verilen 6 haneli kodu gir.',
            style: GoogleFonts.nunito(fontSize: 13, color: context.colors.textSecondary),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _codeCtrl,
            textCapitalization: TextCapitalization.characters,
            maxLength: 6,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _isLoading ? null : _submit(),
            style: GoogleFonts.nunito(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: 10,
            ),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintText: 'XXXXXX',
              hintStyle: GoogleFonts.nunito(
                fontSize: 22,
                color: context.colors.border,
                letterSpacing: 10,
              ),
              counterText: '',
              errorText: _error,
              errorMaxLines: 3,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.teal, width: 2),
              ),
            ),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: DuolingoButton(
              color: AppColors.teal,
              bottomColor: AppColors.tealDark,
              isLoading: _isLoading,
              onPressed: _isLoading ? null : _submit,
              child: Text(
                'GRUBU BUL',
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

// ─── Görünürlük Toggle ────────────────────────────────────────────────────────

class _PrivacyToggle extends StatelessWidget {
  final bool? secili;
  final ValueChanged<bool> onChanged;

  const _PrivacyToggle({required this.secili, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isPublic = secili == false;
    final isPrivate = secili == true;

    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: context.colors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.border),
      ),
      padding: const EdgeInsets.all(4),
      child: Stack(
        children: [
          if (secili != null)
            AnimatedAlign(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeInOut,
              alignment:
                  isPublic ? Alignment.centerLeft : Alignment.centerRight,
              child: FractionallySizedBox(
                widthFactor: 0.5,
                child: Container(
                  decoration: BoxDecoration(
                    color: context.colors.surface,
                    borderRadius: BorderRadius.circular(9),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.10),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => onChanged(false),
                  behavior: HitTestBehavior.opaque,
                  child: Center(
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            isPublic ? FontWeight.w700 : FontWeight.w500,
                        color: isPublic
                            ? context.colors.textPrimary
                            : const Color(0xFF9E9E9E),
                      ),
                      child: const Text('🌐  Herkese Açık'),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => onChanged(true),
                  behavior: HitTestBehavior.opaque,
                  child: Center(
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            isPrivate ? FontWeight.w700 : FontWeight.w500,
                        color: isPrivate
                            ? context.colors.textPrimary
                            : const Color(0xFF9E9E9E),
                      ),
                      child: const Text('🔒  Sadece Davet'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Katılım Politikası Toggle (3 seçenek) ───────────────────────────────────

class _GenderPolicyToggle extends StatelessWidget {
  final String? secili;
  final String cinsiyet;
  final bool isPublic;
  final ValueChanged<String> onChanged;

  const _GenderPolicyToggle({
    required this.secili,
    required this.cinsiyet,
    required this.onChanged,
    this.isPublic = false,
  });

  @override
  Widget build(BuildContext context) {
    const all = [
      ('all', '👥  Herkese'),
      ('men', 'Sadece Beyler'),
      ('women', 'Sadece Hanımlar'),
    ];

    // Cinsiyet kısıtı + açık grup kısıtı
    final options = all.where((o) {
      if (cinsiyet == 'bey' && o.$1 == 'women') return false;
      if (cinsiyet == 'hanim' && o.$1 == 'men') return false;
      if (isPublic && o.$1 == 'all') return false; // açık ekip karışık olamaz
      return true;
    }).toList();

    final n = options.length;
    int? selectedIdx;
    for (int i = 0; i < n; i++) {
      if (options[i].$1 == secili) { selectedIdx = i; break; }
    }

    // Sliding indicator alignment: n seçenek için eşit aralıklı -1..1
    double alignX(int i) {
      if (n == 1) return 0;
      return -1 + (2 / (n - 1)) * i;
    }

    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: context.colors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.border),
      ),
      padding: const EdgeInsets.all(4),
      child: Stack(
        children: [
          if (selectedIdx != null)
            AnimatedAlign(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeInOut,
              alignment: Alignment(alignX(selectedIdx), 0),
              child: FractionallySizedBox(
                widthFactor: 1 / n,
                child: Container(
                  decoration: BoxDecoration(
                    color: context.colors.surface,
                    borderRadius: BorderRadius.circular(9),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.10),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Row(
            children: options.map((opt) {
              final isSelected = secili == opt.$1;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onChanged(opt.$1),
                  behavior: HitTestBehavior.opaque,
                  child: Center(
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? context.colors.textPrimary : const Color(0xFF9E9E9E),
                      ),
                      child: Text(opt.$2),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
