import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dropdown_search/dropdown_search.dart';
import '../app_colors.dart';
import '../app_theme.dart';
import '../models/vird_model.dart';
import '../data/quran_cuz.dart';

class VirdLibraryScreen extends StatefulWidget {
  const VirdLibraryScreen({super.key});

  @override
  State<VirdLibraryScreen> createState() => _VirdLibraryScreenState();
}

class _VirdLibraryScreenState extends State<VirdLibraryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _uid = FirebaseAuth.instance.currentUser?.uid;
  final Map<String, bool> _expandedItems = {};
  late Stream<List<VirdItem>> _virdsStream;
  List<VirdItem> _latestVirds = [];
  StreamSubscription<List<VirdItem>>? _virdsSub;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (mounted && !_tabController.indexIsChanging) {
        setState(() => _expandedItems.clear());
      }
    });
    _virdsStream = _getVirdsStream();
    _virdsSub = _virdsStream.listen((v) {
      if (mounted) setState(() => _latestVirds = v);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _virdsSub?.cancel();
    super.dispose();
  }

  Stream<List<VirdItem>> _getVirdsStream() {
    if (_uid == null) return Stream.value([]);
    return FirebaseFirestore.instance
        .collection('users')
        .doc(_uid)
        .snapshots()
        .map((snap) {
      // Yeni kullanıcılar için varsayılan olarak hepsi kapalı; kullanıcı prefsMap'te aktif etmediyse gösterilmez
      final List<VirdItem> list = VirdItem.defaultVirds.map((e) => e.copyWith(active: false)).toList();
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
            final defaultMap = list[idx].toMap();
            list[idx] = VirdItem.fromMap({
              ...defaultMap,
              ...map,
              // İçerik alanları her zaman koddan gelir — Firestore'daki eskiler geçersiz
              'hadith': defaultMap['hadith'],
              'description': defaultMap['description'],
              'arabicTitle': defaultMap['arabicTitle'],
              'recommendedTime': defaultMap['recommendedTime'],
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
        backgroundColor: context.colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Virdi Sil', style: GoogleFonts.nunito(fontWeight: FontWeight.bold, color: context.colors.textPrimary)),
        content: Text('"${item.title}" virdini kalıcı olarak silmek istiyor musunuz?', style: GoogleFonts.nunito(color: context.colors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Vazgeç', style: GoogleFonts.nunito(color: context.colors.textTertiary)),
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
    String time = 'Sabah Namazı Sonrası';
    SurahInfo? selectedSurah;

    String _n(String s) => s.toLowerCase().replaceAll("'", '').replaceAll('\u2018', '').replaceAll('\u2019', '');
    final addedSurahNames = _latestVirds
        .where((v) => v.category == 'sure')
        .expand((v) {
          final tNorm = _n(v.title);
          return QuranData.surahlar
              .where((s) => tNorm.contains(_n(s.name)))
              .map((s) => s.name);
        })
        .toSet();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (sCtx, setModalState) {
          InputDecoration field(String hint) => InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.nunito(fontSize: 14, color: context.colors.textTertiary),
            contentPadding: const EdgeInsets.only(bottom: 8),
            isDense: true,
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: sCtx.colors.border, width: 1),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.teal, width: 1.5),
            ),
          );

          return Container(
            decoration: BoxDecoration(
              color: sCtx.colors.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(sCtx).viewInsets.bottom + 24,
              top: 12,
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
                      width: 36, height: 3,
                      decoration: BoxDecoration(color: context.colors.border, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Yeni vird ekle',
                        style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700, color: context.colors.textPrimary),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(sCtx),
                        child: Icon(Icons.close_rounded, size: 20, color: sCtx.colors.textTertiary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Segmented kategori seçimi — kayan indicator
                  Container(
                    height: 36,
                    decoration: BoxDecoration(
                      color: context.colors.surfaceVariant,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Stack(
                      children: [
                        // Kayan beyaz pill
                        AnimatedAlign(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeInOut,
                          alignment: category == 'sure'
                              ? Alignment.centerLeft
                              : category == 'zikir'
                                  ? Alignment.center
                                  : Alignment.centerRight,
                          child: FractionallySizedBox(
                            widthFactor: 1 / 3,
                            child: Container(
                              margin: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: sCtx.colors.surface,
                                borderRadius: BorderRadius.circular(7),
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withValues(alpha: 0.07), blurRadius: 4, offset: const Offset(0, 1)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Etiketler
                        Row(
                          children: [
                            _buildSegmentTab('Sure', 'sure', category, (val) => setModalState(() {
                              category = val;
                              targetController.text = '1';
                            })),
                            _buildSegmentTab('Zikir', 'zikir', category, (val) => setModalState(() {
                              category = val;
                              if (targetController.text == '1') targetController.text = '100';
                            })),
                            _buildSegmentTab('Dua', 'dua', category, (val) => setModalState(() {
                              category = val;
                              targetController.text = '1';
                            })),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  SizedBox(
                    height: 220,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        if (category == 'sure')
                          DropdownSearch<SurahInfo>(
                            items: (filter, _) => QuranData.surahlar,
                            itemAsString: (s) => '${s.id}. ${s.name}',
                            filterFn: (s, filter) {
                              final q = filter.toLowerCase();
                              return s.name.toLowerCase().contains(q) || s.id.toString().contains(q);
                            },
                            compareFn: (a, b) => a.id == b.id,
                            selectedItem: selectedSurah,
                            onSelected: (s) => setModalState(() => selectedSurah = s),
                            popupProps: PopupProps.menu(
                              showSearchBox: true,
                              disabledItemFn: (s) => addedSurahNames.contains(s.name),
                              searchFieldProps: const TextFieldProps(
                                decoration: InputDecoration(
                                  hintText: 'Sure ara...',
                                  prefixIcon: Icon(Icons.search),
                                ),
                              ),
                              itemBuilder: (ctx, s, isDisabled, isSelected) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                                  color: Colors.transparent,
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 26, height: 26,
                                        decoration: BoxDecoration(
                                          color: isDisabled
                                              ? context.colors.border.withValues(alpha: 0.4)
                                              : AppColors.teal.withValues(alpha: 0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Center(
                                          child: Text(
                                            '${s.id}',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                              color: isDisabled ? context.colors.textTertiary : AppColors.teal,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          s.name,
                                          style: TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w600,
                                            color: isDisabled ? context.colors.textTertiary : context.colors.textPrimary,
                                          ),
                                        ),
                                      ),
                                      if (isDisabled)
                                        Text(
                                          'Eklendi',
                                          style: GoogleFonts.nunito(fontSize: 11, color: context.colors.textTertiary),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),
                            decoratorProps: DropDownDecoratorProps(
                              decoration: InputDecoration(
                                hintText: 'Sure seç',
                                hintStyle: GoogleFonts.nunito(fontSize: 14, color: context.colors.textTertiary),
                                contentPadding: const EdgeInsets.only(bottom: 8),
                                isDense: true,
                                enabledBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(color: sCtx.colors.border, width: 1),
                                ),
                                focusedBorder: const UnderlineInputBorder(
                                  borderSide: BorderSide(color: AppColors.teal, width: 1.5),
                                ),
                              ),
                            ),
                          )
                        else
                          TextField(
                            controller: titleController,
                            style: GoogleFonts.nunito(fontSize: 14, color: context.colors.textPrimary),
                            decoration: field(category == 'zikir' ? 'Zikir adı (örn: Sübhanallah)' : 'Dua adı'),
                          ),
                        if (category != 'sure')
                          TextField(
                            controller: arabicController,
                            style: GoogleFonts.amiri(fontSize: 16, color: context.colors.textPrimary),
                            textAlign: TextAlign.right,
                            decoration: field('Arapça yazılışı (opsiyonel)'),
                          ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (category != 'sure') ...[
                              SizedBox(
                                width: 72,
                                child: TextField(
                                  controller: targetController,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                  style: GoogleFonts.nunito(fontSize: 14, color: context.colors.textPrimary),
                                  decoration: field('Hedef'),
                                ),
                              ),
                              const SizedBox(width: 16),
                            ],
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border(bottom: BorderSide(color: sCtx.colors.border, width: 1)),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: time,
                                    isExpanded: true,
                                    isDense: true,
                                    icon: Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: sCtx.colors.textTertiary),
                                    style: GoogleFonts.nunito(fontSize: 13.5, color: context.colors.textPrimary),
                                    items: [
                                      'Sabah Namazı Sonrası',
                                      'Öğle Namazı Sonrası',
                                      'İkindi Namazı Sonrası',
                                      'Akşam Namazı Sonrası',
                                      'Yatsı Namazı Sonrası',
                                      'Cuma Gününe Özel',
                                      'Günlük',
                                      'Her Zaman',
                                    ].map((v) => DropdownMenuItem(
                                      value: v,
                                      child: Text(v, style: GoogleFonts.nunito(fontSize: 13, color: context.colors.textPrimary)),
                                    )).toList(),
                                    onChanged: (val) {
                                      if (val != null) setModalState(() => time = val);
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        TextField(
                          controller: descController,
                          maxLines: 2,
                          style: GoogleFonts.nunito(fontSize: 14, color: context.colors.textPrimary),
                          decoration: field('Açıklama / fazileti (opsiyonel)'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  GestureDetector(
                    onTap: () async {
                      final title = category == 'sure'
                          ? (selectedSurah != null ? '${selectedSurah!.name} Suresi' : '')
                          : titleController.text.trim();
                      final arabicTitle = category == 'sure'
                          ? (selectedSurah != null ? 'سورة ${selectedSurah!.arabicName}' : null)
                          : (arabicController.text.trim().isEmpty ? null : arabicController.text.trim());
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
                            'arabicTitle': arabicTitle,
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
                      height: 46,
                      decoration: BoxDecoration(
                        color: AppColors.teal,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'EKLE',
                        style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.6),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSegmentTab(String label, String value, String selectedValue, ValueChanged<String> onTap) {
    final active = value == selectedValue;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(value),
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: 13,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              color: active ? AppColors.teal : context.colors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.nunito(fontSize: 14.5, color: context.colors.textTertiary),
      filled: true,
      fillColor: context.colors.surfaceVariant,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: context.colors.border, width: 1.5),
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
        backgroundColor: context.colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Hedef Adeti Değiştir',
          style: GoogleFonts.nunito(fontWeight: FontWeight.bold, color: context.colors.textPrimary, fontSize: 16),
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
            child: Text('Vazgeç', style: GoogleFonts.nunito(color: context.colors.textTertiary)),
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
      backgroundColor: context.colors.surface,
      appBar: AppBar(
        backgroundColor: context.colors.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: context.colors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Vird Kütüphanesi',
          style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w800, color: context.colors.textPrimary),
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
          unselectedLabelColor: context.colors.textTertiary,
          labelStyle: GoogleFonts.nunito(fontSize: 13.5, fontWeight: FontWeight.bold),
          unselectedLabelStyle: GoogleFonts.nunito(fontSize: 13.5, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'Sureler'),
            Tab(text: 'Zikirler'),
            Tab(text: 'Dualar'),
          ],
        ),
      ),
      body: StreamBuilder<List<VirdItem>>(
        stream: _virdsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.teal));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildEmptyState();
          }

          final allVirds = snapshot.data!;
          
          final suresDefault = allVirds.where((e) => e.category == 'sure' && !e.isCustom).toList();
          final suresCustom = allVirds.where((e) => e.category == 'sure' && e.isCustom).toList();
          
          final zikirsDefault = allVirds.where((e) => e.category == 'zikir' && !e.isCustom).toList();
          final zikirsCustom = allVirds.where((e) => e.category == 'zikir' && e.isCustom).toList();
          
          final duasDefault = allVirds.where((e) => e.category == 'dua' && !e.isCustom).toList();
          final duasCustom = allVirds.where((e) => e.category == 'dua' && e.isCustom).toList();

          return TabBarView(
            controller: _tabController,
            children: [
              _buildVirdList(
                defaultItems: suresDefault,
                customItems: suresCustom,
                footer: _buildSureAutoLogNote(),
              ),
              _buildVirdList(defaultItems: zikirsDefault, customItems: zikirsCustom),
              _buildVirdList(defaultItems: duasDefault, customItems: duasCustom),
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
          Icon(Icons.menu_book_rounded, size: 64, color: context.colors.border),
          const SizedBox(height: 12),
          Text(
            'Kütüphane Yüklenemedi',
            style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700, color: context.colors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildSureAutoLogNote() {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: context.colors.tealSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.teal.withValues(alpha: 0.25)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.auto_stories_rounded, size: 16, color: AppColors.teal),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Günlük olarak tamamladığınız sureler otomatik okuma kaydı olarak eklenir; seri ve Kuran haritanızı günceller.',
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.tealDark,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVirdList({
    required List<VirdItem> defaultItems,
    required List<VirdItem> customItems,
    Widget? footer,
  }) {
    if (defaultItems.isEmpty && customItems.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            'Bu kategoride vird bulunamadı.',
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(fontSize: 14.5, color: context.colors.textTertiary, height: 1.5),
          ),
        ),
      );
    }

    final List<Widget> children = [];

    // Sistem virdleri
    for (int i = 0; i < defaultItems.length; i++) {
      final item = defaultItems[i];
      final isLast = i == defaultItems.length - 1;
      children.add(_buildVirdTile(item, isLast: isLast));
    }

    // Özel kullanıcı virdleri ve ayırıcı çizgi
    if (customItems.isNotEmpty) {
      children.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            children: [
              Expanded(
                child: Divider(
                  color: context.colors.border.withValues(alpha: 0.8),
                  thickness: 1.2,
                  endIndent: 12,
                ),
              ),
              Text(
                'KENDİ EKLEDİKLERİM',
                style: GoogleFonts.nunito(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: context.colors.textTertiary,
                  letterSpacing: 1.0,
                ),
              ),
              Expanded(
                child: Divider(
                  color: context.colors.border.withValues(alpha: 0.8),
                  thickness: 1.2,
                  indent: 12,
                ),
              ),
            ],
          ),
        ),
      );

      for (int i = 0; i < customItems.length; i++) {
        final item = customItems[i];
        final isLast = i == customItems.length - 1;
        children.add(_buildVirdTile(item, isLast: isLast));
      }
    }

    if (footer != null) children.add(footer);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: children,
    );
  }

  Widget _buildVirdTile(VirdItem item, {required bool isLast}) {
    final isExpanded = _expandedItems[item.id] ?? false;

    IconData categoryIcon;
    Color categoryColor;
    
    switch (item.category) {
      case 'sure':
        categoryIcon = Icons.auto_stories_rounded;
        categoryColor = AppColors.teal;
        break;
      case 'zikir':
        categoryIcon = Icons.repeat_one_rounded;
        categoryColor = AppColors.orange;
        break;
      case 'dua':
        categoryIcon = Icons.bookmark_added_rounded;
        categoryColor = AppColors.infoBlue;
        break;
      default:
        categoryIcon = Icons.bookmark_rounded;
        categoryColor = context.colors.textSecondary;
    }

    return Container(
      decoration: BoxDecoration(
        border: isLast ? null : Border(
          bottom: BorderSide(
            color: context.colors.border.withValues(alpha: 0.5),
            width: 1.0,
          ),
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                final wasOpen = _expandedItems[item.id] ?? false;
                _expandedItems.clear();
                if (!wasOpen) _expandedItems[item.id] = true;
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  // Sol Kategori İkonu
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: categoryColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      categoryIcon,
                      color: categoryColor,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Orta Bilgi (Başlık + Alt Bilgi)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          item.title,
                          style: GoogleFonts.nunito(
                            fontSize: 14.5,
                            fontWeight: FontWeight.bold,
                            color: context.colors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Text(
                              item.recommendedTime,
                              style: GoogleFonts.nunito(
                                  fontSize: 10.0,
                                  color: context.colors.textTertiary,
                                  fontWeight: FontWeight.w600,
                                ),
                            ),
                            if (item.arabicTitle != null) ...[
                              const SizedBox(width: 6),
                              Text(
                                '•',
                                style: TextStyle(fontSize: 8, color: context.colors.textTertiary.withValues(alpha: 0.5)),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                item.arabicTitle!,
                                style: GoogleFonts.amiri(
                                  fontSize: 12.0,
                                  color: context.colors.textTertiary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Sağ Taraf: Hedef badge + Switch + Chevron
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (item.category != 'sure') ...[
                        GestureDetector(
                          onTap: () => _showEditTargetDialog(item),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: context.colors.tealSurface,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppColors.teal.withValues(alpha: 0.2)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Hedef: ${item.targetCount}',
                                  style: GoogleFonts.nunito(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.teal,
                                  ),
                                ),
                                const SizedBox(width: 2),
                                const Icon(Icons.edit, size: 8, color: AppColors.teal),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                      ],
                      Transform.scale(
                        scale: 0.8,
                        child: Switch(
                          value: item.active,
                          activeColor: AppColors.teal,
                          activeTrackColor: context.colors.tealSurface,
                          inactiveThumbColor: context.colors.textTertiary,
                          inactiveTrackColor: context.colors.border,
                          onChanged: (active) => _toggleVird(item, active),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                        color: context.colors.textTertiary,
                        size: 18,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Genişletilebilir Bilgi & Silme Satırı
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(44, 0, 8, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.description,
                    style: GoogleFonts.nunito(
                      fontSize: 12.5,
                      color: context.colors.textSecondary,
                      height: 1.45,
                    ),
                  ),
                  if (item.hadith != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: context.colors.surfaceVariant,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: context.colors.border.withValues(alpha: 0.5)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Fazileti & Kaynağı:',
                            style: GoogleFonts.nunito(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.teal,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.hadith!,
                            style: GoogleFonts.nunito(
                              fontSize: 11.5,
                              color: context.colors.textPrimary,
                              height: 1.4,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (item.isCustom) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.errorRed,
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () => _deleteCustomVird(item),
                        icon: const Icon(Icons.delete_outline_rounded, size: 16),
                        label: Text(
                          'Bu Virdi Sil',
                          style: GoogleFonts.nunito(fontSize: 11.5, fontWeight: FontWeight.bold),
                        ),
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
  }
}
