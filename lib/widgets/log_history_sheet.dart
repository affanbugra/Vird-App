import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:dropdown_search/dropdown_search.dart';
import '../app_colors.dart';
import '../models/reading_log_model.dart';
import '../models/hatim_model.dart';
import '../data/quran_cuz.dart';

class LogHistorySheet {
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _LogHistoryContent(),
    );
  }
}

// ── Ana içerik ────────────────────────────────────────────────────────────────

class _LogHistoryContent extends StatelessWidget {
  const _LogHistoryContent();

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.68,
        child: Scaffold(
          backgroundColor: AppColors.white,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 8, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Son Kayıtlar',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Liste
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(uid)
                      .collection('logs')
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(
                          child: CircularProgressIndicator(color: AppColors.teal));
                    }
                    final docs = snap.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.history, size: 52, color: AppColors.borderGrey),
                            SizedBox(height: 12),
                            Text('Henüz kayıt yok.',
                                style: TextStyle(color: AppColors.textMid)),
                          ],
                        ),
                      );
                    }
                    final logs = docs
                        .map((d) => ReadingLog.fromFirestore(d))
                        .toList();
                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemCount: logs.length,
                      separatorBuilder: (ctx, i) =>
                          const Divider(height: 1, color: AppColors.borderGrey),
                      itemBuilder: (context, i) => _LogTile(
                        log: logs[i],
                        uid: uid,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Log satırı ────────────────────────────────────────────────────────────────

class _LogTile extends StatelessWidget {
  final ReadingLog log;
  final String uid;

  const _LogTile({required this.log, required this.uid});

  String get _title {
    switch (log.method) {
      case LogMethod.hatim:
        return '+${log.pagesRead} sayfa devam';
      case LogMethod.pages:
        return '${log.startPage}–${log.endPage}. sayfalar';
      case LogMethod.cuz:
        final cuz = QuranData.cuzler
            .where((c) => c.startPage == log.startPage)
            .firstOrNull;
        return cuz != null ? '${cuz.cuzNo}. Cüz' : '${log.pagesRead} sayfa';
      case LogMethod.surah:
        final surah = log.surahId != null
            ? QuranData.surahlar
                .where((s) => s.id == log.surahId)
                .firstOrNull
            : null;
        return surah?.name ?? '${log.pagesRead} sayfa';
    }
  }

  String get _typeLabel =>
      log.type == HatimType.arapca ? 'Arapça' : 'Meal';

  IconData get _icon {
    switch (log.method) {
      case LogMethod.hatim:
        return Icons.bookmark;
      case LogMethod.pages:
        return Icons.description_outlined;
      case LogMethod.cuz:
        return Icons.layers_outlined;
      case LogMethod.surah:
        return Icons.menu_book_outlined;
    }
  }

  Color get _iconColor =>
      log.method == LogMethod.hatim ? AppColors.orange : AppColors.teal;

  String _timeText(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Az önce';
    if (diff.inMinutes < 60) return '${diff.inMinutes} dk önce';
    if (diff.inHours < 24) return '${diff.inHours} sa önce';
    final today = DateTime(now.year, now.month, now.day);
    final logDay = DateTime(dt.year, dt.month, dt.day);
    final dayDiff = today.difference(logDay).inDays;
    if (dayDiff == 1) return 'Dün';
    if (dayDiff < 7) return '$dayDiff gün önce';
    return '${dt.day}.${dt.month}.${dt.year}';
  }

  Future<void> _delete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Kaydı sil',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
          '"$_title" silinsin mi?\nHasanat ${log.pagesRead * 10} geri alınacak.',
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
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final batch = FirebaseFirestore.instance.batch();
    batch.delete(FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('logs')
        .doc(log.id));
    batch.update(
      FirebaseFirestore.instance.collection('users').doc(uid),
      {
        'hasanat': FieldValue.increment(-(log.pagesRead * 10)),
        'totalPages': FieldValue.increment(-log.pagesRead),
      },
    );
    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          // İkon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_icon, color: _iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          // Metin
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        _title,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppColors.textDark),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    _TypeBadge(label: _typeLabel),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${_timeText(log.createdAt)} · +${log.pagesRead * 10} ✨',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textLight),
                ),
              ],
            ),
          ),
          // Aksiyonlar
          IconButton(
            icon: const Icon(Icons.edit_outlined,
                color: AppColors.teal, size: 20),
            onPressed: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => Padding(
                padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom),
                child: _LogEditSheet(log: log, uid: uid),
              ),
            ),
            tooltip: 'Düzenle',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline,
                color: AppColors.errorRed, size: 20),
            onPressed: () => _delete(context),
            tooltip: 'Sil',
          ),
        ],
      ),
    );
  }
}

// ── Tip badge ─────────────────────────────────────────────────────────────────

class _TypeBadge extends StatelessWidget {
  final String label;
  const _TypeBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.tealLight,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: AppColors.teal),
      ),
    );
  }
}

// ── Düzenleme sheet ───────────────────────────────────────────────────────────

class _LogEditSheet extends StatefulWidget {
  final ReadingLog log;
  final String uid;

  const _LogEditSheet({required this.log, required this.uid});

  @override
  State<_LogEditSheet> createState() => _LogEditSheetState();
}

class _LogEditSheetState extends State<_LogEditSheet> {
  // hatim
  late final TextEditingController _pagesCtrl;

  // pages
  late final TextEditingController _startCtrl;
  late final TextEditingController _endCtrl;

  // cuz
  CuzInfo? _selectedCuz;

  // surah
  SurahInfo? _selectedSurah;

  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final log = widget.log;

    _pagesCtrl = TextEditingController(text: '${log.pagesRead}');
    _startCtrl = TextEditingController(text: '${log.startPage ?? ''}');
    _endCtrl = TextEditingController(text: '${log.endPage ?? ''}');

    if (log.method == LogMethod.cuz && log.startPage != null) {
      _selectedCuz = QuranData.cuzler
          .where((c) => c.startPage == log.startPage)
          .firstOrNull;
    }
    if (log.method == LogMethod.surah && log.surahId != null) {
      _selectedSurah = QuranData.surahlar
          .where((s) => s.id == log.surahId)
          .firstOrNull;
    }
  }

  @override
  void dispose() {
    _pagesCtrl.dispose();
    _startCtrl.dispose();
    _endCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final log = widget.log;
    int newPagesRead;
    final Map<String, dynamic> updateData = {};

    switch (log.method) {
      case LogMethod.hatim:
        newPagesRead = int.tryParse(_pagesCtrl.text) ?? log.pagesRead;
        if (newPagesRead <= 0) return;
        updateData['pagesRead'] = newPagesRead;

      case LogMethod.pages:
        final s = int.tryParse(_startCtrl.text) ?? 0;
        final e = int.tryParse(_endCtrl.text) ?? 0;
        if (s <= 0 || e <= 0 || s > e || e > 604) return;
        newPagesRead = e - s + 1;
        updateData['startPage'] = s;
        updateData['endPage'] = e;
        updateData['pagesRead'] = newPagesRead;

      case LogMethod.cuz:
        if (_selectedCuz == null) return;
        newPagesRead = _selectedCuz!.pageCount;
        updateData['startPage'] = _selectedCuz!.startPage;
        updateData['endPage'] = _selectedCuz!.endPage;
        updateData['pagesRead'] = newPagesRead;

      case LogMethod.surah:
        if (_selectedSurah == null) return;
        newPagesRead = _selectedSurah!.startPage == 0
            ? 1
            : (_selectedSurah!.endPage - _selectedSurah!.startPage + 1);
        updateData['surahId'] = _selectedSurah!.id;
        updateData['startPage'] = _selectedSurah!.startPage;
        updateData['endPage'] = _selectedSurah!.endPage;
        updateData['pagesRead'] = newPagesRead;
    }

    setState(() => _loading = true);

    final diff = newPagesRead - log.pagesRead;
    final batch = FirebaseFirestore.instance.batch();

    batch.update(
      FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .collection('logs')
          .doc(log.id),
      updateData,
    );

    if (diff != 0) {
      batch.update(
        FirebaseFirestore.instance.collection('users').doc(widget.uid),
        {
          'hasanat': FieldValue.increment(diff * 10),
          'totalPages': FieldValue.increment(diff),
        },
      );
    }

    await batch.commit();
    if (mounted) Navigator.pop(context);
  }

  String get _methodLabel {
    switch (widget.log.method) {
      case LogMethod.hatim:
        return 'Hatim devam';
      case LogMethod.pages:
        return 'Sayfa aralığı';
      case LogMethod.cuz:
        return 'Cüz';
      case LogMethod.surah:
        return 'Sure';
    }
  }

  @override
  Widget build(BuildContext context) {
    final log = widget.log;
    final typeLabel = log.type == HatimType.arapca ? 'Arapça' : 'Meal';

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
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Kaydı Düzenle',
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
          const SizedBox(height: 4),

          // Kayıt bilgisi (salt okunur)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.lightGrey,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline,
                    size: 14, color: AppColors.textLight),
                const SizedBox(width: 6),
                Text(
                  '$typeLabel · $_methodLabel',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textMid),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Düzenlenebilir alan
          _buildEditField(log),

          // Hatim notu
          if (log.method == LogMethod.hatim) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.warning_amber_outlined,
                    size: 13, color: AppColors.textLight),
                const SizedBox(width: 4),
                const Expanded(
                  child: Text(
                    'Hatim ilerlemesi güncellenmez, yalnızca hasanat düzeltilir.',
                    style: TextStyle(
                        fontSize: 11, color: AppColors.textLight),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 20),

          // Kaydet
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _loading ? null : _save,
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
                  return const BorderSide(
                      color: AppColors.tealDark, width: 3);
                }),
              ),
              child: _loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('KAYDET',
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

  Widget _buildEditField(ReadingLog log) {
    switch (log.method) {
      case LogMethod.hatim:
        return TextField(
          controller: _pagesCtrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Okunan sayfa sayısı',
            prefixIcon: const Icon(Icons.add),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.teal),
            ),
          ),
        );

      case LogMethod.pages:
        return Row(
          children: [
            Expanded(
              child: TextField(
                controller: _startCtrl,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Başlangıç',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
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
                controller: _endCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Bitiş',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.teal),
                  ),
                ),
              ),
            ),
          ],
        );

      case LogMethod.cuz:
        return DropdownSearch<CuzInfo>(
          items: (filter, _) => QuranData.cuzler,
          itemAsString: (c) =>
              '${c.cuzNo}. Cüz  (${c.startPage}–${c.endPage}. sayfa)',
          compareFn: (a, b) => a.cuzNo == b.cuzNo,
          selectedItem: _selectedCuz,
          onSelected: (c) => setState(() => _selectedCuz = c),
          popupProps: const PopupProps.menu(showSearchBox: false),
          decoratorProps: DropDownDecoratorProps(
            decoration: InputDecoration(
              labelText: 'Cüz seç',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.teal),
              ),
            ),
          ),
        );

      case LogMethod.surah:
        return DropdownSearch<SurahInfo>(
          items: (filter, _) => QuranData.surahlar,
          itemAsString: (s) => '${s.id}. ${s.name}',
          compareFn: (a, b) => a.id == b.id,
          selectedItem: _selectedSurah,
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
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.teal),
              ),
            ),
          ),
        );
    }
  }
}
