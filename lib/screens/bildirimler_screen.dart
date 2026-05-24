import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app_colors.dart';
import 'ekip_profil_screen.dart';
import 'vird_screen.dart';

class BildirimlerScreen extends StatefulWidget {
  final String uid;
  const BildirimlerScreen({super.key, required this.uid});

  @override
  State<BildirimlerScreen> createState() => _BildirimlerScreenState();
}

class _BildirimlerScreenState extends State<BildirimlerScreen> {
  bool _isSelectionMode = false;
  final Set<String> _selectedDocIds = {};

  Future<void> _markAllRead(List<QueryDocumentSnapshot> unreadDocs) async {
    if (unreadDocs.isEmpty) return;
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in unreadDocs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  Future<void> _deleteSelected() async {
    if (_selectedDocIds.isEmpty) return;
    
    // Premium onay diyaloğu göster
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Bildirimleri Sil',
          style: GoogleFonts.nunito(
            fontWeight: FontWeight.w800,
            color: AppColors.textDark,
          ),
        ),
        content: Text(
          'Seçili ${_selectedDocIds.length} bildirimi silmek istediğinize emin misiniz?',
          style: GoogleFonts.nunito(
            fontSize: 15,
            color: AppColors.textMid,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Vazgeç',
              style: GoogleFonts.nunito(
                fontWeight: FontWeight.w700,
                color: AppColors.textMid,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.errorRed,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Sil',
              style: GoogleFonts.nunito(
                fontWeight: FontWeight.w700,
                color: AppColors.white,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final batch = FirebaseFirestore.instance.batch();
    for (final id in _selectedDocIds) {
      final ref = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .collection('notifications')
          .doc(id);
      batch.delete(ref);
    }
    await batch.commit();

    setState(() {
      _selectedDocIds.clear();
      _isSelectionMode = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(widget.uid)
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
              centerTitle: _isSelectionMode ? false : true,
              leading: _isSelectionMode
                  ? IconButton(
                      icon: const Icon(Icons.close, color: AppColors.textDark),
                      onPressed: () {
                        setState(() {
                          _isSelectionMode = false;
                          _selectedDocIds.clear();
                        });
                      },
                    )
                  : IconButton(
                      icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
                      onPressed: () => Navigator.pop(context),
                    ),
              title: Text(
                _isSelectionMode ? '${_selectedDocIds.length} bildirim seçildi' : 'Bildirimler',
                style: GoogleFonts.nunito(
                  fontSize: _isSelectionMode ? 16 : 20,
                  fontWeight: _isSelectionMode ? FontWeight.w600 : FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
              actions: [
                if (!_isSelectionMode) ...[
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
                  if (docs.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: AppColors.textDark),
                      onPressed: () {
                        setState(() {
                          _isSelectionMode = true;
                        });
                      },
                    ),
                ] else ...[
                  TextButton(
                    onPressed: () {
                      setState(() {
                        if (_selectedDocIds.length == docs.length) {
                          _selectedDocIds.clear();
                        } else {
                          _selectedDocIds.addAll(docs.map((d) => d.id));
                        }
                      });
                    },
                    child: Text(
                      _selectedDocIds.length == docs.length ? 'Seçimi Kaldır' : 'Tümünü Seç',
                      style: GoogleFonts.nunito(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.teal,
                      ),
                    ),
                  ),
                  if (_selectedDocIds.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.delete, color: AppColors.errorRed),
                      onPressed: _deleteSelected,
                    ),
                ],
              ],
            ),
            body: snap.connectionState == ConnectionState.waiting && docs.isEmpty
                ? const Center(child: CircularProgressIndicator(color: AppColors.teal))
                : docs.isEmpty
                    ? const _EmptyState()
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        itemCount: docs.length,
                        separatorBuilder: (_, index) => const Divider(
                          height: 1,
                          indent: 72,
                          endIndent: 16,
                        ),
                        itemBuilder: (context, i) {
                          final doc = docs[i];
                          final isSelected = _selectedDocIds.contains(doc.id);
                          return _NotificationTile(
                            doc: doc,
                            uid: widget.uid,
                            isSelectionMode: _isSelectionMode,
                            isSelected: isSelected,
                            onTap: () {
                              if (_isSelectionMode) {
                                setState(() {
                                  if (isSelected) {
                                    _selectedDocIds.remove(doc.id);
                                  } else {
                                    _selectedDocIds.add(doc.id);
                                  }
                                });
                              }
                            },
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
              decoration: const BoxDecoration(
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
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback onTap;

  const _NotificationTile({
    required this.doc,
    required this.uid,
    required this.isSelectionMode,
    required this.isSelected,
    required this.onTap,
  });

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

  Widget _buildNotificationBody(String body, String type) {
    if (body.isEmpty) return const SizedBox.shrink();

    final normalStyle = GoogleFonts.nunito(
      fontSize: 13,
      color: AppColors.textMid,
      height: 1.4,
    );

    final boldStyle = GoogleFonts.nunito(
      fontSize: 13,
      fontWeight: FontWeight.w800,
      color: AppColors.textDark,
      height: 1.4,
    );

    // 1. Durum: join_approved (örn: "Ekip Adı ekibine katıldın.")
    if (type == 'join_approved') {
      const suffix = ' ekibine katıldın.';
      if (body.endsWith(suffix)) {
        final teamName = body.substring(0, body.length - suffix.length);
        return Text.rich(
          TextSpan(
            children: [
              TextSpan(text: '"$teamName"', style: boldStyle),
              TextSpan(text: suffix, style: normalStyle),
            ],
          ),
        );
      }
    }

    // 2. Durum: join_rejected (örn: "Ekip Adı ekibine katılma isteğin onaylanmadı.")
    if (type == 'join_rejected') {
      const suffix = ' ekibine katılma isteğin onaylanmadı.';
      if (body.endsWith(suffix)) {
        final teamName = body.substring(0, body.length - suffix.length);
        return Text.rich(
          TextSpan(
            children: [
              TextSpan(text: '"$teamName"', style: boldStyle),
              TextSpan(text: suffix, style: normalStyle),
            ],
          ),
        );
      }
    }

    // 3. Durum: Çift tırnak içeren metinler (örn: Ahmet "Ekip Adı" ekibine katılmak istiyor.)
    if (body.contains('"')) {
      final parts = body.split('"');
      final spans = <TextSpan>[];
      for (int i = 0; i < parts.length; i++) {
        if (i % 2 == 1) {
          // Tırnak içi (bold + tırnaklar)
          spans.add(TextSpan(text: '"${parts[i]}"', style: boldStyle));
        } else {
          // Normal metin
          spans.add(TextSpan(text: parts[i], style: normalStyle));
        }
      }
      return Text.rich(TextSpan(children: spans));
    }

    // Varsayılan: Normal metin
    return Text(body, style: normalStyle);
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
      direction: isSelectionMode ? DismissDirection.none : DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: AppColors.errorRed.withValues(alpha: 0.08),
        child: const Icon(Icons.delete_outline, color: AppColors.errorRed, size: 22),
      ),
      onDismissed: (_) => _delete(),
      child: GestureDetector(
        onTap: isSelectionMode ? onTap : () => _handleTap(context),
        child: Container(
          color: isRead ? Colors.transparent : AppColors.tealLight.withValues(alpha: 0.35),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Seçim Kutusu (Checkbox)
              if (isSelectionMode) ...[
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.only(right: 12, top: 9),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? AppColors.teal : AppColors.textLight,
                      width: 2,
                    ),
                    color: isSelected ? AppColors.teal : Colors.transparent,
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, size: 14, color: AppColors.white)
                      : null,
                ),
              ],
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
                      _buildNotificationBody(body, type),
                    ],
                  ],
                ),
              ),
              // Sağ taraf: okunmamış nokta veya chevron
              if (!isSelectionMode) ...[
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
            ],
          ),
        ),
      ),
    );
  }
}
