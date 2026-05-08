import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app_colors.dart';
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
      return '$startStr - $endStr ${startDt.year} Haftası';
    } else {
      return '$startStr ${startDt.year} - $endStr ${endDt.year} Haftası';
    }
  }

  Color _getRankColor(int rank) {
    switch (rank) {
      case 1:
        return const Color(0xFFFFC107); // Altın
      case 2:
        return const Color(0xFF9E9E9E); // Gümüş
      case 3:
        return const Color(0xFFCD7F32); // Bronz
      default:
        return AppColors.teal;
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
          // Eğer createdAt yoksa çok eski bir tarih (2020) varsayalım ki bir şeyleri gizlemesin
          final createdDate = createdAtTs?.toDate() ?? DateTime(2020, 1, 1);
          final teamCreatedAtDay = DateTime(createdDate.year, createdDate.month, createdDate.day);

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
                return Center(child: Text('Bir hata oluştu.', style: GoogleFonts.nunito()));
              }

              final allDocs = snapshot.data?.docs ?? [];
              
              // Ekranda sadece ekibin kurulduğu günden sonra biten haftaları göster
              var docs = allDocs.where((doc) {
                final parts = doc.id.split('-');
                if (parts.length == 3) {
                  final docDate = DateTime(int.tryParse(parts[0]) ?? 1970, int.tryParse(parts[1]) ?? 1, int.tryParse(parts[2]) ?? 1);
                  final docEndDate = docDate.add(const Duration(days: 6));
                  // Eğer haftanın bitiş tarihi, takımın kurulduğu günden sonra değilse (veya tam olarak Pazar günü açıldıysa) gizle
                  if (!docEndDate.isAfter(teamCreatedAtDay)) return false;
                }
                return true;
              }).toList();

              // Pro Yönetici değilse sadece en sonuncu 1 kaydı göster
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
                  final rankings = data['rankings'] as List<dynamic>? ?? [];

                  final dateStr = _formatDate(doc.id, teamCreatedAtDay);

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
                      title: Text(
                        dateStr,
                        style: GoogleFonts.nunito(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                        ),
                      ),
                      subtitle: Text(
                        '${rankings.length} üye',
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
                        if (rankings.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              'Bu gün hiç okuma yapılmamış.',
                              style: GoogleFonts.nunito(color: AppColors.textMid),
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: rankings.length,
                            separatorBuilder: (context, index) => const Divider(height: 1, indent: 64, endIndent: 16),
                            itemBuilder: (context, rIndex) {
                              final r = rankings[rIndex] as Map<String, dynamic>;
                              final rank = rIndex + 1;
                              final hasanat = r['periodHasanat'] as int? ?? 0;
                              final name = r['name'] as String? ?? 'İsimsiz';
                              final username = r['username'] as String? ?? '';
                              final uid = r['uid'] as String?;

                              return ListTile(
                                leading: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: _getRankColor(rank),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '$rank',
                                      style: GoogleFonts.nunito(
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ),
                                title: Text(
                                  name,
                                  style: GoogleFonts.nunito(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                subtitle: username.isNotEmpty
                                    ? Text(
                                        '@$username',
                                        style: GoogleFonts.nunito(
                                          fontSize: 12,
                                          color: AppColors.textLight,
                                        ),
                                      )
                                    : null,
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppColors.gold.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '$hasanat',
                                    style: GoogleFonts.nunito(
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.gold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                onTap: uid != null
                                    ? () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                              builder: (_) => KullaniciProfilScreen(uid: uid)),
                                        )
                                    : null,
                              );
                            },
                          ),
                      ],
                    ),
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
