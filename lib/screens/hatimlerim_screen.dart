import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import '../app_colors.dart';
import '../models/hatim_model.dart';
import '../data/quran_cuz.dart';
import '../widgets/log_entry_bottom_sheet.dart';
import '../widgets/hatim_heat_map_sheet.dart';
import 'tamamlanan_hatimler_screen.dart';

const int _arapcaLimit = 3;
const int _mealLimit = 1;

class HatimlerimScreen extends StatefulWidget {
  const HatimlerimScreen({super.key});

  @override
  State<HatimlerimScreen> createState() => _HatimlerimScreenState();
}

class _HatimlerimScreenState extends State<HatimlerimScreen> {
  final user = FirebaseAuth.instance.currentUser;

  // Silinmekte olan hatim id'leri — Dismissible/StreamBuilder çakışmasını önler
  final Set<String> _deletingIds = {};

  Future<void> _showNewHatimSheet(BuildContext context, List<Hatim> hatims) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _NewHatimSheet(
          currentHatims: hatims,
          onConfirm: (type, name) => _createHatim(context, type, name),
        ),
      ),
    );
  }

  Future<void> _createHatim(BuildContext context, HatimType type, String name) async {
    if (user == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('hatims')
        .add(Hatim(
          id: '',
          type: type,
          name: name,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ).toMap());
    if (context.mounted) Navigator.pop(context);
  }

  Future<void> _deleteHatim(Hatim hatim) async {
    if (user == null) return;
    setState(() => _deletingIds.add(hatim.id));
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('hatims')
        .doc(hatim.id)
        .delete();
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
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.teal));
          }

          final allHatims = (snap.data?.docs
                  .map((d) => Hatim.fromFirestore(d))
                  .where((h) => !_deletingIds.contains(h.id))
                  .toList()) ??
              [];

          final hatims = allHatims.where((h) => !h.isCompleted).toList();
          final completedCount = allHatims.where((h) => h.isCompleted).length;

          final arapcaCount = hatims.where((h) => h.type == HatimType.arapca).length;
          final mealCount = hatims.where((h) => h.type == HatimType.meal).length;
          final canAddMore = arapcaCount < _arapcaLimit || mealCount < _mealLimit;

          return Scaffold(
            floatingActionButton: canAddMore
                ? FloatingActionButton.extended(
                    onPressed: () => _showNewHatimSheet(context, hatims),
                    backgroundColor: AppColors.teal,
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: const Text('Yeni Hatim',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  )
                : null,
            body: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Hatimlerim',
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark),
                  ),
                  const SizedBox(height: 24),
                  _SummaryCards(uid: user!.uid),
                  const SizedBox(height: 32),
                  const Text(
                    'Aktif Hatimler',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textMid),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: hatims.isEmpty
                        ? _EmptyState(onAdd: () => _showNewHatimSheet(context, hatims))
                        : ListView.builder(
                            itemCount: hatims.length + (completedCount > 0 ? 1 : 0),
                            itemBuilder: (context, i) {
                              if (i < hatims.length) {
                                final hatim = hatims[i];
                                return _DismissibleHatimCard(
                                  hatim: hatim,
                                  onDelete: () => _deleteHatim(hatim),
                                  onHeatMap: () => HatimHeatMapSheet.show(
                                    context,
                                    hatim: hatim,
                                    uid: user!.uid,
                                    onDevamEt: () => LogEntryBottomSheet.show(
                                        context, initialHatim: hatim),
                                  ),
                                );
                              }
                              // Tamamlanan hatimler butonu
                              return Padding(
                                padding: const EdgeInsets.only(top: 4, bottom: 16),
                                child: _TamamlananButton(
                                  count: completedCount,
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const TamamlananHatimlerScreen(),
                                    ),
                                  ),
                                ),
                              );
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
}

// ── Boş durum ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.menu_book_outlined, size: 64, color: AppColors.borderGrey),
          const SizedBox(height: 16),
          const Text('Henüz aktif bir hatiminiz yok.',
              style: TextStyle(color: AppColors.textMid, fontSize: 15)),
          const SizedBox(height: 8),
          const Text('İlk hatimini başlatmak için + butonuna dokun.',
              style: TextStyle(color: AppColors.textLight, fontSize: 13)),
        ],
      ),
    );
  }
}

// ── Özet kartlar ────────────────────────────────────────────────────────────

class _SummaryCards extends StatelessWidget {
  final String uid;
  const _SummaryCards({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data() as Map<String, dynamic>?;
        final seri = data?['seri'] ?? 0;
        final hasanat = data?['hasanat'] ?? 0;
        return Row(
          children: [
            Expanded(child: _StatCard(
              icon: Icons.local_fire_department,
              color: AppColors.orange,
              value: '$seri Gün',
              label: 'Mevcut Seri',
            )),
            const SizedBox(width: 16),
            Expanded(child: _StatCard(
              icon: Icons.stars,
              color: AppColors.gold,
              value: '$hasanat',
              label: 'Toplam Hasanat',
            )),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String label;

  const _StatCard({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: color)),
          Text(label,
              style: const TextStyle(fontSize: 12, color: AppColors.textMid)),
        ],
      ),
    );
  }
}

// ── Hatim kartı (silinebilir) ────────────────────────────────────────────────

class _DismissibleHatimCard extends StatelessWidget {
  final Hatim hatim;
  final VoidCallback onDelete;
  final VoidCallback onHeatMap;

  const _DismissibleHatimCard({
    required this.hatim,
    required this.onDelete,
    required this.onHeatMap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
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
          child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
        ),
        confirmDismiss: (_) async {
          return await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Hatimi sil',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              content: Text(
                '"${hatim.displayName}" silinsin mi?\nBu işlem geri alınamaz.',
                style: const TextStyle(color: AppColors.textMid),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('İptal',
                      style: TextStyle(color: AppColors.textMid)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.errorRed,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Sil',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ) ?? false;
        },
        onDismissed: (_) => onDelete(),
        child: GestureDetector(
          onTap: onHeatMap,
          child: _HatimCardContent(hatim: hatim, onHeatMap: onHeatMap),
        ),
      ),
    );
  }
}

class _HatimCardContent extends StatelessWidget {
  final Hatim hatim;
  final VoidCallback onHeatMap;

  const _HatimCardContent({required this.hatim, required this.onHeatMap});

  int _completedCuzCount(int currentPage) {
    if (currentPage <= 0) return 0;
    return QuranData.cuzler.where((c) => currentPage >= c.endPage).length;
  }

  @override
  Widget build(BuildContext context) {
    final isArapca = hatim.type == HatimType.arapca;
    final completedCuz = _completedCuzCount(hatim.currentPage);
    const totalCuz = 30;
    final cuzProgress = completedCuz / totalCuz;
    final currentCuzInfo = hatim.currentPage == 0
        ? QuranData.cuzler.first
        : QuranData.cuzForPage(hatim.currentPage);
    final currentCuzNo = currentCuzInfo?.cuzNo ?? 1;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.borderGrey),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.tealLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isArapca ? Icons.menu_book : Icons.translate,
                    color: AppColors.teal,
                    size: 18,
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
                        '${hatim.currentPage}/604 sayfa · $currentCuzNo. cüz',
                        style: GoogleFonts.nunito(
                          color: AppColors.textMid,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                // Isı haritası ikonu
                GestureDetector(
                  onTap: onHeatMap,
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: AppColors.lightGrey,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.grid_view_rounded, size: 16, color: AppColors.textMid),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: cuzProgress,
                minHeight: 6,
                backgroundColor: AppColors.borderGrey,
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.teal),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Yeni hatim sheet ─────────────────────────────────────────────────────────

class _NewHatimSheet extends StatefulWidget {
  final List<Hatim> currentHatims;
  final Future<void> Function(HatimType type, String name) onConfirm;

  const _NewHatimSheet({required this.currentHatims, required this.onConfirm});

  @override
  State<_NewHatimSheet> createState() => _NewHatimSheetState();
}

class _NewHatimSheetState extends State<_NewHatimSheet> {
  HatimType? _selectedType;
  final _nameCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  int get _arapcaCount =>
      widget.currentHatims.where((h) => h.type == HatimType.arapca).length;
  int get _mealCount =>
      widget.currentHatims.where((h) => h.type == HatimType.meal).length;

  bool get _arapcaDisabled => _arapcaCount >= _arapcaLimit;
  bool get _mealDisabled => _mealCount >= _mealLimit;

  String _defaultName(HatimType type) {
    if (type == HatimType.meal) return 'Meal Hatimi';
    return _arapcaCount == 0 ? 'Arapça Hatim' : 'Arapça Hatim ${_arapcaCount + 1}';
  }

  void _selectType(HatimType type) {
    setState(() {
      _selectedType = type;
      _nameCtrl.text = _defaultName(type);
    });
  }

  Future<void> _confirm() async {
    if (_selectedType == null) return;
    setState(() => _loading = true);
    final name = _nameCtrl.text.trim().isEmpty
        ? _defaultName(_selectedType!)
        : _nameCtrl.text.trim();
    await widget.onConfirm(_selectedType!, name);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Yeni Hatim Başlat',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark)),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Arapça seçeneği
          _TypeOption(
            icon: Icons.menu_book,
            title: 'Arapça Hatim',
            subtitle: _arapcaDisabled
                ? '$_arapcaLimit hatim limitine ulaştınız'
                : 'Kuran-ı Kerim Arapça metninden hatim',
            count: '$_arapcaCount/$_arapcaLimit',
            isSelected: _selectedType == HatimType.arapca,
            isDisabled: _arapcaDisabled,
            onTap: _arapcaDisabled ? null : () => _selectType(HatimType.arapca),
          ),
          const SizedBox(height: 12),

          // Meal seçeneği
          _TypeOption(
            icon: Icons.translate,
            title: 'Meal Hatimi',
            subtitle: _mealDisabled
                ? 'Aynı anda 1 Meal hatimi açık olabilir'
                : 'Kendi anadilinde anlamıyla hatim',
            count: '$_mealCount/$_mealLimit',
            isSelected: _selectedType == HatimType.meal,
            isDisabled: _mealDisabled,
            onTap: _mealDisabled ? null : () => _selectType(HatimType.meal),
          ),

          // İsim alanı
          if (_selectedType != null) ...[
            const SizedBox(height: 20),
            TextField(
              controller: _nameCtrl,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Hatim adı (opsiyonel)',
                hintText: _defaultName(_selectedType!),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.teal),
                ),
              ),
            ),
          ],

          const SizedBox(height: 20),

          // Başlat butonu
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: (_selectedType == null || _loading) ? null : _confirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.teal,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.borderGrey,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999)),
                elevation: 0,
              ).copyWith(
                side: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.disabled)) return null;
                  return const BorderSide(color: AppColors.tealDark, width: 3);
                }),
              ),
              child: _loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('BAŞLAT',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String count;
  final bool isSelected;
  final bool isDisabled;
  final VoidCallback? onTap;

  const _TypeOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.count,
    required this.isSelected,
    required this.isDisabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: isDisabled ? 0.45 : 1.0,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.tealLight : AppColors.white,
            border: Border.all(
              color: isSelected
                  ? AppColors.teal
                  : isDisabled
                      ? AppColors.borderGrey
                      : AppColors.teal,
              width: isSelected ? 2 : 1.5,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.teal : AppColors.tealLight,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon,
                    color: isSelected ? Colors.white : AppColors.teal,
                    size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: isDisabled
                                ? AppColors.textLight
                                : AppColors.textDark)),
                    Text(subtitle,
                        style: TextStyle(
                            fontSize: 12,
                            color: isDisabled
                                ? AppColors.errorRed
                                : AppColors.textMid)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.teal : AppColors.lightGrey,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(count,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : AppColors.textMid)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Tamamlanan hatimler navigasyon butonu ────────────────────────────────────

class _TamamlananButton extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _TamamlananButton({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF38A474).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF38A474).withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.emoji_events_outlined, size: 18, color: Color(0xFF38A474)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$count tamamlanan hatim',
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF38A474),
                ),
              ),
            ),
            const Icon(Icons.chevron_right, size: 18, color: Color(0xFF38A474)),
          ],
        ),
      ),
    );
  }
}
