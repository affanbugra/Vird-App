import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dropdown_search/dropdown_search.dart';
import '../app_colors.dart';
import '../models/reading_log_model.dart';
import '../models/hatim_model.dart';
import '../data/quran_cuz.dart';
import '../utils/hatim_calculator.dart';
import '../utils/text_utils.dart';
import '../utils/seri_calculator.dart';
import 'duolingo_button.dart';

class LogEditSheet extends StatefulWidget {
  final ReadingLog log;
  final String uid;

  const LogEditSheet({super.key, required this.log, required this.uid});

  @override
  State<LogEditSheet> createState() => _LogEditSheetState();
}

class _LogEditSheetState extends State<LogEditSheet> {
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

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.errorRed),
    );
  }

  Future<void> _save() async {
    final log = widget.log;
    int newPagesRead;
    final Map<String, dynamic> updateData = {};

    switch (log.method) {
      case LogMethod.hatim:
        final rawPages = int.tryParse(_pagesCtrl.text) ?? 0;
        if (rawPages <= 0) {
          _showError('Sayfa sayısı 0\'dan büyük olmalı.');
          return;
        }
        if (log.startPage != null) {
          final newEnd = (log.startPage! + rawPages - 1).clamp(1, 604);
          newPagesRead = newEnd - log.startPage! + 1;
          updateData['startPage'] = log.startPage;
          updateData['endPage'] = newEnd;
        } else {
          newPagesRead = rawPages;
        }
        updateData['pagesRead'] = newPagesRead;
        break;

      case LogMethod.pages:
        final s = int.tryParse(_startCtrl.text) ?? 0;
        final e = int.tryParse(_endCtrl.text) ?? 0;
        if (s <= 0) { _showError('Başlangıç sayfası geçerli değil.'); return; }
        if (e <= 0) { _showError('Bitiş sayfası geçerli değil.'); return; }
        if (e > 604) { _showError('Bitiş sayfası 604\'ten büyük olamaz.'); return; }
        if (s > e) { _showError('Başlangıç sayfası bitiş sayfasından büyük olamaz.'); return; }
        newPagesRead = e - s + 1;
        updateData['startPage'] = s;
        updateData['endPage'] = e;
        updateData['pagesRead'] = newPagesRead;
        break;

      case LogMethod.cuz:
        if (_selectedCuz == null) return;
        newPagesRead = _selectedCuz!.pageCount;
        updateData['startPage'] = _selectedCuz!.startPage;
        updateData['endPage'] = _selectedCuz!.endPage;
        updateData['pagesRead'] = newPagesRead;
        break;

      case LogMethod.surah:
        if (_selectedSurah == null) return;
        newPagesRead = _selectedSurah!.startPage == 0
            ? 1
            : (_selectedSurah!.endPage - _selectedSurah!.startPage + 1);
        updateData['surahId'] = _selectedSurah!.id;
        updateData['startPage'] = _selectedSurah!.startPage;
        updateData['endPage'] = _selectedSurah!.endPage;
        updateData['pagesRead'] = newPagesRead;
        break;
    }

    setState(() => _loading = true);

    try {
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

      bool justCompleted = false;
      if (log.hatimId != null) {
        justCompleted = await HatimCalculator.recalculate(widget.uid, log.hatimId!);
      }
      await SeriCalculator.recalculate(widget.uid);

      if (!mounted) return;
      final overlayCtx = Navigator.of(context, rootNavigator: true).context;
      Navigator.pop(context);

      if (justCompleted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          showDialog<void>(
            context: overlayCtx,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🎉', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 12),
                  const Text('Hatim Tamamlandı',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 10),
                  const Text(
                    'Mâşallah! Bir hatmi tamamladınız. Allah kabul eylesin.',
                    style: TextStyle(fontSize: 15, color: AppColors.textMid),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.teal,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Âmin',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
          );
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kaydetme hatası: $e'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    }
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
                  () {
                    if (log.method == LogMethod.hatim && log.startPage != null) {
                      final originalEnd =
                          (log.startPage! + log.pagesRead - 1).clamp(1, 604);
                      return '$typeLabel · Sayfa ${log.startPage}–$originalEnd';
                    }
                    return '$typeLabel · $_methodLabel';
                  }(),
                  style: const TextStyle(fontSize: 12, color: AppColors.textMid),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Düzenlenebilir alan
          _buildEditField(log),

          const SizedBox(height: 20),

          // Kaydet
          SizedBox(
            height: 52,
            child: DuolingoButton(
              color: AppColors.teal,
              bottomColor: AppColors.tealDark,
              disabledColor: AppColors.borderGrey,
              onPressed: _loading ? null : _save,
              isLoading: _loading,
              child: const Text('KAYDET',
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
          textInputAction: TextInputAction.done,
          maxLength: 4,
          onSubmitted: (_) => _loading ? null : _save(),
          decoration: InputDecoration(
            labelText: 'Okunan sayfa sayısı',
            prefixIcon: const Icon(Icons.add),
            counterText: '',
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
                textInputAction: TextInputAction.next,
                maxLength: 4,
                decoration: InputDecoration(
                  labelText: 'Başlangıç',
                  counterText: '',
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
                textInputAction: TextInputAction.done,
                maxLength: 4,
                onSubmitted: (_) => _loading ? null : _save(),
                decoration: InputDecoration(
                  labelText: 'Bitiş',
                  counterText: '',
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
          filterFn: (s, filter) => turkishContains('${s.id}. ${s.name}', filter),
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
