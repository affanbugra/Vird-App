import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import '../app_colors.dart';
import '../models/hatim_model.dart';
import '../widgets/hatim_heat_map_sheet.dart';
import '../utils/hatim_remover.dart';

class TamamlananHatimlerScreen extends StatefulWidget {
  const TamamlananHatimlerScreen({super.key});

  @override
  State<TamamlananHatimlerScreen> createState() => _TamamlananHatimlerScreenState();
}

class _TamamlananHatimlerScreenState extends State<TamamlananHatimlerScreen> {
  final user = FirebaseAuth.instance.currentUser;
  final Set<String> _deletingIds = {};

  Future<void> _deleteHatim(Hatim hatim) async {
    if (user == null) return;
    setState(() => _deletingIds.add(hatim.id));
    try {
      await HatimRemover.deleteHatim(user!.uid, hatim);
    } catch (_) {
      if (mounted) setState(() => _deletingIds.remove(hatim.id));
    }
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '';
    return '${dt.day}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) return const Scaffold(body: Center(child: Text('Giriş yapınız')));

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Tamamlanan Hatimler',
          style: GoogleFonts.nunito(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.textDark,
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .collection('hatims')
            .where('isCompleted', isEqualTo: true)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.teal));
          }

          final hatims = (snap.data?.docs
                  .map((d) => Hatim.fromFirestore(d))
                  .where((h) => !_deletingIds.contains(h.id))
                  .toList() ??
              [])
            ..sort((a, b) => (b.completedAt ?? b.updatedAt).compareTo(a.completedAt ?? a.updatedAt));

          if (hatims.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.emoji_events_outlined, size: 64, color: AppColors.borderGrey),
                  const SizedBox(height: 16),
                  Text(
                    'Henüz tamamlanan hatim yok.',
                    style: GoogleFonts.nunito(
                      fontSize: 15,
                      color: AppColors.textMid,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '604 sayfayı okuyunca hatim tamamlanır.',
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      color: AppColors.textLight,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: hatims.length,
            itemBuilder: (context, i) {
              final hatim = hatims[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Dismissible(
                  key: ValueKey(hatim.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    decoration: BoxDecoration(
                      color: AppColors.errorRed,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(Icons.delete_outline, color: Colors.white, size: 26),
                  ),
                  confirmDismiss: (_) async {
                    return await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        title: Text('Hatimi sil',
                            style: GoogleFonts.nunito(fontWeight: FontWeight.bold)),
                        content: Text(
                          '"${hatim.displayName}" ve tüm okuma kayıtları silinecek.\nHasanat puanı ve okunan sayfalar geri alınır.',
                          style: GoogleFonts.nunito(color: AppColors.textMid),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: Text('İptal',
                                style: GoogleFonts.nunito(color: AppColors.textMid)),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.errorRed,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () => Navigator.pop(ctx, true),
                            child: Text('Sil',
                                style: GoogleFonts.nunito(
                                    color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ) ??
                        false;
                  },
                  onDismissed: (_) => _deleteHatim(hatim),
                  child: GestureDetector(
                    onTap: () => HatimHeatMapSheet.show(
                      context,
                      hatim: hatim,
                      uid: user!.uid,
                    ),
                    child: _CompletedHatimCard(
                      hatim: hatim,
                      completedDate: _formatDate(hatim.completedAt),
                      onHeatMap: () => HatimHeatMapSheet.show(
                        context,
                        hatim: hatim,
                        uid: user!.uid,
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _CompletedHatimCard extends StatelessWidget {
  final Hatim hatim;
  final String completedDate;
  final VoidCallback onHeatMap;

  const _CompletedHatimCard({
    required this.hatim,
    required this.completedDate,
    required this.onHeatMap,
  });

  @override
  Widget build(BuildContext context) {
    final isArapca = hatim.type == HatimType.arapca;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF38A474).withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF38A474).withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: const Color(0xFF38A474).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isArapca ? Icons.menu_book : Icons.translate,
              color: const Color(0xFF38A474),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hatim.displayName,
                  style: GoogleFonts.nunito(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: AppColors.textDark,
                  ),
                ),
                Text(
                  '604/604 sayfa${completedDate.isNotEmpty ? ' · $completedDate' : ''}',
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    color: AppColors.textMid,
                  ),
                ),
              ],
            ),
          ),
          // Tamamlandı badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF38A474).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'TAMAM',
              style: GoogleFonts.nunito(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF38A474),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Harita butonu
          GestureDetector(
            onTap: onHeatMap,
            child: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppColors.tealLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.grid_view_rounded, size: 16, color: AppColors.teal),
            ),
          ),
        ],
      ),
    );
  }
}
