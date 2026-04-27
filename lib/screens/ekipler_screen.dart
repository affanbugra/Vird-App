import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../app_colors.dart';
import '../models/team_model.dart';
import '../widgets/duolingo_button.dart';
import 'ekip_profil_screen.dart';

class EkiplerScreen extends StatelessWidget {
  const EkiplerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Ekipler',
          style: GoogleFonts.nunito(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.textDark,
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

  void _showProDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _ProDialogSheet(),
    );
  }

  void _showCreateTeamSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _CreateTeamSheet(uid: uid),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, userSnap) {
        final userData = userSnap.data?.data() as Map<String, dynamic>?;
        final currentTeamId = userData?['teamId'] as String?;
        final isPro = (userData?['isPro'] as bool?) ?? false;

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('teams')
              .orderBy('memberCount', descending: true)
              .snapshots(),
          builder: (context, teamsSnap) {
            final teams = teamsSnap.data?.docs
                    .map((d) => TeamModel.fromFirestore(d))
                    .toList() ??
                [];

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
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          itemCount: teams.length,
                          itemBuilder: (context, i) {
                            final team = teams[i];
                            final isMyTeam = team.id == currentTeamId;
                            return _TeamCard(
                              team: team,
                              isMyTeam: isMyTeam,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => EkipProfilScreen(
                                    teamId: team.id,
                                    currentUid: uid,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    8,
                    16,
                    MediaQuery.of(context).padding.bottom + 16,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: DuolingoButton(
                      color: AppColors.teal,
                      bottomColor: AppColors.tealDark,
                      onPressed: () {
                        if (isPro) {
                          _showCreateTeamSheet(context);
                        } else {
                          _showProDialog(context);
                        }
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.add, color: Colors.white, size: 20),
                          const SizedBox(width: 6),
                          Text(
                            'YENİ EKİP KUR',
                            style: GoogleFonts.nunito(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
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
            Icon(Icons.shield_outlined, size: 64, color: AppColors.borderGrey),
            const SizedBox(height: 16),
            Text(
              'Henüz hiç ekip yok',
              style: GoogleFonts.nunito(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'İlk ekibi sen kur ve arkadaşlarını hayra davet et.',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 14,
                color: AppColors.textMid,
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
  final VoidCallback onTap;

  const _TeamCard({
    required this.team,
    required this.isMyTeam,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isMyTeam ? AppColors.tealLight : AppColors.white,
          border: Border.all(
            color: isMyTeam ? AppColors.teal : AppColors.borderGrey,
            width: isMyTeam ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isMyTeam
                    ? AppColors.teal.withValues(alpha: 0.15)
                    : AppColors.lightGrey,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.shield_outlined,
                color: isMyTeam ? AppColors.teal : AppColors.textMid,
                size: 24,
              ),
            ),
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
                            color: AppColors.textDark,
                          ),
                        ),
                      ),
                      if (isMyTeam)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.teal,
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
                        fontSize: 12,
                        color: AppColors.textMid,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.people_outline,
                          size: 13, color: AppColors.textLight),
                      const SizedBox(width: 3),
                      Text(
                        '${team.memberCount} üye',
                        style: GoogleFonts.nunito(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textLight,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textLight),
          ],
        ),
      ),
    );
  }
}

// ─── Pro Dialog ───────────────────────────────────────────────────────────────

class _ProDialogSheet extends StatelessWidget {
  const _ProDialogSheet();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 40,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: AppColors.borderGrey,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: AppColors.tealLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.workspace_premium,
                color: AppColors.teal, size: 36),
          ),
          const SizedBox(height: 16),
          Text(
            'Pro Özelliği',
            style: GoogleFonts.nunito(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Kendi ekibini kurmak için\nVird Pro gereklidir.',
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(
              fontSize: 15,
              color: AppColors.textMid,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Mevcut ekiplere ücretsiz katılabilirsin.',
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(
              fontSize: 13,
              color: AppColors.textLight,
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: DuolingoButton(
              color: AppColors.teal,
              bottomColor: AppColors.tealDark,
              onPressed: () => Navigator.pop(context),
              child: Text(
                'ANLADIM',
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

// ─── Yeni Ekip Oluştur Sheet ──────────────────────────────────────────────────

class _CreateTeamSheet extends StatefulWidget {
  final String uid;
  const _CreateTeamSheet({required this.uid});

  @override
  State<_CreateTeamSheet> createState() => _CreateTeamSheetState();
}

class _CreateTeamSheetState extends State<_CreateTeamSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final db = FirebaseFirestore.instance;
      final teamRef = db.collection('teams').doc();
      final batch = db.batch();

      batch.set(teamRef, {
        'name': _nameCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'penaltyNote': '',
        'adminUid': widget.uid,
        'memberCount': 1,
        'createdAt': Timestamp.now(),
      });

      batch.update(db.collection('users').doc(widget.uid), {
        'teamId': teamRef.id,
      });

      await batch.commit();
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
              'Yeni Ekip Kur',
              style: GoogleFonts.nunito(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                labelText: 'Ekip Adı',
                labelStyle: GoogleFonts.nunito(color: AppColors.textMid),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppColors.teal, width: 2),
                ),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Ekip adı zorunludur' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Açıklama (Opsiyonel)',
                labelStyle: GoogleFonts.nunito(color: AppColors.textMid),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppColors.teal, width: 2),
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
                onPressed: _isLoading ? null : _create,
                child: Text(
                  'EKİP OLUŞTUR',
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
}
