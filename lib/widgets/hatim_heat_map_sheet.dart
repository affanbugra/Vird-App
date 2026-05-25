import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../app_colors.dart';
import '../app_theme.dart';
import '../models/hatim_model.dart';
import 'duolingo_button.dart';
import '../data/quran_cuz.dart';
import '../data/tilavet_secde.dart';
import '../models/reading_log_model.dart';
import 'log_edit_sheet.dart';
import '../utils/hatim_calculator.dart';
import '../utils/seri_calculator.dart';

String _fmtDate(DateTime dt) =>
    '${dt.day}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';

String _fmtDuration(DateTime start, DateTime end) {
  final days = end.difference(start).inDays;
  if (days < 30) return '$days gün';
  final months = days ~/ 30;
  final rem = days % 30;
  return rem == 0 ? '$months ay' : '$months ay $rem gün';
}

const _kReadColor = Color(0xFF38A474);

class HatimHeatMapSheet extends StatefulWidget {
  final Hatim hatim;
  final String uid;
  final VoidCallback? onDevamEt; // null = tamamlanan hatim, buton gösterilmez

  const HatimHeatMapSheet({
    super.key,
    required this.hatim,
    required this.uid,
    this.onDevamEt,
  });

  static Future<void> show(
    BuildContext context, {
    required Hatim hatim,
    required String uid,
    VoidCallback? onDevamEt,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => HatimHeatMapSheet(hatim: hatim, uid: uid, onDevamEt: onDevamEt),
    );
  }

  @override
  State<HatimHeatMapSheet> createState() => _HatimHeatMapSheetState();
}

class _HatimHeatMapSheetState extends State<HatimHeatMapSheet> {
  final ValueNotifier<int?> _selectedPage = ValueNotifier<int?>(null);

  /// page -> 'done' | 'pending' | null (not yet asked)
  Map<int, String> _secdeStatus = {};

  @override
  void initState() {
    super.initState();
    _loadSecdeStatus();
  }

  Future<void> _loadSecdeStatus() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .collection('logs')
          .doc('tilavet_secde_${widget.hatim.id}')
          .get();
      if (doc.exists && mounted) {
        final data = doc.data()!;
        final Map<int, String> status = {};
        (data['pages'] as Map<String, dynamic>? ?? {}).forEach((k, v) {
          status[int.parse(k)] = v as String;
        });
        setState(() => _secdeStatus = status);
      }
    } catch (e) {
      debugPrint('Secde load error: \$e');
    }
  }

  Future<void> _saveSecdeStatus(int page, String status) async {
    setState(() => _secdeStatus[page] = status);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .collection('logs')
          .doc('tilavet_secde_${widget.hatim.id}')
          .set({
        'hatimId': widget.hatim.id,
        'type': 'tilavet_secde',
        'pages': _secdeStatus.map((k, v) => MapEntry(k.toString(), v)),
      });
    } catch (e) {
      debugPrint('Secde save error: \$e');
    }
  }

  void _showSecdeDialog(int page) {
    final label = TilavetSecdeData.secdeLabel(page) ?? 'Tilavet Secdesi';
    final currentStatus = _secdeStatus[page];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🕌', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 12),
            Text(
              'Tilavet Secdesi',
              style: GoogleFonts.nunito(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: context.colors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '$label  (Sayfa $page)',
              style: GoogleFonts.nunito(fontSize: 13, color: context.colors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
                label: Text(
                  'Yaptım',
                  style: GoogleFonts.nunito(
                      color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  _saveSecdeStatus(page, 'done');
                },
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: Icon(Icons.access_time,
                    color: currentStatus == 'pending'
                        ? AppColors.errorRed
                        : context.colors.textSecondary,
                    size: 18),
                label: Text(
                  'Henüz Yapmadım',
                  style: GoogleFonts.nunito(
                    color: currentStatus == 'pending'
                        ? AppColors.errorRed
                        : context.colors.textSecondary,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: BorderSide(
                    color: currentStatus == 'pending'
                        ? AppColors.errorRed
                        : context.colors.border,
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  _saveSecdeStatus(page, 'pending');
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _selectedPage.dispose();
    super.dispose();
  }

  Set<int> _buildReadPages(List<QueryDocumentSnapshot> logs) {
    final Set<int> pages = {};
    for (final doc in logs) {
      final data = doc.data() as Map<String, dynamic>;
      final start = data['startPage'] as int?;
      final end = data['endPage'] as int?;
      if (start != null && end != null) {
        for (int p = start; p <= end && p <= 604; p++) {
          pages.add(p);
        }
      }
    }
    return pages;
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: context.colors.border,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            // Başlık
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 12, 0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: context.colors.tealSurface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      widget.hatim.type == HatimType.arapca
                          ? Icons.menu_book
                          : Icons.translate,
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
                          widget.hatim.displayName,
                          style: GoogleFonts.nunito(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: context.colors.textPrimary,
                          ),
                        ),
                        Text(
                          'Okuma haritası',
                          style: GoogleFonts.nunito(fontSize: 12, color: context.colors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: context.colors.textSecondary, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Divider(height: 16, color: context.colors.border),
            // İçerik
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(widget.uid)
                    .collection('logs')
                    .where('hatimId', isEqualTo: widget.hatim.id)
                    .snapshots(),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator(color: AppColors.teal));
                  }

                  final readPages = snap.hasData
                      ? _buildReadPages(snap.data!.docs)
                      : <int>{};

                  final readCount = readPages.where((p) => p >= 1).length;
                  final completedCuz = QuranData.cuzler.where((c) {
                    for (int p = c.startPage; p <= c.endPage; p++) {
                      if (!readPages.contains(p)) return false;
                    }
                    return true;
                  }).length;

                  // Tarihe göre sıralı dökümanlar (yeniden eskiye)
                  final sortedDocs = [...snap.data!.docs]..sort((a, b) {
                      final aT = (a.data() as Map)['createdAt'] as Timestamp?;
                      final bT = (b.data() as Map)['createdAt'] as Timestamp?;
                      if (aT == null || bT == null) return 0;
                      return bT.compareTo(aT);
                    });

                  return ListView(
                    controller: controller,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                    children: [
                      // DEVAM ET butonu (sadece aktif hatimler için)
                      if (widget.onDevamEt != null) ...[
                        DuolingoButton(
                          color: AppColors.teal,
                          bottomColor: AppColors.tealDark,
                          onPressed: () {
                            Navigator.pop(context);
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              widget.onDevamEt!();
                            });
                          },
                          child: Text(
                            'DEVAM ET',
                            style: GoogleFonts.nunito(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      // İstatistik şeridi
                      Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 16),
                        decoration: BoxDecoration(
                          color: context.colors.surfaceVariant,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _StatItem(value: '$readCount', label: 'SAYFA'),
                            Container(
                                width: 1, height: 28, color: context.colors.border),
                            _StatItem(value: '$completedCuz/30', label: 'CÜZ'),
                            Container(
                                width: 1, height: 28, color: context.colors.border),
                            _StatItem(value: '${604 - readCount}', label: 'KALAN'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      // Isı haritası + Lejant + Detay paneli
                      ValueListenableBuilder<int?>(
                        valueListenable: _selectedPage,
                        builder: (context, selectedPage, _) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _BinaryHeatGrid(
                                readPages: readPages,
                                selectedPage: selectedPage,
                                secdeStatus: _secdeStatus,
                                onPageTap: (p) => _selectedPage.value =
                                    _selectedPage.value == p ? null : p,
                                onSecdeTap: _showSecdeDialog,
                              ),
                              const SizedBox(height: 10),
                              // Lejant
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  _LegendDot(color: context.colors.border),
                                  const SizedBox(width: 4),
                                  Text('Okunmadı',
                                      style: GoogleFonts.nunito(
                                          fontSize: 10, color: context.colors.textSecondary)),
                                  const SizedBox(width: 12),
                                  _LegendDot(color: _kReadColor),
                                  const SizedBox(width: 4),
                                  Text('Okundu',
                                      style: GoogleFonts.nunito(
                                          fontSize: 10, color: context.colors.textSecondary)),
                                ],
                              ),
                              // Detay paneli
                              _DetailPanel(page: selectedPage, readPages: readPages),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      // Tarih bilgileri
                      _HatimDatesRow(hatim: widget.hatim),
                      // Son okumalar
                      if (sortedDocs.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Text(
                              'Son Okumalar',
                              style: GoogleFonts.nunito(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: context.colors.textPrimary,
                              ),
                            ),
                            const Spacer(),
                            GestureDetector(
                              onTap: () => _AllLogsSheet.show(
                                context,
                                uid: widget.uid,
                                hatimId: widget.hatim.id,
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: context.colors.surfaceVariant,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(Icons.settings_outlined,
                                    size: 14, color: context.colors.textSecondary),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ...sortedDocs
                            .take(3)
                            .map((doc) => _LogRow(doc: doc)),
                        if (sortedDocs.length > 3)
                          Align(
                            alignment: Alignment.centerRight,
                            child: GestureDetector(
                              onTap: () => _AllLogsSheet.show(
                                context,
                                uid: widget.uid,
                                hatimId: widget.hatim.id,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  'Tümünü gör (${sortedDocs.length})',
                                  style: GoogleFonts.nunito(
                                    fontSize: 12,
                                    color: AppColors.teal,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── İstatistik öğesi ────────────────────────────────────────────────────────

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  const _StatItem({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: GoogleFonts.nunito(
                fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.teal)),
        Text(label,
            style: GoogleFonts.nunito(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: context.colors.textTertiary,
                letterSpacing: 0.4)),
      ],
    );
  }
}

// ─── Lejant noktası ───────────────────────────────────────────────────────────

class _LegendDot extends StatelessWidget {
  final Color color;
  const _LegendDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
    );
  }
}

// ─── Detay paneli ─────────────────────────────────────────────────────────────

class _DetailPanel extends StatelessWidget {
  final int? page;
  final Set<int> readPages;
  const _DetailPanel({required this.page, required this.readPages});

  @override
  Widget build(BuildContext context) {
    if (page == null) {
      return Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: context.colors.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.colors.border),
        ),
        child: Text(
          'Detay için bir sayfaya dokun',
          style: GoogleFonts.nunito(fontSize: 11, color: context.colors.textTertiary),
        ),
      );
    }

    final p = page!;
    final surahText = p == 0 ? 'Fâtiha' : QuranData.surahsOnPage(p);
    final cuz = QuranData.cuzForPage(p);
    final pageLabel = p == 0 ? 'Fâtiha · Cüz 1' : 'Sayfa $p · Cüz ${cuz?.cuzNo ?? '?'}';
    final isRead = readPages.contains(p);

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: context.colors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pageLabel,
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: context.colors.textPrimary,
                  ),
                ),
                if (surahText.isNotEmpty)
                  Text(
                    surahText,
                    style: GoogleFonts.nunito(
                        fontSize: 11, color: context.colors.textSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isRead
                  ? _kReadColor.withValues(alpha: 0.12)
                  : context.colors.border,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              isRead ? 'Okundu' : 'Okunmadı',
              style: GoogleFonts.nunito(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isRead ? _kReadColor : context.colors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Binary Isı Haritası Grid ─────────────────────────────────────────────────

class _BinaryHeatGrid extends StatelessWidget {
  final Set<int> readPages;
  final int? selectedPage;
  final Map<int, String> secdeStatus;
  final ValueChanged<int> onPageTap;
  final ValueChanged<int> onSecdeTap;

  const _BinaryHeatGrid({
    required this.readPages,
    required this.selectedPage,
    required this.secdeStatus,
    required this.onPageTap,
    required this.onSecdeTap,
  });

  static const double _labelW = 14;
  static const double _labelGap = 5;
  static const double _squareGap = 2;
  static const int _maxPages = 20;

  static double _squareSize(double availableWidth) {
    final squaresArea = availableWidth - _labelW - _labelGap;
    return (squaresArea - _maxPages * _squareGap) / _maxPages;
  }

  Widget _square(BuildContext context, int page, double sq, double radius, {bool usePage1Color = false}) {
    final actualPage = usePage1Color ? 1 : page;
    final isRead = readPages.contains(actualPage);
    final isSelected = selectedPage == page;
    final hasSecde = TilavetSecdeData.hasSecde(page);
    final sStatus = hasSecde ? secdeStatus[page] : null;

    // Köşe rozet rengi — okunmamış sayfada secde durumu gösterilmez
    Color? badgeColor;
    if (hasSecde) {
      if (!isRead) {
        badgeColor = context.colors.textTertiary;
      } else if (sStatus == 'done') {
        badgeColor = AppColors.gold;
      } else if (sStatus == 'pending') {
        badgeColor = AppColors.errorRed;
      } else {
        badgeColor = context.colors.textTertiary;
      }
    }

    final badgeSize = (sq * 0.32).clamp(3.5, 6.0);

    return GestureDetector(
      onTap: () {
        onPageTap(page);
        if (hasSecde && isRead) onSecdeTap(page);
      },
      child: Stack(
        children: [
          Container(
            width: sq,
            height: sq,
            margin: const EdgeInsets.only(right: _squareGap),
            decoration: BoxDecoration(
              color: isRead ? _kReadColor : context.colors.border,
              borderRadius: BorderRadius.circular(radius),
              border: isSelected ? Border.all(color: context.colors.textPrimary, width: 1.5) : null,
            ),
          ),
          if (hasSecde)
            Positioned(
              top: 1,
              right: _squareGap + 1,
              child: Container(
                width: badgeSize,
                height: badgeSize,
                decoration: BoxDecoration(
                  color: badgeColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.8),
                    width: 0.8,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final sq = _squareSize(constraints.maxWidth);
        final radius = (sq * 0.22).clamp(1.5, 4.0);

        final labelStyle = GoogleFonts.nunito(
          fontSize: 8,
          fontWeight: FontWeight.w700,
          color: context.colors.textTertiary,
        );

        final rows = <Widget>[];

        // Bekleyen tilavet secdesi sayısı — sadece okunmuş sayfalardaki 'pending'ler
        final pendingCount = secdeStatus.entries
            .where((e) => e.value == 'pending' && readPages.contains(e.key))
            .length;

        rows.add(Padding(
          padding: const EdgeInsets.only(bottom: _squareGap),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(width: _labelW + _labelGap),
              _square(context, 0, sq, radius, usePage1Color: true),
              const SizedBox(width: 5),
              Text('Fâtiha', style: labelStyle),
              const Spacer(),
              if (pendingCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.errorRed.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: AppColors.errorRed.withValues(alpha: 0.5),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 5,
                        height: 5,
                        decoration: const BoxDecoration(
                          color: AppColors.errorRed,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '$pendingCount tamamlanmayan secde',
                        style: GoogleFonts.nunito(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: AppColors.errorRed,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ));

        // Cüz 1–29
        for (final cuz in QuranData.cuzler) {
          if (cuz.cuzNo < 30) {
            rows.add(Padding(
              padding: const EdgeInsets.only(bottom: _squareGap),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: _labelW,
                    child: Text('${cuz.cuzNo}',
                        textAlign: TextAlign.right, style: labelStyle),
                  ),
                  const SizedBox(width: _labelGap),
                  ...List.generate(
                      cuz.pageCount, (i) => _square(context, cuz.startPage + i, sq, radius)),
                ],
              ),
            ));
          } else {
            // Cüz 30 — satır 1
            rows.add(Padding(
              padding: const EdgeInsets.only(bottom: _squareGap),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: _labelW,
                    child: Text('30', textAlign: TextAlign.right, style: labelStyle),
                  ),
                  const SizedBox(width: _labelGap),
                  ...List.generate(20, (i) => _square(context, 581 + i, sq, radius)),
                ],
              ),
            ));
            // Cüz 30 — satır 2
            rows.add(Padding(
              padding: const EdgeInsets.only(bottom: _squareGap),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(width: _labelW + _labelGap),
                  ...List.generate(4, (i) => _square(context, 601 + i, sq, radius)),
                  const SizedBox(width: 3),
                  Text('İhlâs · Felak · Nâs', style: labelStyle),
                ],
              ),
            ));
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: rows,
        );
      },
    );
  }
}

// ─── Tarih satırı ─────────────────────────────────────────────────────────────

class _HatimDatesRow extends StatelessWidget {
  final Hatim hatim;
  const _HatimDatesRow({required this.hatim});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        _DateChip(icon: Icons.play_arrow_rounded, label: 'Başlangıç: ${_fmtDate(hatim.createdAt)}'),
        if (hatim.completedAt != null) ...[
          _DateChip(icon: Icons.check_circle_outline, label: 'Bitiş: ${_fmtDate(hatim.completedAt!)}'),
          _DateChip(
            icon: Icons.timer_outlined,
            label: _fmtDuration(hatim.createdAt, hatim.completedAt!),
          ),
        ],
      ],
    );
  }
}

class _DateChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _DateChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: context.colors.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: context.colors.textSecondary),
          const SizedBox(width: 4),
          Text(label,
              style: GoogleFonts.nunito(fontSize: 11, color: context.colors.textSecondary)),
        ],
      ),
    );
  }
}

// ─── Log satırı (özet) ────────────────────────────────────────────────────────

class _LogRow extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  const _LogRow({required this.doc});

  @override
  Widget build(BuildContext context) {
    final data = doc.data() as Map<String, dynamic>;
    final startPage = data['startPage'] as int?;
    final endPage = data['endPage'] as int?;
    final pagesRead = data['pagesRead'] as int? ?? 0;
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    final method = data['method'] as String? ?? '';

    final pageText = (startPage != null && endPage != null)
        ? '$startPage–$endPage. sayfa'
        : '$pagesRead sayfa';
    final dateText = createdAt != null ? _fmtDate(createdAt) : '';

    final icon = method == 'hatim'
        ? Icons.bookmark_border
        : method == 'cuz'
            ? Icons.pie_chart_outline
            : method == 'surah'
                ? Icons.menu_book_outlined
                : Icons.article_outlined;

    return Container(
      margin: const EdgeInsets.only(bottom: 5),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: context.colors.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 13, color: context.colors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(pageText,
                style: GoogleFonts.nunito(fontSize: 12, color: context.colors.textPrimary)),
          ),
          Text('$pagesRead sy.',
              style: GoogleFonts.nunito(fontSize: 11, color: context.colors.textSecondary)),
          if (dateText.isNotEmpty) ...[
            const SizedBox(width: 8),
            Text(dateText,
                style: GoogleFonts.nunito(fontSize: 10, color: context.colors.textTertiary)),
          ],
        ],
      ),
    );
  }
}

// ─── Tüm okumalar sayfası ─────────────────────────────────────────────────────

class _AllLogsSheet extends StatefulWidget {
  final String uid;
  final String hatimId;

  const _AllLogsSheet({required this.uid, required this.hatimId});

  static Future<void> show(BuildContext context,
      {required String uid, required String hatimId}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AllLogsSheet(uid: uid, hatimId: hatimId),
    );
  }

  @override
  State<_AllLogsSheet> createState() => _AllLogsSheetState();
}

class _AllLogsSheetState extends State<_AllLogsSheet> {
  Future<void> _deleteLog(QueryDocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;
    final pagesRead = data['pagesRead'] as int? ?? 0;
    try {
      final batch = FirebaseFirestore.instance.batch();
      batch.delete(doc.reference);
      batch.update(
        FirebaseFirestore.instance.collection('users').doc(widget.uid),
        {
          'hasanat': FieldValue.increment(-(pagesRead * 10)),
          'totalPages': FieldValue.increment(-pagesRead),
        },
      );
      await batch.commit();

      final hatimId = data['hatimId'] as String?;
      if (hatimId != null) {
        await HatimCalculator.recalculate(widget.uid, hatimId);
      }
      await SeriCalculator.recalculate(widget.uid);
    } catch (e) {
      debugPrint('Log sil hatası: $e');
    }
  }

  Future<void> _confirmAndDelete(BuildContext context, QueryDocumentSnapshot doc) async {
    // Seri etkisini önceden hesapla
    int currentSeri = 0;
    int? newSeri;
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users').doc(widget.uid).get();
      final stored = (userDoc.data()?['seri'] as int?) ?? 0;
      final lastLogTs = userDoc.data()?['lastLogDate'] as Timestamp?;
      currentSeri = seriDisplayState(stored, lastLogTs).value;
      if (currentSeri > 0) {
        newSeri = await SeriCalculator.simulateWithoutLog(widget.uid, doc.id);
      }
    } catch (_) {}

    final seriDrops = newSeri != null && newSeri < currentSeri;
    if (!context.mounted) return;

    final pagesRead =
        (doc.data() as Map<String, dynamic>)['pagesRead'] as int? ?? 0;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          seriDrops ? '🔥 Seri Etkilenecek' : 'Kaydı sil',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (seriDrops) ...[
              RichText(
                text: TextSpan(
                  style: TextStyle(
                      color: context.colors.textSecondary, fontSize: 14),
                  children: [
                    const TextSpan(text: 'Seriniz '),
                    TextSpan(
                      text: '$currentSeri gün',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: context.colors.textPrimary),
                    ),
                    const TextSpan(text: '\'den '),
                    TextSpan(
                      text: '$newSeri gün',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: newSeri == 0
                            ? AppColors.errorRed
                            : AppColors.orange,
                      ),
                    ),
                    const TextSpan(text: '\'e düşecek.'),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
            Text(
              'Bu okuma kaydı silinsin mi?\nHasanat ${pagesRead * 10} geri alınacak.',
              style: TextStyle(color: context.colors.textSecondary),
            ),
            if (seriDrops) ...[
              const SizedBox(height: 8),
              const Text(
                'Bu işlem geri alınamaz.',
                style: TextStyle(
                    color: AppColors.errorRed,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('İptal',
                style: TextStyle(color: context.colors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.errorRed,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              seriDrops ? 'Yine de Sil' : 'Sil',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    ) ?? false;
    if (confirmed) await _deleteLog(doc);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: context.colors.border,
                  borderRadius: BorderRadius.circular(999)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 12, 0),
              child: Row(
                children: [
                  Text('Okuma Geçmişi',
                      style: GoogleFonts.nunito(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: context.colors.textPrimary)),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close,
                        color: context.colors.textSecondary, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Divider(height: 16, color: context.colors.border),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(widget.uid)
                    .collection('logs')
                    .where('hatimId', isEqualTo: widget.hatimId)
                    .snapshots(),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator(color: AppColors.teal));
                  }
                  final docs = (snap.data?.docs ?? []).where((d) {
                    final t = (d.data() as Map<String, dynamic>)['type'] as String?;
                    return t == 'arapca' || t == 'meal';
                  }).toList()
                    ..sort((a, b) {
                      final aT = (a.data() as Map)['createdAt'] as Timestamp?;
                      final bT = (b.data() as Map)['createdAt'] as Timestamp?;
                      if (aT == null || bT == null) return 0;
                      return bT.compareTo(aT);
                    });

                  if (docs.isEmpty) {
                    return Center(
                      child: Text('Henüz okuma kaydı yok.',
                          style: GoogleFonts.nunito(color: context.colors.textSecondary)),
                    );
                  }

                  return ListView.separated(
                    controller: controller,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                    itemCount: docs.length,
                    separatorBuilder: (_, _) =>
                        Divider(height: 1, color: context.colors.border),
                    itemBuilder: (context, i) {
                      final doc = docs[i];
                      return _LogRowDetailed(
                        doc: doc,
                        uid: widget.uid,
                        onDelete: () => _confirmAndDelete(context, doc),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LogRowDetailed extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  final String uid;
  final VoidCallback onDelete;

  const _LogRowDetailed({
    required this.doc,
    required this.uid,
    required this.onDelete,
  });

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

  @override
  Widget build(BuildContext context) {
    final log = ReadingLog.fromFirestore(doc);

    final title = switch (log.method) {
      LogMethod.hatim => '+${log.pagesRead} sayfa devam',
      LogMethod.pages => '${log.startPage}–${log.endPage}. sayfalar',
      LogMethod.cuz => () {
          final cuz = QuranData.cuzler
              .where((c) => c.startPage == log.startPage)
              .firstOrNull;
          return cuz != null ? '${cuz.cuzNo}. Cüz' : '${log.pagesRead} sayfa';
        }(),
      LogMethod.surah => () {
          final surah = log.surahId != null
              ? QuranData.surahlar.where((s) => s.id == log.surahId).firstOrNull
              : null;
          return surah?.name ?? '${log.pagesRead} sayfa';
        }(),
    };

    final typeLabel = log.type == HatimType.arapca ? 'Arapça' : 'Meal';
    final iconColor = log.method == LogMethod.hatim ? AppColors.orange : AppColors.teal;
    final icon = switch (log.method) {
      LogMethod.hatim => Icons.bookmark_border,
      LogMethod.pages => Icons.article_outlined,
      LogMethod.cuz => Icons.pie_chart_outline,
      LogMethod.surah => Icons.menu_book_outlined,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: context.colors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: context.colors.tealSurface,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        typeLabel,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppColors.teal,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${_timeText(log.createdAt)} · +${log.pagesRead * 10} ✨',
                  style: TextStyle(fontSize: 12, color: context.colors.textTertiary),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: AppColors.teal, size: 20),
            onPressed: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => Padding(
                padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom),
                child: LogEditSheet(log: log, uid: uid),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.errorRed, size: 20),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

