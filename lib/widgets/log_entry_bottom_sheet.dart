import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import '../app_colors.dart';
import '../models/hatim_model.dart';
import '../models/reading_log_model.dart';
import '../data/quran_cuz.dart';
import 'log_history_sheet.dart';

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

class _LogEntryBottomSheetState extends State<LogEntryBottomSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<Hatim> _hatims = [];
  bool _loadingHatims = true;
  bool _isLoading = false;

  // ── Devam ──────────────────────────────────────────────────────────
  Hatim? _devamHatim;
  final _devamPagesCtrl = TextEditingController();

  // ── Sayfa ──────────────────────────────────────────────────────────
  final _startPageCtrl = TextEditingController();
  final _endPageCtrl = TextEditingController();
  Hatim? _sayfaHatim;

  // ── Cüz ────────────────────────────────────────────────────────────
  CuzInfo? _selectedCuz;
  Hatim? _cuzHatim;

  // ── Sure ───────────────────────────────────────────────────────────
  SurahInfo? _selectedSurah;

  // ── Ortak tür seçici ───────────────────────────────────────────────
  HatimType _globalType = HatimType.arapca;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    if (widget.initialHatim != null) {
      _devamHatim = widget.initialHatim;
      _globalType = widget.initialHatim!.type;
    }
    _fetchHatims();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _devamPagesCtrl.dispose();
    _startPageCtrl.dispose();
    _endPageCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchHatims() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _loadingHatims = false);
      return;
    }
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('hatims')
        .orderBy('updatedAt', descending: true)
        .get();
    if (!mounted) return;
    setState(() {
      _hatims = snap.docs.map((d) => Hatim.fromFirestore(d)).toList();
      _loadingHatims = false;
      // Devam sekmesinde tek hatim varsa otomatik seç
      if (widget.initialHatim == null && _hatims.length == 1) {
        _devamHatim = _hatims.first;
      }
    });
  }

  // ── Kaydet ─────────────────────────────────────────────────────────

  Future<void> _saveLog() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    int pagesRead;
    LogMethod method;
    int? startPage;
    int? endPage;
    int? surahId;
    String? hatimId;
    HatimType type;
    Hatim? linkedHatim;

    switch (_tabController.index) {
      case 0: // Devam
        if (_devamHatim == null) return;
        final pages = int.tryParse(_devamPagesCtrl.text) ?? 0;
        if (pages <= 0) return;
        method = LogMethod.hatim;
        type = _devamHatim!.type;
        pagesRead = pages;
        startPage = (_devamHatim!.currentPage + 1).clamp(1, 604);
        endPage = (_devamHatim!.currentPage + pages).clamp(1, 604);
        hatimId = _devamHatim!.id;
        linkedHatim = _devamHatim;

      case 1: // Sayfa
        final s = int.tryParse(_startPageCtrl.text) ?? 0;
        final e = int.tryParse(_endPageCtrl.text) ?? 0;
        if (s <= 0 || e <= 0 || s > e || e > 604) return;
        method = LogMethod.pages;
        type = _sayfaHatim?.type ?? _globalType;
        startPage = s;
        endPage = e;
        pagesRead = e - s + 1;
        hatimId = _sayfaHatim?.id;
        linkedHatim = _sayfaHatim;

      case 2: // Cüz
        if (_selectedCuz == null) return;
        method = LogMethod.cuz;
        type = _cuzHatim?.type ?? _globalType;
        startPage = _selectedCuz!.startPage;
        endPage = _selectedCuz!.endPage;
        pagesRead = _selectedCuz!.pageCount;
        hatimId = _cuzHatim?.id;
        linkedHatim = _cuzHatim;

      default: // Sure
        if (_selectedSurah == null) return;
        method = LogMethod.surah;
        type = _globalType;
        surahId = _selectedSurah!.id;
        startPage = _selectedSurah!.startPage;
        endPage = _selectedSurah!.endPage;
        pagesRead = _selectedSurah!.startPage == 0
            ? 1
            : (_selectedSurah!.endPage - _selectedSurah!.startPage + 1);
        hatimId = null;
        linkedHatim = null;
    }

    if (pagesRead <= 0) return;
    setState(() => _isLoading = true);

    try {
      final batch = FirebaseFirestore.instance.batch();

      final logRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('logs')
          .doc();

      batch.set(logRef, ReadingLog(
        id: '',
        type: type,
        method: method,
        pagesRead: pagesRead,
        surahId: surahId,
        startPage: startPage,
        endPage: endPage,
        hatimId: hatimId,
        createdAt: DateTime.now(),
      ).toMap());

      final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
      batch.update(userRef, {
        'hasanat': FieldValue.increment(pagesRead * 10),
        'totalPages': FieldValue.increment(pagesRead),
      });

      if (linkedHatim != null && hatimId != null) {
        final hatimRef = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('hatims')
            .doc(hatimId);

        final int newCurrentPage;
        if (_tabController.index == 0) {
          // Devam: kaldığı yerden ilerle
          newCurrentPage = (linkedHatim.currentPage + pagesRead).clamp(0, 604);
        } else {
          // Sayfa/Cüz: bitiş sayfasına götür (geri gitmez)
          newCurrentPage = math.max(linkedHatim.currentPage, endPage);
        }

        batch.update(hatimRef, {
          'currentPage': newCurrentPage,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Yardımcı ───────────────────────────────────────────────────────

  String _hatimPositionText(Hatim hatim) {
    if (hatim.currentPage == 0) return 'Henüz başlanmadı';
    final cuz = QuranData.cuzForPage(hatim.currentPage);
    if (cuz == null) return '${hatim.currentPage}. sayfa';
    final pagesInCuz = hatim.currentPage - cuz.startPage + 1;
    return '${cuz.cuzNo}. cüzden $pagesInCuz sayfa okundu';
  }

  String _hatimSurahText(Hatim hatim) {
    if (hatim.currentPage == 0) return 'Fâtiha';
    return QuranData.surahsOnPage(hatim.currentPage);
  }

  // ── Tab: Devam ──────────────────────────────────────────────────────

  Widget _buildDevamTab() {
    if (_loadingHatims && _devamHatim == null) {
      return const Center(child: CircularProgressIndicator(color: AppColors.teal));
    }

    // Eğer initialHatim ile gelindiyse hatim zaten seçili — direk input göster
    if (_devamHatim != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Seçili hatim bilgi kartı
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.tealLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.teal.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.teal,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _devamHatim!.type == HatimType.arapca ? Icons.menu_book : Icons.translate,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _devamHatim!.displayName,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.teal),
                      ),
                      Text(
                        _hatimPositionText(_devamHatim!),
                        style: const TextStyle(fontSize: 12, color: AppColors.teal),
                      ),
                      Text(
                        _hatimSurahText(_devamHatim!),
                        style: TextStyle(
                            fontSize: 11, color: AppColors.teal.withValues(alpha: 0.7)),
                      ),
                    ],
                  ),
                ),
                // Birden fazla hatim varsa değiştir seçeneği
                if (_hatims.length > 1)
                  GestureDetector(
                    onTap: () => setState(() => _devamHatim = null),
                    child: const Text('Değiştir',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppColors.teal,
                            fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _devamPagesCtrl,
            keyboardType: TextInputType.number,
            autofocus: widget.initialHatim != null,
            decoration: InputDecoration(
              labelText: 'Kaç sayfa okudun?',
              prefixIcon: const Icon(Icons.add),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.teal),
              ),
            ),
          ),
        ],
      );
    }

    // Hatim seçim ekranı
    if (_hatims.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.info_outline, color: AppColors.textLight, size: 40),
            const SizedBox(height: 8),
            const Text('Aktif hatiminiz yok.',
                style: TextStyle(color: AppColors.textMid)),
            const SizedBox(height: 4),
            const Text('Sayfa, Cüz veya Sure sekmesinden serbest log girebilirsiniz.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textLight, fontSize: 12)),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Hangi hatim?',
            style: TextStyle(color: AppColors.textMid, fontSize: 13)),
        const SizedBox(height: 8),
        ..._hatims.map((h) => _HatimSelectCard(
              hatim: h,
              isSelected: false,
              positionText: _hatimPositionText(h),
              surahText: _hatimSurahText(h),
              onTap: () => setState(() => _devamHatim = h),
            )),
      ],
    );
  }

  // ── Tab: Sayfa ──────────────────────────────────────────────────────

  Widget _buildSayfaTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _startPageCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Başlangıç',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.teal),
                    ),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text('–',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textMid)),
              ),
              Expanded(
                child: TextField(
                  controller: _endPageCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Bitiş',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.teal),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_hatims.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('Hatimle ilişkilendir (opsiyonel):',
                style: TextStyle(color: AppColors.textMid, fontSize: 13)),
            const SizedBox(height: 8),
            _OptionalHatimChips(
              hatims: _hatims.where((h) => h.type == _globalType).toList(),
              selected: _sayfaHatim,
              onChanged: (h) => setState(() => _sayfaHatim = h),
            ),
          ],
        ],
      ),
    );
  }

  // ── Tab: Cüz ────────────────────────────────────────────────────────

  Widget _buildCuzTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownSearch<CuzInfo>(
            items: (filter, _) => QuranData.cuzler,
            itemAsString: (c) => '${c.cuzNo}. Cüz  (${c.startPage}–${c.endPage}. sayfa)',
            compareFn: (a, b) => a.cuzNo == b.cuzNo,
            onSelected: (c) => setState(() => _selectedCuz = c),
            popupProps: const PopupProps.menu(showSearchBox: false),
            decoratorProps: DropDownDecoratorProps(
              decoration: InputDecoration(
                labelText: 'Cüz seç',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.teal),
                ),
              ),
            ),
          ),
          if (_selectedCuz != null) ...[
            const SizedBox(height: 6),
            Text(
              '${_selectedCuz!.pageCount} sayfa kaydedilecek  (${_selectedCuz!.startPage}–${_selectedCuz!.endPage})',
              style: const TextStyle(
                  color: AppColors.teal, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ],
          if (_hatims.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('Hatimle ilişkilendir (opsiyonel):',
                style: TextStyle(color: AppColors.textMid, fontSize: 13)),
            const SizedBox(height: 8),
            _OptionalHatimChips(
              hatims: _hatims.where((h) => h.type == _globalType).toList(),
              selected: _cuzHatim,
              onChanged: (h) => setState(() => _cuzHatim = h),
            ),
          ],
        ],
      ),
    );
  }

  // ── Tab: Sure ───────────────────────────────────────────────────────

  Widget _buildSureTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownSearch<SurahInfo>(
            items: (filter, _) => QuranData.surahlar,
            itemAsString: (s) => '${s.id}. ${s.name}',
            compareFn: (a, b) => a.id == b.id,
            onSelected: (s) => setState(() => _selectedSurah = s),
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
                labelText: 'Sure seç',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.teal),
                ),
              ),
            ),
          ),
          if (_selectedSurah != null) ...[
            const SizedBox(height: 6),
            Text(
              _selectedSurah!.startPage == 0
                  ? 'Fâtiha — 1 sayfa kaydedilecek'
                  : '${_selectedSurah!.endPage - _selectedSurah!.startPage + 1} sayfa kaydedilecek  (${_selectedSurah!.startPage}–${_selectedSurah!.endPage})',
              style: const TextStyle(
                  color: AppColors.teal, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline, size: 13, color: AppColors.textLight),
              const SizedBox(width: 4),
              const Expanded(
                child: Text(
                  'Sure logları serbest kaydedilir — hatimle ilişkilendirilemez.',
                  style: TextStyle(color: AppColors.textLight, fontSize: 11),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────

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
              const Text('Okuma Kaydet',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark)),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.history, color: AppColors.textMid),
                    onPressed: () => LogHistorySheet.show(context),
                    tooltip: 'Kayıt geçmişi',
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Builder(builder: (context) {
            final tabIndex = _tabController.index;
            final bool isDevam = tabIndex == 0;
            final bool hasSayfaHatim = tabIndex == 1 && _sayfaHatim != null;
            final bool hasCuzHatim = tabIndex == 2 && _cuzHatim != null;
            final bool locked = isDevam || hasSayfaHatim || hasCuzHatim;
            HatimType displayType = _globalType;
            if (isDevam && _devamHatim != null) displayType = _devamHatim!.type;
            if (hasSayfaHatim) displayType = _sayfaHatim!.type;
            if (hasCuzHatim) displayType = _cuzHatim!.type;
            return _TypeToggle(
              selected: displayType,
              enabled: !locked,
              onChanged: (t) => setState(() {
                _globalType = t;
                if (_sayfaHatim?.type != t) _sayfaHatim = null;
                if (_cuzHatim?.type != t) _cuzHatim = null;
              }),
            );
          }),
          const SizedBox(height: 4),
          TabBar(
            controller: _tabController,
            labelColor: AppColors.teal,
            unselectedLabelColor: AppColors.textLight,
            indicatorColor: AppColors.teal,
            labelPadding: EdgeInsets.zero,
            onTap: (_) => setState(() {}),
            tabs: const [
              Tab(text: 'Devam'),
              Tab(text: 'Sayfa'),
              Tab(text: 'Cüz'),
              Tab(text: 'Sure'),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 260,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildDevamTab(),
                _buildSayfaTab(),
                _buildCuzTab(),
                _buildSureTab(),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SaveButton(isLoading: _isLoading, onPressed: _saveLog),
        ],
      ),
    );
  }
}

// ── Alt bileşenler ─────────────────────────────────────────────────────────────

class _HatimSelectCard extends StatelessWidget {
  final Hatim hatim;
  final bool isSelected;
  final String positionText;
  final String surahText;
  final VoidCallback onTap;

  const _HatimSelectCard({
    required this.hatim,
    required this.isSelected,
    required this.positionText,
    required this.surahText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isArapca = hatim.type == HatimType.arapca;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.tealLight : Colors.white,
          border: Border.all(
            color: isSelected ? AppColors.teal : AppColors.borderGrey,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.teal : AppColors.borderGrey,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isArapca ? Icons.menu_book : Icons.translate,
                color: isSelected ? Colors.white : AppColors.textMid,
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
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isSelected ? AppColors.teal : AppColors.textDark,
                    ),
                  ),
                  Text(positionText,
                      style: const TextStyle(color: AppColors.textMid, fontSize: 12)),
                  Text(surahText,
                      style: const TextStyle(color: AppColors.textLight, fontSize: 11)),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: AppColors.teal, size: 20),
          ],
        ),
      ),
    );
  }
}

class _OptionalHatimChips extends StatelessWidget {
  final List<Hatim> hatims;
  final Hatim? selected;
  final ValueChanged<Hatim?> onChanged;

  const _OptionalHatimChips({
    required this.hatims,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        _Chip(
          label: 'Serbest Okuma',
          icon: Icons.lock_open,
          isSelected: selected == null,
          onTap: () => onChanged(null),
        ),
        ...hatims.map((h) => _Chip(
              label: h.displayName,
              icon: h.type == HatimType.arapca ? Icons.menu_book : Icons.translate,
              isSelected: selected?.id == h.id,
              onTap: () => onChanged(h),
            )),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.tealLight : Colors.white,
          border: Border.all(
            color: isSelected ? AppColors.teal : AppColors.borderGrey,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: isSelected ? AppColors.teal : AppColors.textMid),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? AppColors.teal : AppColors.textMid,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeToggle extends StatelessWidget {
  final HatimType selected;
  final bool enabled;
  final ValueChanged<HatimType> onChanged;

  const _TypeToggle({required this.selected, required this.onChanged, this.enabled = true});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.55,
      child: SegmentedButton<HatimType>(
        segments: const [
          ButtonSegment(value: HatimType.arapca, label: Text('Arapça'), icon: Icon(Icons.menu_book)),
          ButtonSegment(value: HatimType.meal, label: Text('Meal'), icon: Icon(Icons.translate)),
        ],
        selected: {selected},
        onSelectionChanged: enabled ? (s) => onChanged(s.first) : null,
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected) ? AppColors.teal : Colors.transparent),
          foregroundColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected) ? Colors.white : AppColors.teal),
        ),
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onPressed;

  const _SaveButton({required this.isLoading, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.teal,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.borderGrey,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
          elevation: 0,
          padding: EdgeInsets.zero,
        ).copyWith(
          side: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) return null;
            return const BorderSide(color: AppColors.tealDark, width: 3);
          }),
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Text('KAYDET',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
      ),
    );
  }
}
