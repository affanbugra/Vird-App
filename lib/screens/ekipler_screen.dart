import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../app_colors.dart';
import '../app_assets.dart';
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

  void _openCreateSheet(BuildContext context, bool isPro, bool isDeveloper, String? currentTeamId) {
    if (!isPro && !isDeveloper) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Pro Özellik',
            style: GoogleFonts.nunito(fontWeight: FontWeight.w800, color: AppColors.textDark),
          ),
          content: Text(
            'Ekip kurma özelliği Pro kullanıcılara özeldir.',
            style: GoogleFonts.nunito(color: AppColors.textMid),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Tamam',
                  style: GoogleFonts.nunito(color: AppColors.teal, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
      return;
    }
    if (!isDeveloper && currentTeamId != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Zaten bir ekiptesin.', style: GoogleFonts.nunito()),
        backgroundColor: AppColors.teal,
      ));
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
        onCreated: (teamId) => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => EkipProfilScreen(teamId: teamId, currentUid: uid)),
        ),
      ),
    );
  }

  void _openInviteCodeSheet(BuildContext context, String? currentTeamId, bool isDeveloper) {
    if (!isDeveloper && currentTeamId != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          'Zaten bir ekiptesin. Önce mevcut ekibinden ayrılmalısın.',
          style: GoogleFonts.nunito(),
        ),
        backgroundColor: AppColors.teal,
      ));
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _InviteCodeSheet(
        uid: uid,
        isDeveloper: isDeveloper,
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
        final currentTeamId = userData?['teamId'] as String?;
        final isPro = (userData?['isPro'] as bool?) ?? false;
        final isDeveloper = (userData?['isDeveloper'] as bool?) ?? false;
        final devTeamIds = ((userData?['developerTeamIds']) as List?)
                ?.map((e) => e.toString())
                .toList() ??
            const <String>[];

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
            // Gizli grupları filtrele: sadece kendi grubu görünsün
            final teams =
                allTeams.where((t) => !t.isPrivate || t.id == currentTeamId || devTeamIds.contains(t.id)).toList();

            if (teamsSnap.connectionState == ConnectionState.waiting && teams.isEmpty) {
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
                            final isMyTeam = team.id == currentTeamId ||
                                devTeamIds.contains(team.id);
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

                // ── Alt aksiyon çubuğu ──────────────────────────────────────
                Container(
                  decoration: const BoxDecoration(
                    color: AppColors.white,
                    border: Border(top: BorderSide(color: AppColors.borderGrey)),
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
                                  _openInviteCodeSheet(context, currentTeamId, isDeveloper),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppColors.teal),
                                padding: const EdgeInsets.symmetric(vertical: 14),
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
                              onPressed: () =>
                                  _openCreateSheet(context, isPro, isDeveloper, currentTeamId),
                              child: Text(
                                'Yeni Grup Kur',
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
            const Icon(Icons.shield_outlined, size: 64, color: AppColors.borderGrey),
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
              'İlk ekibi sen kur.',
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
                      if (team.isPrivate && !isMyTeam)
                        const Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Icon(Icons.lock_outline,
                              size: 14, color: AppColors.textLight),
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
                          fontSize: 12, color: AppColors.textMid),
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

// ─── Yeni Grup Kur Sheet ──────────────────────────────────────────────────────

class _CreateTeamSheet extends StatefulWidget {
  final String uid;
  final bool isDeveloper;
  final void Function(String teamId) onCreated;

  const _CreateTeamSheet({
    required this.uid,
    required this.isDeveloper,
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

  Future<void> _create() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Grup adı gerekli.', style: GoogleFonts.nunito()),
        backgroundColor: AppColors.errorRed,
      ));
      return;
    }
    if (_isPrivate == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Grubun görünürlüğünü seçin.', style: GoogleFonts.nunito()),
        backgroundColor: AppColors.errorRed,
      ));
      return;
    }
    if (_genderPolicy == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Katılım politikasını seçin.', style: GoogleFonts.nunito()),
        backgroundColor: AppColors.errorRed,
      ));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final db = FirebaseFirestore.instance;

      if (!widget.isDeveloper) {
        final userDoc = await db.collection('users').doc(widget.uid).get();
        if ((userDoc.data() ?? {})['teamId'] != null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Zaten bir ekipteysin.', style: GoogleFonts.nunito()),
              backgroundColor: AppColors.errorRed,
            ));
          }
          return;
        }
      }

      final inviteCode = _generateInviteCode();
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
      if (widget.isDeveloper) {
        batch.update(db.collection('users').doc(widget.uid), {
          'developerTeamIds': FieldValue.arrayUnion([teamRef.id]),
        });
      } else {
        batch.update(db.collection('users').doc(widget.uid), {
          'teamId': teamRef.id,
          'teamJoinedAt': FieldValue.serverTimestamp(),
        });
      }
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
                color: AppColors.borderGrey,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            'Yeni Grup Kur',
            style: GoogleFonts.nunito(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _nameCtrl,
            textInputAction: TextInputAction.next,
            maxLength: 50,
            decoration: InputDecoration(
              labelText: 'Grup Adı *',
              labelStyle: GoogleFonts.nunito(color: AppColors.textMid),
              counterText: '',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
              labelStyle: GoogleFonts.nunito(color: AppColors.textMid),
              counterText: '',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.teal, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // ── Görünürlük ───────────────────────────────────────────────
          Text(
            'Görünürlük',
            style: GoogleFonts.nunito(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textMid,
            ),
          ),
          const SizedBox(height: 8),
          _PrivacyToggle(
            secili: _isPrivate,
            onChanged: (v) => setState(() => _isPrivate = v),
          ),
          const SizedBox(height: 20),
          // ── Katılım politikası ───────────────────────────────────────
          Text(
            'Katılım Politikası',
            style: GoogleFonts.nunito(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textMid,
            ),
          ),
          const SizedBox(height: 8),
          _GenderPolicyToggle(
            secili: _genderPolicy,
            onChanged: (v) => setState(() => _genderPolicy = v),
          ),
          const SizedBox(height: 10),
          // ── Uyarı notu ───────────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline, size: 11, color: Color(0xFFBBAB00)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Bu ayarlar bir kez belirlenir ve sonradan değiştirilemez. Dikkatle seçin.',
                  style: GoogleFonts.nunito(
                    fontSize: 10,
                    color: const Color(0xFFAA9000),
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
  final void Function(String teamId) onTeamFound;

  const _InviteCodeSheet({required this.uid, required this.isDeveloper, required this.onTeamFound});

  @override
  State<_InviteCodeSheet> createState() => _InviteCodeSheetState();
}

class _InviteCodeSheetState extends State<_InviteCodeSheet> {
  final _codeCtrl = TextEditingController();
  bool _isLoading = false;
  String? _error;

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

      // 1. Önce kullanıcının zaten bir ekipte olup olmadığını kontrol et
      final userDoc = await db.collection('users').doc(widget.uid).get();
      final userData = userDoc.data() ?? {};
      if (!widget.isDeveloper && userData['teamId'] != null) {
        if (mounted) {
          setState(() { _error = 'Zaten bir ekiptesin. Önce mevcut ekibinden ayrıl.'; _isLoading = false; });
        }
        return;
      }

      // 2. Davet koduyla ekibi bul
      final snap = await db
          .collection('teams')
          .where('inviteCode', isEqualTo: code)
          .limit(1)
          .get();

      if (snap.docs.isEmpty) {
        if (mounted) setState(() { _error = 'Geçersiz kod. Tekrar dene.'; _isLoading = false; });
        return;
      }

      if (!mounted) return;

      final teamId = snap.docs.first.id;

      // 3. Kullanıcıyı ekibe kat (teamId güncelle + memberCount artır)
      final batch = db.batch();
      if (widget.isDeveloper) {
        batch.update(db.collection('users').doc(widget.uid), {
          'developerTeamIds': FieldValue.arrayUnion([teamId]),
        });
      } else {
        batch.update(db.collection('users').doc(widget.uid), {
          'teamId': teamId,
          'teamJoinedAt': FieldValue.serverTimestamp(),
        });
      }
      batch.update(db.collection('teams').doc(teamId), {
        'memberCount': FieldValue.increment(1),
      });
      await batch.commit();

      if (!mounted) return;

      final cb = widget.onTeamFound;

      // Pop sheet önce, sonraki frame'de push yap — aynı frame'de pop+push → navigator crash
      Navigator.pop(context);
      WidgetsBinding.instance.addPostFrameCallback((_) => cb(teamId));

    } catch (e) {
      if (mounted) setState(() { _error = 'Bir hata oluştu. Tekrar dene.'; _isLoading = false; });
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
            'Davet Koduyla Katıl',
            style: GoogleFonts.nunito(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Lider tarafından verilen 6 haneli kodu gir.',
            style: GoogleFonts.nunito(fontSize: 13, color: AppColors.textMid),
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
                color: AppColors.borderGrey,
                letterSpacing: 10,
              ),
              counterText: '',
              errorText: _error,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
        color: const Color(0xFFF0F0F0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderGrey),
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
                    color: Colors.white,
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
                            ? AppColors.textDark
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
                            ? AppColors.textDark
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
  final ValueChanged<String> onChanged;

  const _GenderPolicyToggle({required this.secili, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const options = [
      ('all', '👥  Herkese'),
      ('men', '👨  Sadece Beyler'),
      ('women', '👩  Sadece Hanımlar'),
    ];

    int? selectedIdx;
    for (int i = 0; i < options.length; i++) {
      if (options[i].$1 == secili) {
        selectedIdx = i;
        break;
      }
    }

    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: const Color(0xFFF0F0F0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderGrey),
      ),
      padding: const EdgeInsets.all(4),
      child: Stack(
        children: [
          if (selectedIdx != null)
            AnimatedAlign(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeInOut,
              alignment: Alignment(
                  selectedIdx == 0 ? -1 : selectedIdx == 1 ? 0 : 1, 0),
              child: FractionallySizedBox(
                widthFactor: 1 / 3,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
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
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected
                            ? AppColors.textDark
                            : const Color(0xFF9E9E9E),
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
