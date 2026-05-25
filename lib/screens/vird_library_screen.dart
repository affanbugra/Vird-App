import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../app_colors.dart';
import '../models/vird_model.dart';

class VirdLibraryScreen extends StatefulWidget {
  const VirdLibraryScreen({super.key});

  @override
  State<VirdLibraryScreen> createState() => _VirdLibraryScreenState();
}

class _VirdLibraryScreenState extends State<VirdLibraryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _uid = FirebaseAuth.instance.currentUser?.uid;
  final Map<String, bool> _expandedItems = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Stream<List<VirdItem>> _getVirdsStream() {
    if (_uid == null) return Stream.value([]);
    return FirebaseFirestore.instance
        .collection('users')
        .doc(_uid)
        .snapshots()
        .map((snap) {
      final List<VirdItem> list = VirdItem.defaultVirds.map((e) => e.copyWith()).toList();
      final userData = snap.data() ?? {};
      final prefsMap = userData['virdPreferences'] as Map<String, dynamic>? ?? {};

      prefsMap.forEach((id, val) {
        final map = Map<String, dynamic>.from(val as Map);
        final isCustom = map['isCustom'] ?? false;

        if (isCustom) {
          list.add(VirdItem.fromMap({...map, 'id': id}));
        } else {
          final idx = list.indexWhere((e) => e.id == id);
          if (idx != -1) {
            list[idx] = VirdItem.fromMap({
              ...list[idx].toMap(),
              ...map,
            });
          }
        }
      });
      return list;
    });
  }

  Future<void> _toggleVird(VirdItem item, bool active) async {
    if (_uid == null) return;
    HapticFeedback.lightImpact();

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .update({
        'virdPreferences.${item.id}': {
          'active': active,
          'category': item.category,
          'targetCount': item.targetCount,
          'title': item.title,
          'arabicTitle': item.arabicTitle,
          'description': item.description,
          'recommendedTime': item.recommendedTime,
          'hadith': item.hadith,
          'isCustom': item.isCustom,
          'updatedAt': FieldValue.serverTimestamp(),
        }
      });
    } catch (e) {
      debugPrint('Error toggling vird: $e');
    }
  }

  Future<void> _updateTargetCount(VirdItem item, int target) async {
    if (_uid == null || target <= 0) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .update({
        'virdPreferences.${item.id}.targetCount': target,
        'virdPreferences.${item.id}.updatedAt': FieldValue.serverTimestamp(),
      });
      HapticFeedback.mediumImpact();
    } catch (e) {
      debugPrint('Error updating target: $e');
    }
  }

  Future<void> _deleteCustomVird(VirdItem item) async {
    if (_uid == null || !item.isCustom) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Virdi Sil', style: GoogleFonts.nunito(fontWeight: FontWeight.bold, color: AppColors.textDark)),
        content: Text('"${item.title}" virdini kalıcı olarak silmek istiyor musunuz?', style: GoogleFonts.nunito(color: AppColors.textMid)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Vazgeç', style: GoogleFonts.nunito(color: AppColors.textLight)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.errorRed,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Sil', style: GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_uid)
            .update({
          'virdPreferences.${item.id}': FieldValue.delete()
        });
        HapticFeedback.mediumImpact();
      } catch (e) {
        debugPrint('Error deleting custom vird: $e');
      }
    }
  }

  void _showAddCustomVirdDialog() {
    final titleController = TextEditingController();
    final arabicController = TextEditingController();
    final descController = TextEditingController();
    final targetController = TextEditingController(text: '100');
    String category = 'zikir';
    String time = 'Günlük';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (sCtx, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sCtx).viewInsets.bottom + 20,
            top: 20,
            left: 20,
            right: 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(color: AppColors.borderGrey, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Yeni Özel Vird Ekle',
                      style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textDark),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(sCtx),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Kategori Seçimi
                Text('Kategori', style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textMid)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _buildCategoryChip(sCtx, 'Zikir', 'zikir', category, (val) {
                      setModalState(() {
                        category = val;
                        if (targetController.text == '1') targetController.text = '100';
                      });
                    }),
                    const SizedBox(width: 8),
                    _buildCategoryChip(sCtx, 'Sure', 'sure', category, (val) {
                      setModalState(() {
                        category = val;
                        targetController.text = '1';
                      });
                    }),
                    const SizedBox(width: 8),
                    _buildCategoryChip(sCtx, 'Dua', 'dua', category, (val) {
                      setModalState(() {
                        category = val;
                        targetController.text = '1';
                      });
                    }),
                  ],
                ),
                const SizedBox(height: 16),

                // Başlık
                TextField(
                  controller: titleController,
                  style: GoogleFonts.nunito(fontSize: 14.5, color: AppColors.textDark),
                  decoration: _buildInputDecoration('Vird Başlığı (örn: Kelime-i Tevhid)'),
                ),
                const SizedBox(height: 12),

                // Arapça Başlık (Opsiyonel)
                TextField(
                  controller: arabicController,
                  style: GoogleFonts.amiri(fontSize: 16, color: AppColors.textDark),
                  textAlign: TextAlign.right,
                  decoration: _buildInputDecoration('Arapça Yazılışı (Opsiyonel)').copyWith(
                    hintStyle: GoogleFonts.nunito(fontSize: 14.5, color: AppColors.textLight),
                  ),
                ),
                const SizedBox(height: 12),

                // Hedef Sayısı ve Önerilen Vakit
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: targetController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        style: GoogleFonts.nunito(fontSize: 14.5, color: AppColors.textDark),
                        decoration: _buildInputDecoration('Hedef Adeti'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: AppColors.lightGrey,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.borderGrey),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: time,
                            icon: const Icon(Icons.arrow_drop_down, color: AppColors.textMid),
                            items: [
                              'Günlük',
                              'Sabah Namazı Sonrası',
                              'İkindi Sonrası',
                              'Akşam Sonrası',
                              'Yatsı Sonrası',
                              'Cuma Gününe Özel',
                              'Her Zaman'
                            ].map((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value, style: GoogleFonts.nunito(fontSize: 13.5, color: AppColors.textDark)),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setModalState(() => time = val);
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Açıklama / Fazilet
                TextField(
                  controller: descController,
                  maxLines: 2,
                  style: GoogleFonts.nunito(fontSize: 14.5, color: AppColors.textDark),
                  decoration: _buildInputDecoration('Açıklama / Fazileti (Opsiyonel)'),
                ),
                const SizedBox(height: 24),

                // Ekle Butonu
                GestureDetector(
                  onTap: () async {
                    final title = titleController.text.trim();
                    final target = int.tryParse(targetController.text) ?? 1;
                    if (title.isEmpty || _uid == null) return;
                    final customId = 'custom_${DateTime.now().millisecondsSinceEpoch}';
                    try {
                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(_uid)
                          .update({
                        'virdPreferences.$customId': {
                          'title': title,
                          'arabicTitle': arabicController.text.trim().isEmpty ? null : arabicController.text.trim(),
                          'description': descController.text.trim().isEmpty ? 'Özel tanımlanmış vird.' : descController.text.trim(),
                          'category': category,
                          'targetCount': target,
                          'recommendedTime': time,
                          'active': true,
                          'isCustom': true,
                          'updatedAt': FieldValue.serverTimestamp(),
                        }
                      });

                      HapticFeedback.mediumImpact();
                      if (sCtx.mounted) Navigator.pop(sCtx);
                    } catch (e) {
                      debugPrint('Error saving custom vird: $e');
                      if (sCtx.mounted) {
                        ScaffoldMessenger.of(sCtx).showSnackBar(
                          SnackBar(
                            content: Text('Vird kaydedilemedi: yetki yetersiz veya bağlantı hatası.'),
                            backgroundColor: AppColors.errorRed,
                          ),
                        );
                      }
                    }
                  },
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.teal,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.tealDark.withValues(alpha: 0.3),
                          offset: const Offset(0, 4),
                          blurRadius: 8,
                        )
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'LİSTEME EKLE',
                      style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 1.0),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChip(BuildContext ctx, String label, String value, String selectedValue, ValueChanged<String> onTap) {
    final active = value == selectedValue;
    return GestureDetector(
      onTap: () => onTap(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppColors.teal : AppColors.lightGrey,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? AppColors.teal : AppColors.borderGrey),
        ),
        child: Text(
          label,
          style: GoogleFonts.nunito(
            fontSize: 13,
            fontWeight: active ? FontWeight.bold : FontWeight.w600,
            color: active ? Colors.white : AppColors.textMid,
          ),
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.nunito(fontSize: 14.5, color: AppColors.textLight),
      filled: true,
      fillColor: AppColors.lightGrey,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.borderGrey, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.teal, width: 1.5),
      ),
    );
  }

  void _showEditTargetDialog(VirdItem item) {
    final controller = TextEditingController(text: item.targetCount.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Hedef Adeti Değiştir',
          style: GoogleFonts.nunito(fontWeight: FontWeight.bold, color: AppColors.textDark, fontSize: 16),
        ),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: _buildInputDecoration('Hedef sayısı girin'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Vazgeç', style: GoogleFonts.nunito(color: AppColors.textLight)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.teal,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              final target = int.tryParse(controller.text) ?? item.targetCount;
              Navigator.pop(ctx);
              _updateTargetCount(item, target);
            },
            child: Text('Güncelle', style: GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textDark, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Vird Kütüphanesi',
          style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textDark),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.teal, size: 26),
            onPressed: _showAddCustomVirdDialog,
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.teal,
          labelColor: AppColors.teal,
          unselectedLabelColor: AppColors.textLight,
          labelStyle: GoogleFonts.nunito(fontSize: 13.5, fontWeight: FontWeight.bold),
          unselectedLabelStyle: GoogleFonts.nunito(fontSize: 13.5, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'Sureler'),
            Tab(text: 'Zikirler'),
            Tab(text: 'Dualar'),
            Tab(text: 'Özel'),
          ],
        ),
      ),
      body: StreamBuilder<List<VirdItem>>(
        stream: _getVirdsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.teal));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildEmptyState();
          }

          final allVirds = snapshot.data!;
          final sures = allVirds.where((e) => e.category == 'sure').toList();
          final zikirs = allVirds.where((e) => e.category == 'zikir' && !e.isCustom).toList();
          final duas = allVirds.where((e) => e.category == 'dua').toList();
          final customs = allVirds.where((e) => e.isCustom).toList();

          return TabBarView(
            controller: _tabController,
            children: [
              _buildVirdList(sures),
              _buildVirdList(zikirs),
              _buildVirdList(duas),
              _buildVirdList(customs, isCustomTab: true),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.menu_book_rounded, size: 64, color: AppColors.borderGrey),
          const SizedBox(height: 12),
          Text(
            'Kütüphane Yüklenemedi',
            style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textMid),
          ),
        ],
      ),
    );
  }

  Widget _buildVirdList(List<VirdItem> items, {bool isCustomTab = false}) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                isCustomTab ? 'Henüz özel bir vird eklemediniz.' : 'Bu kategoride vird bulunamadı.',
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(fontSize: 14.5, color: AppColors.textLight, height: 1.5),
              ),
              if (isCustomTab) ...[
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.teal,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  onPressed: _showAddCustomVirdDialog,
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: Text('Özel Vird Ekle', style: GoogleFonts.nunito(fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final isExpanded = _expandedItems[item.id] ?? false;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppColors.lightGrey,
            border: Border.all(color: AppColors.borderGrey),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              // Ana Başlık Satırı
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                title: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textDark),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
                                child: Text(
                                  item.recommendedTime,
                                  style: GoogleFonts.nunito(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textLight),
                                ),
                              ),
                              if (item.category == 'zikir') ...[
                                const SizedBox(width: 6),
                                GestureDetector(
                                  onTap: () => _showEditTargetDialog(item),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.tealLight,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: AppColors.teal.withValues(alpha: 0.2)),
                                    ),
                                    child: Row(
                                      children: [
                                        Text(
                                          'Hedef: ${item.targetCount}',
                                          style: GoogleFonts.nunito(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.teal),
                                        ),
                                        const SizedBox(width: 2),
                                        const Icon(Icons.edit, size: 9, color: AppColors.teal),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (item.arabicTitle != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        item.arabicTitle!,
                        style: GoogleFonts.amiri(fontSize: 16, color: AppColors.textMid, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Switch(
                      value: item.active,
                      activeColor: AppColors.teal,
                      activeTrackColor: AppColors.tealLight,
                      inactiveThumbColor: AppColors.textLight,
                      inactiveTrackColor: AppColors.borderGrey,
                      onChanged: (active) => _toggleVird(item, active),
                    ),
                    IconButton(
                      icon: Icon(
                        isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                        color: AppColors.textLight,
                      ),
                      onPressed: () {
                        setState(() {
                          _expandedItems[item.id] = !isExpanded;
                        });
                      },
                    ),
                  ],
                ),
              ),

              // Genişletilebilir Bilgi & Silme Satırı
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: Colors.white, width: 1.5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      Text(
                        item.description,
                        style: GoogleFonts.nunito(fontSize: 13.5, color: AppColors.textMid, height: 1.5),
                      ),
                      if (item.hadith != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.borderGrey.withValues(alpha: 0.5)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Fazileti & Kaynağı:',
                                style: GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.teal),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item.hadith!,
                                style: GoogleFonts.nunito(fontSize: 12.5, color: AppColors.textDark, height: 1.45, fontStyle: FontStyle.italic),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (item.isCustom) ...[
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            style: TextButton.styleFrom(foregroundColor: AppColors.errorRed),
                            onPressed: () => _deleteCustomVird(item),
                            icon: const Icon(Icons.delete_outline_rounded, size: 18),
                            label: Text('Bu Virdi Sil', style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 200),
              ),
            ],
          ),
        );
      },
    );
  }
}
