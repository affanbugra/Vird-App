import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app_colors.dart';

class BildirimlerScreen extends StatefulWidget {
  final String uid;
  const BildirimlerScreen({super.key, required this.uid});

  @override
  State<BildirimlerScreen> createState() => _BildirimlerScreenState();
}

class _BildirimlerScreenState extends State<BildirimlerScreen> {
  @override
  void initState() {
    super.initState();
    _markAllRead();
  }

  Future<void> _markAllRead() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .collection('notifications')
          .where('isRead', isEqualTo: false)
          .get();
      if (snap.docs.isEmpty) return;
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in snap.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
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
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(widget.uid)
            .collection('notifications')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.teal),
            );
          }

          final docs = snap.data?.docs ?? [];

          if (docs.isEmpty) {
            return _EmptyState();
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 12),
            itemCount: docs.length,
            separatorBuilder: (context, index) => const Divider(
              height: 1,
              indent: 72,
              endIndent: 16,
            ),
            itemBuilder: (context, i) {
              final data = docs[i].data() as Map<String, dynamic>;
              return _NotificationTile(data: data);
            },
          );
        },
      ),
    );
  }
}

// ─── Boş durum ────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
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
              'Ekip davetleri, mesajlar ve önemli duyurular burada görünecek.',
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

// ─── Bildirim satırı ──────────────────────────────────────────────────────────

class _NotificationTile extends StatelessWidget {
  final Map<String, dynamic> data;
  const _NotificationTile({required this.data});

  IconData get _icon {
    switch (data['type'] as String? ?? '') {
      case 'team_invite':
      case 'team_join':
        return Icons.group_outlined;
      case 'join_request':
        return Icons.person_add_outlined;
      case 'join_approved':
        return Icons.check_circle_outline;
      case 'join_rejected':
        return Icons.cancel_outlined;
      case 'message':
        return Icons.mail_outline;
      default:
        return Icons.notifications_outlined;
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

  @override
  Widget build(BuildContext context) {
    final isRead = (data['isRead'] as bool?) ?? true;
    final title = data['title'] as String? ?? '';
    final body = data['body'] as String? ?? '';
    final ts = data['createdAt'] as Timestamp?;

    return Container(
      color: isRead ? Colors.transparent : AppColors.tealLight.withValues(alpha: 0.4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.tealLight,
              shape: BoxShape.circle,
            ),
            child: Icon(_icon, size: 20, color: AppColors.teal),
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
                        title,
                        style: GoogleFonts.nunito(
                          fontSize: 14,
                          fontWeight:
                              isRead ? FontWeight.w600 : FontWeight.w800,
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
          ],
        ],
      ),
    );
  }
}
