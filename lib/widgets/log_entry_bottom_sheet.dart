import 'package:flutter/material.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import '../app_colors.dart';
import '../models/hatim_model.dart';
import '../models/reading_log_model.dart';
import '../data/quran_cuz.dart';

class LogEntryBottomSheet extends StatefulWidget {
  final Hatim? initialHatim;

  const LogEntryBottomSheet({super.key, this.initialHatim});

  static Future<void> show(BuildContext context, {Hatim? initialHatim}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: LogEntryBottomSheet(initialHatim: initialHatim),
      ),
    );
  }

  @override
  State<LogEntryBottomSheet> createState() => _LogEntryBottomSheetState();
}

class _LogEntryBottomSheetState extends State<LogEntryBottomSheet> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late HatimType _selectedType;
  Hatim? _activeHatim;
  
  // Forms state
  bool _isLoading = false;
  
  // Hatim Devam Tab
  final TextEditingController _pagesController = TextEditingController();
  
  // Sure Tab
  SurahInfo? _selectedSurah;
  
  // Sayfa Tab
  final TextEditingController _startPageController = TextEditingController();
  final TextEditingController _endPageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _selectedType = widget.initialHatim?.type ?? HatimType.arapca;
    _activeHatim = widget.initialHatim;
    
    if (_activeHatim == null) {
      _fetchActiveHatim();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pagesController.dispose();
    _startPageController.dispose();
    _endPageController.dispose();
    super.dispose();
  }

  Future<void> _fetchActiveHatim() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    final query = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('hatims')
        .where('type', isEqualTo: _selectedType == HatimType.arapca ? 'arapca' : 'meal')
        .get();
        
    if (query.docs.isNotEmpty) {
      setState(() {
        _activeHatim = Hatim.fromFirestore(query.docs.first);
      });
    } else {
      setState(() {
        _activeHatim = null;
      });
    }
  }

  void _onTypeChanged(HatimType type) {
    if (_selectedType == type) return;
    setState(() {
      _selectedType = type;
      _activeHatim = null; // reset while fetching
    });
    _fetchActiveHatim();
  }

  /// Sayfa aralığından toplam sayfa sayısı hesaplar
  int _calculatePages(int startPage, int endPage) {
    if (startPage > endPage) return 0;
    final start = startPage < 1 ? 1 : startPage;
    final end = endPage > 604 ? 604 : endPage;
    return (end - start) + 1;
  }

  /// Bir surenin toplam sayfa sayısı
  int _getSurahPages(SurahInfo surah) {
    if (surah.startPage == 0) return 1; // Fatiha özel durum
    return _calculatePages(surah.startPage, surah.endPage);
  }

  Future<void> _saveLog() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    int pagesRead = 0;
    LogMethod method;
    int? startPage;
    int? endPage;
    int? surahId;

    if (_tabController.index == 0) {
      // Hatim Devam
      if (_activeHatim == null) return;
      final pages = int.tryParse(_pagesController.text) ?? 0;
      if (pages <= 0) return;
      
      method = LogMethod.hatim;
      pagesRead = pages;
      
      // Hatim'deki başlangıç ve bitiş sayfalarını hesapla
      startPage = _activeHatim!.currentPage + 1;
      endPage = _activeHatim!.currentPage + pages;
      if (endPage > 604) endPage = 604;
      
      // Update Hatim document
      final newCurrentPage = _activeHatim!.currentPage + pages;
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('hatims')
          .doc(_activeHatim!.id)
          .update({
            'currentPage': newCurrentPage > 604 ? 604 : newCurrentPage,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          
    } else if (_tabController.index == 1) {
      // Sure Seç
      if (_selectedSurah == null) return;
      method = LogMethod.surah;
      surahId = _selectedSurah!.id;
      startPage = _selectedSurah!.startPage;
      endPage = _selectedSurah!.endPage;
      pagesRead = _getSurahPages(_selectedSurah!);
      
    } else {
      // Sayfa Aralığı
      final start = int.tryParse(_startPageController.text) ?? 0;
      final end = int.tryParse(_endPageController.text) ?? 0;
      if (start <= 0 || end <= 0 || start > end || end > 604) return;
      
      method = LogMethod.pages;
      startPage = start;
      endPage = end;
      pagesRead = _calculatePages(start, end);
    }

    if (pagesRead <= 0) return;

    setState(() => _isLoading = true);

    // Create Log
    final log = ReadingLog(
      id: '',
      type: _selectedType,
      method: method,
      pagesRead: pagesRead,
      surahId: surahId,
      startPage: startPage,
      endPage: endPage,
      hatimId: _activeHatim?.id,
      createdAt: DateTime.now(),
    );

    // Save Log & Update Hasanat + totalPages
    final batch = FirebaseFirestore.instance.batch();
    
    final logRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('logs')
        .doc();
        
    batch.set(logRef, log.toMap());
    
    final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    batch.update(userRef, {
      'hasanat': FieldValue.increment(pagesRead * 10),
      'totalPages': FieldValue.increment(pagesRead),
    });

    await batch.commit();

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header & Toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Okuma Kaydet', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 16),
          
          if (widget.initialHatim == null)
            SegmentedButton<HatimType>(
              segments: const [
                ButtonSegment(value: HatimType.arapca, label: Text('Arapça'), icon: Icon(Icons.menu_book)),
                ButtonSegment(value: HatimType.meal, label: Text('Meal'), icon: Icon(Icons.translate)),
              ],
              selected: {_selectedType},
              onSelectionChanged: (set) => _onTypeChanged(set.first),
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith((states) {
                  return states.contains(WidgetState.selected) ? AppColors.teal : Colors.transparent;
                }),
                foregroundColor: WidgetStateProperty.resolveWith((states) {
                  return states.contains(WidgetState.selected) ? Colors.white : AppColors.teal;
                }),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              decoration: BoxDecoration(color: AppColors.tealLight, borderRadius: BorderRadius.circular(12)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_selectedType == HatimType.arapca ? Icons.menu_book : Icons.translate, color: AppColors.teal),
                  const SizedBox(width: 8),
                  Text(_selectedType == HatimType.arapca ? 'Arapça Hatim' : 'Meal Hatimi', 
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.teal)),
                ],
              ),
            ),
            
          const SizedBox(height: 16),
          
          TabBar(
            controller: _tabController,
            labelColor: AppColors.teal,
            unselectedLabelColor: AppColors.textLight,
            indicatorColor: AppColors.teal,
            tabs: const [
              Tab(text: 'Hatim Devam'),
              Tab(text: 'Sure'),
              Tab(text: 'Sayfa'),
            ],
          ),
          
          const SizedBox(height: 24),
          
          SizedBox(
            height: 200,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildHatimTab(),
                _buildSurahTab(),
                _buildPagesTab(),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          ElevatedButton(
            onPressed: _isLoading ? null : _saveLog,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.teal,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: _isLoading 
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Kaydet ve Puan Kazan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ],
      ),
    );
  }

  Widget _buildHatimTab() {
    if (_activeHatim == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.info_outline, color: AppColors.textLight, size: 48),
            const SizedBox(height: 8),
            Text('Aktif bir ${_selectedType == HatimType.arapca ? "Arapça" : "Meal"} hatiminiz bulunmuyor.', 
              textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textMid)),
          ],
        ),
      );
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppColors.orange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
          child: Row(
            children: [
              const Icon(Icons.bookmark, color: AppColors.orange),
              const SizedBox(width: 8),
              Text('Kaldığın yer: ${_activeHatim!.currentPage}. Sayfa', 
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.orange)),
            ],
          ),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _pagesController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Kaç sayfa okudun?',
            prefixIcon: const Icon(Icons.add),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  Widget _buildSurahTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Okuduğunuz sureyi seçin. Sayfa sayısı otomatik hesaplanacaktır.', style: TextStyle(color: AppColors.textMid)),
        const SizedBox(height: 16),
        DropdownSearch<SurahInfo>(
          items: (filter, loadProps) => QuranData.surahlar,
          itemAsString: (SurahInfo s) => "${s.id}. ${s.name}",
          compareFn: (a, b) => a.id == b.id,
          onSelected: (SurahInfo? data) {
            setState(() {
              _selectedSurah = data;
            });
          },
          popupProps: const PopupProps.menu(
            showSearchBox: true,
            searchFieldProps: TextFieldProps(
              decoration: InputDecoration(
                hintText: 'Sure ara...',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          decoratorProps: DropDownDecoratorProps(
            decoration: InputDecoration(
              labelText: "Sure Seç",
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        if (_selectedSurah != null) ...[
          const SizedBox(height: 16),
          Text('${_getSurahPages(_selectedSurah!)} sayfa olarak kaydedilecek.', 
            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.teal)),
        ]
      ],
    );
  }

  Widget _buildPagesTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Okuduğunuz sayfa aralığını girin.', style: TextStyle(color: AppColors.textMid)),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _startPageController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Başlangıç',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('-', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: TextField(
                controller: _endPageController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Bitiş',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
