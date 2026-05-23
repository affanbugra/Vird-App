import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app_colors.dart';
import 'ekip_profil_screen.dart';
import 'vird_screen.dart';

class BildirimlerScreen extends StatelessWidget {
  final String uid;
  const BildirimlerScreen({super.key, required this.uid});

  Future<void> _markAllRead(List<QueryDocumentSnapshot> unreadDocs) async {
    if (unreadDocs.isEmpty) return;
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in unreadDocs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('notifications')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snap) {
          final docs = snap.data?.docs ?? [];
          final unreadDocs = docs.where((d) {
            final data = d.data() as Map<String, dynamic>;
            return (data['isRead'] as bool?) == false;
          }).toList();
          final hasUnread = unreadDocs.isNotEmpty;

          return Scaffold(
            backgroundColor: AppColors.white,
            appBar: AppBar(
              backgroundColor: AppColors.white,
              elevation: 0,
              centerTitle: true,
              title: Text(
                'Bildirimler',
                style: GoogleFonts.nunito(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
                onPressed: () => Navigator.pop(context),
              ),
              actions: [
                if (hasUnread)
                  TextButton(
                    onPressed: () => _markAllRead(unreadDocs),
                    child: Text(
                      'Tümü okundu',
                      style: GoogleFonts.nunito(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.teal,
                      ),
                    ),
                  ),
              ],
            ),
            body: snap.connectionState == ConnectionState.waiting && docs.isEmpty
                ? const Center(child: CircularProgressIndicator(color: AppColors.teal))
                : docs.isEmpty
                    ? const _EmptyState()
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        itemCount: docs.length,
                        separatorBuilder: (_, __) => const Divider(
                          height: 1,
                          indent: 72,
                          endIndent: 16,
                        ),
                        itemBuilder: (context, i) {
                          final doc = docs[i];
                          return _NotificationTile(
                            doc: doc,
                            uid: uid,
                          );
                        },
                      ),
          );
        },
      ),
    );
  }
}

// ─── Boş durum ─────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.tealLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_outlined,
                size: 40,
                color: AppColors.teal,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Henüz bildirim yok',
              style: GoogleFonts.nunito(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ekip davetleri ve önemli duyurular burada görünecek.',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 13,
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

// ─── Bildirim satırı ────────────────────────────────────────────────────────────

class _NotificationTile extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  final String uid;
  const _NotificationTile({required this.doc, required this.uid});

  Map<String, dynamic> get _data => doc.data() as Map<String, dynamic>;

  IconData get _icon {
    switch (_data['type'] as String? ?? '') {
      case 'team_invite':
      case 'team_join':
        return Icons.group_outlined;
      case 'join_request':
        return Icons.person_add_outlined;
      case 'join_approved':
        return Icons.check_circle_outline;
      case 'join_rejected':
        return Icons.cancel_outlined;
      case 'streak_freeze':
        return Icons.shield_rounded;
      case 'announcement':
        return Icons.campaign_outlined;
      case 'message':
        return Icons.mail_outline;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color get _iconColor {
    switch (_data['type'] as String? ?? '') {
      case 'join_approved':
        return AppColors.successGreen;
      case 'join_rejected':
        return AppColors.errorRed;
      case 'streak_freeze':
        return const Color(0xFF3A9AC4);
      case 'announcement':
        return AppColors.orange;
      default:
        return AppColors.teal;
    }
  }

  String _timeAgo(Timestamp? ts) {
    if (ts == null) return '';
    final diff = DateTime.now().difference(ts.toDate());
    if (diff.inMinutes < 1) return 'Az önce';
    if (diff.inMinutes < 60) return '${diff.inMinutes} dk önce';
    if (diff.inHours < 24) return '${diff.inHours} sa önce';
    if (diff.inDays < 7) return '${diff.inDays} gün önce';
    final d = ts.toDate();
    const months = [
      '', 'Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz',
      'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara'
    ];
    return '${d.day} ${months[d.month]}';
  }

  Future<void> _markRead() async {
    final isRead = (_data['isRead'] as bool?) ?? true;
    if (isRead) return;
    await doc.reference.update({'isRead': true});
  }

  Future<void> _delete() async {
    await doc.reference.delete();
  }

  void _handleTap(BuildContext context) {
    _markRead();
    final type = _data['type'] as String? ?? '';
    final teamId = _data['teamId'] as String?;
    if (type == 'join_request' && teamId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EkipProfilScreen(
            teamId: teamId,
            currentUid: uid,
            isAdmin: true,
          ),
        ),
      );
    } else if (type == 'announcement') {
      showRoadmapSheet(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRead = (_data['isRead'] as bool?) ?? true;
    final title = _data['title'] as String? ?? '';
    final body = _data['body'] as String? ?? '';
    final ts = _data['createdAt'] as Timestamp?;
    final type = _data['type'] as String? ?? '';
    final isTappable = (type == 'join_request' && (_data['teamId'] as String?) != null) || type == 'announcement';

    return Dismissible(
      key: ValueKey(doc.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: AppColors.errorRed.withValues(alpha: 0.08),
        child: const Icon(Icons.delete_outline, color: AppColors.errorRed, size: 22),
      ),
      onDismissed: (_) => _delete(),
      child: GestureDetector(
        onTap: () => _handleTap(context),
        child: Container(
          color: isRead ? Colors.transparent : AppColors.tealLight.withValues(alpha: 0.35),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // İkon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _iconColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(_icon, size: 20, color: _iconColor),
              ),
              const SizedBox(width: 12),
              // İçerik
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: GoogleFonts.nunito(
                              fontSize: 14,
                              fontWeight: isRead ? FontWeight.w600 : FontWeight.w800,
                              color: AppColors.textDark,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _timeAgo(ts),
                          style: GoogleFonts.nunito(
                            fontSize: 11,
                            color: AppColors.textLight,
                          ),
                        ),
                      ],
                    ),
                    if (body.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        body,
                        style: GoogleFonts.nunito(
                          fontSize: 13,
                          color: AppColors.textMid,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Sağ taraf: okunmamış nokta veya chevron
              if (!isRead) ...[
                const SizedBox(width: 8),
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(top: 4),
                  decoration: const BoxDecoration(
                    color: AppColors.teal,
                    shape: BoxShape.circle,
                  ),
                ),
              ] else if (isTappable) ...[
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, size: 16, color: AppColors.textLight),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
