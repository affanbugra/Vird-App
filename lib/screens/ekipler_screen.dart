import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../app_colors.dart';
import '../app_assets.dart';
import '../models/team_model.dart';
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

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, userSnap) {
        final userData = userSnap.data?.data() as Map<String, dynamic>?;
        final currentTeamId = userData?['teamId'] as String?;

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

            if (teams.isEmpty) return const _EmptyState();

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
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
              'Ekipler yakında burada görünecek.',
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

  Widget _buildLogo() {
    if (team.logoAsset == 'rical_i_fark') {
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
    return Container(
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
          color: isMyTeam ? AppColors.tealLight : AppColors.white,
          border: Border.all(
            color: isMyTeam ? AppColors.teal : AppColors.borderGrey,
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
