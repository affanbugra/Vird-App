import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import '../app_colors.dart';
import '../models/hatim_model.dart';
import '../widgets/log_entry_bottom_sheet.dart';

class HatimlerimScreen extends StatefulWidget {
  const HatimlerimScreen({super.key});

  @override
  State<HatimlerimScreen> createState() => _HatimlerimScreenState();
}

class _HatimlerimScreenState extends State<HatimlerimScreen> {
  final user = FirebaseAuth.instance.currentUser;

  Future<void> _showNewHatimBottomSheet(BuildContext context, List<Hatim> currentHatims) async {
    final hasArapca = currentHatims.any((h) => h.type == HatimType.arapca);
    final hasMeal = currentHatims.any((h) => h.type == HatimType.meal);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Yeni Hatim Başlat',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textDark),
              ),
              const SizedBox(height: 24),
              _buildHatimOption(
                context: context,
                title: 'Arapça Hatim',
                subtitle: 'Kuran-ı Kerim Arapça metninden hatim',
                icon: Icons.menu_book,
                isDisabled: hasArapca,
                type: HatimType.arapca,
              ),
              const SizedBox(height: 16),
              _buildHatimOption(
                context: context,
                title: 'Meal Hatimi',
                subtitle: 'Kendi anadilinde anlamıyla hatim',
                icon: Icons.translate,
                isDisabled: hasMeal,
                type: HatimType.meal,
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHatimOption({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isDisabled,
    required HatimType type,
  }) {
    return InkWell(
      onTap: isDisabled ? null : () => _createNewHatim(context, type),
      borderRadius: BorderRadius.circular(16),
      child: Opacity(
        opacity: isDisabled ? 0.5 : 1.0,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: isDisabled ? Colors.grey.shade300 : AppColors.teal, width: 2),
            borderRadius: BorderRadius.circular(16),
            color: isDisabled ? Colors.grey.shade100 : AppColors.tealLight.withValues(alpha: 0.3),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDisabled ? Colors.grey.shade300 : AppColors.teal,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(subtitle, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                    if (isDisabled)
                      const Text('Zaten devam eden bir hatiminiz var', style: TextStyle(color: AppColors.errorRed, fontSize: 10, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createNewHatim(BuildContext context, HatimType type) async {
    if (user == null) return;
    
    final newHatim = Hatim(
      id: '',
      type: type,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('hatims')
        .add(newHatim.toMap());

    if (context.mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) return const Center(child: Text('Giriş yapınız'));

    return SafeArea(
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .collection('hatims')
            .orderBy('updatedAt', descending: true)
            .snapshots(),
        builder: (context, hatimSnapshot) {
          if (hatimSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.teal));
          }

          final hatims = hatimSnapshot.data?.docs.map((doc) => Hatim.fromFirestore(doc)).toList() ?? [];

          return Scaffold(
            floatingActionButton: hatims.length >= 2
                ? null
                : FloatingActionButton.extended(
                    onPressed: () => _showNewHatimBottomSheet(context, hatims),
                    backgroundColor: AppColors.teal,
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: const Text('Yeni Hatim', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
            body: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Hatimlerim',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      IconButton(
                        onPressed: () => LogEntryBottomSheet.show(context),
                        icon: const Icon(Icons.post_add, color: AppColors.teal),
                        tooltip: 'Serbest Okuma Ekle',
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildSummaryCards(),
                  const SizedBox(height: 32),
                  const Text(
                    'Aktif Hatimler',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textMid),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: hatims.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.menu_book, size: 64, color: Colors.grey.shade300),
                                const SizedBox(height: 16),
                                Text('Henüz aktif bir hatiminiz yok.', style: TextStyle(color: Colors.grey.shade500)),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: hatims.length,
                            itemBuilder: (context, index) {
                              final hatim = hatims[index];
                              return _buildHatimCard(hatim);
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryCards() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user!.uid).snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() as Map<String, dynamic>?;
        final currentStreak = data?['seri'] ?? 0;
        final totalHasanat = data?['hasanat'] ?? 0;

        return Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.orange.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.local_fire_department, color: AppColors.orange, size: 32),
                    const SizedBox(height: 8),
                    Text('$currentStreak Gün', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.orange)),
                    const Text('Mevcut Seri', style: TextStyle(fontSize: 12, color: AppColors.textMid)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.stars, color: Colors.amber, size: 32),
                    const SizedBox(height: 8),
                    Text('$totalHasanat', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.amber)),
                    const Text('Toplam Hasanat', style: TextStyle(fontSize: 12, color: AppColors.textMid)),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHatimCard(Hatim hatim) {
    final isArapca = hatim.type == HatimType.arapca;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppColors.tealLight, borderRadius: BorderRadius.circular(12)),
                  child: Icon(isArapca ? Icons.menu_book : Icons.translate, color: AppColors.teal),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(isArapca ? 'Arapça Hatim' : 'Meal Hatimi', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('Sayfa ${hatim.currentPage} / ${hatim.totalPages}', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                    ],
                  ),
                ),
                Text(
                  '%${(hatim.progressPercentage * 100).toStringAsFixed(1)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.teal, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: hatim.progressPercentage,
                minHeight: 8,
                backgroundColor: Colors.grey.shade200,
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.teal),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => LogEntryBottomSheet.show(context, initialHatim: hatim),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.teal,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('Okumaya Devam Et', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
