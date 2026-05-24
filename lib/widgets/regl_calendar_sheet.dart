import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../app_colors.dart';

class ReglCalendarSheet extends StatefulWidget {
  const ReglCalendarSheet({super.key});

  @override
  State<ReglCalendarSheet> createState() => _ReglCalendarSheetState();
}

class _ReglCalendarSheetState extends State<ReglCalendarSheet> {
  final Set<String> _reglDates = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchReglDates();
  }

  Future<void> _fetchReglDates() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      // Sadece prayer loglarını al
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('logs')
          .where('type', isEqualTo: 'prayer')
          .get();

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final dateStr = (data['date'] as String).replaceAll('prayer_', ''); // YYYY-MM-DD
        final prayers = data['prayers'] as Map<String, dynamic>? ?? {};
        
        // Eğer herhangi bir vakit regl ise, o günü işaretle
        bool isRegl = prayers.values.any((status) => status == 'regl');
        if (isRegl) {
          _reglDates.add(dateStr);
        }
      }
    } catch (e) {
      debugPrint("Error fetching regl dates: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _getMonthName(int month) {
    const months = ['', 'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', 'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'];
    return months[month];
  }

  @override
  Widget build(BuildContext context) {
    // Son 12 ayı gösterecek bir liste oluşturalım
    final now = DateTime.now();
    final monthsToShow = List.generate(12, (i) {
      int y = now.year;
      int m = now.month - i;
      while (m <= 0) {
        m += 12;
        y -= 1;
      }
      return DateTime(y, m, 1);
    });

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      decoration: const BoxDecoration(
        color: AppColors.lightGrey,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Muafiyet Takvimi',
                style: GoogleFonts.nunito(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: AppColors.textMid),
                onPressed: () => Navigator.pop(context),
              )
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.pink))
                : GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 0.8,
                    ),
                    itemCount: monthsToShow.length,
                    itemBuilder: (context, index) {
                      final monthDate = monthsToShow[index];
                      return _buildMonthCalendar(monthDate);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthCalendar(DateTime monthDate) {
    final daysInMonth = DateTime(monthDate.year, monthDate.month + 1, 0).day;
    final firstDayWeekday = DateTime(monthDate.year, monthDate.month, 1).weekday;
    
    // Grid için gerekli boş hücreler (Pazartesi=1 olduğu için)
    final emptyCellsBefore = firstDayWeekday - 1;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderGrey),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_getMonthName(monthDate.month)} ${monthDate.year}',
            style: GoogleFonts.nunito(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 4),
          // Gün İsimleri
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: const ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'].map((day) {
              return Expanded(
                child: Center(
                  child: Text(
                    day,
                    style: TextStyle(fontSize: 8, fontWeight: FontWeight.w600, color: AppColors.textMid),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 2),
          // Takvim Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 2,
              crossAxisSpacing: 0,
              childAspectRatio: 1.0,
            ),
            itemCount: emptyCellsBefore + daysInMonth,
            itemBuilder: (context, index) {
              if (index < emptyCellsBefore) {
                return const SizedBox();
              }
              final day = index - emptyCellsBefore + 1;
              final dateStr = '${monthDate.year}-${monthDate.month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
              
              final isRegl = _reglDates.contains(dateStr);
              
              return Center(
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: isRegl ? Colors.pink.shade50 : Colors.transparent,
                    border: isRegl ? Border.all(color: Colors.pink.shade200) : null,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '$day',
                      style: GoogleFonts.nunito(
                        fontSize: 8,
                        fontWeight: isRegl ? FontWeight.w800 : FontWeight.w600,
                        color: isRegl ? Colors.pink.shade400 : AppColors.textDark,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
