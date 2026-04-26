import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../app_colors.dart';
import '../models/hatim_model.dart';
import '../data/quran_cuz.dart';

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
  int? _selectedPage;

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
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderGrey,
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
                      color: AppColors.tealLight,
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
                            color: AppColors.textDark,
                          ),
                        ),
                        Text(
                          'Okuma haritası',
                          style: GoogleFonts.nunito(fontSize: 12, color: AppColors.textMid),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.textMid, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 16, color: AppColors.borderGrey),
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
                        SizedBox(
                          height: 44,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                widget.onDevamEt!();
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.teal,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(999)),
                              elevation: 0,
                            ).copyWith(
                              side: WidgetStateProperty.all(
                                  const BorderSide(color: AppColors.tealDark, width: 3)),
                            ),
                            child: Text(
                              'DEVAM ET',
                              style: GoogleFonts.nunito(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
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
                          color: AppColors.lightGrey,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _StatItem(value: '$readCount', label: 'SAYFA'),
                            Container(
                                width: 1, height: 28, color: AppColors.borderGrey),
                            _StatItem(value: '$completedCuz/30', label: 'CÜZ'),
                            Container(
                                width: 1, height: 28, color: AppColors.borderGrey),
                            _StatItem(value: '${604 - readCount}', label: 'KALAN'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      // Isı haritası
                      _BinaryHeatGrid(
                        readPages: readPages,
                        selectedPage: _selectedPage,
                        onPageTap: (p) => setState(() =>
                            _selectedPage = _selectedPage == p ? null : p),
                      ),
                      const SizedBox(height: 10),
                      // Lejant
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          _LegendDot(color: AppColors.borderGrey),
                          const SizedBox(width: 4),
                          Text('Okunmadı',
                              style: GoogleFonts.nunito(
                                  fontSize: 10, color: AppColors.textMid)),
                          const SizedBox(width: 12),
                          _LegendDot(color: _kReadColor),
                          const SizedBox(width: 4),
                          Text('Okundu',
                              style: GoogleFonts.nunito(
                                  fontSize: 10, color: AppColors.textMid)),
                        ],
                      ),
                      // Detay paneli
                      if (_selectedPage != null)
                        _DetailPanel(page: _selectedPage!, readPages: readPages),
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
                                color: AppColors.textDark,
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
                                  color: AppColors.lightGrey,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.settings_outlined,
                                    size: 14, color: AppColors.textMid),
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
                color: AppColors.textLight,
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
  final int page;
  final Set<int> readPages;
  const _DetailPanel({required this.page, required this.readPages});

  @override
  Widget build(BuildContext context) {
    final surahText = page == 0
        ? 'Fâtiha'
        : QuranData.surahsOnPage(page);
    final isRead = readPages.contains(page);

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.lightGrey,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderGrey),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  page == 0 ? 'Fâtiha' : '$page. sayfa',
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
                Text(
                  surahText,
                  style: GoogleFonts.nunito(
                      fontSize: 11, color: AppColors.textMid),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isRead
                  ? _kReadColor.withValues(alpha: 0.12)
                  : AppColors.borderGrey,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              isRead ? 'Okundu' : 'Okunmadı',
              style: GoogleFonts.nunito(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isRead ? _kReadColor : AppColors.textMid,
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
  final ValueChanged<int> onPageTap;

  const _BinaryHeatGrid({
    required this.readPages,
    required this.selectedPage,
    required this.onPageTap,
  });

  static const double _labelW = 14;
  static const double _labelGap = 5;
  static const double _squareGap = 2;
  static const int _maxPages = 20;

  static double _squareSize(double availableWidth) {
    final squaresArea = availableWidth - _labelW - _labelGap;
    return (squaresArea - _maxPages * _squareGap) / _maxPages;
  }

  Widget _square(int page, double sq, double radius, {bool usePage1Color = false}) {
    final isRead = readPages.contains(usePage1Color ? 1 : page);
    final isSelected = selectedPage == page;
    return GestureDetector(
      onTap: () => onPageTap(page),
      child: Container(
        width: sq,
        height: sq,
        margin: const EdgeInsets.only(right: _squareGap),
        decoration: BoxDecoration(
          color: isRead ? _kReadColor : AppColors.borderGrey,
          borderRadius: BorderRadius.circular(radius),
          border: isSelected ? Border.all(color: AppColors.textDark, width: 1.5) : null,
        ),
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
          color: AppColors.textLight,
        );

        final rows = <Widget>[];

        // Fatiha — rengi page 1 ile aynı
        rows.add(Padding(
          padding: const EdgeInsets.only(bottom: _squareGap),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(width: _labelW + _labelGap),
              _square(0, sq, radius, usePage1Color: true),
              const SizedBox(width: 5),
              Text('Fâtiha', style: labelStyle),
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
                      cuz.pageCount, (i) => _square(cuz.startPage + i, sq, radius)),
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
                  ...List.generate(20, (i) => _square(581 + i, sq, radius)),
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
                  ...List.generate(4, (i) => _square(601 + i, sq, radius)),
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
        color: AppColors.lightGrey,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderGrey),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: AppColors.textMid),
          const SizedBox(width: 4),
          Text(label,
              style: GoogleFonts.nunito(fontSize: 11, color: AppColors.textMid)),
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
        ? Icons.arrow_forward
        : method == 'cuz'
            ? Icons.layers_outlined
            : Icons.menu_book_outlined;

    return Container(
      margin: const EdgeInsets.only(bottom: 5),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.lightGrey,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 13, color: AppColors.textMid),
          const SizedBox(width: 8),
          Expanded(
            child: Text(pageText,
                style: GoogleFonts.nunito(fontSize: 12, color: AppColors.textDark)),
          ),
          Text('$pagesRead sy.',
              style: GoogleFonts.nunito(fontSize: 11, color: AppColors.textMid)),
          if (dateText.isNotEmpty) ...[
            const SizedBox(width: 8),
            Text(dateText,
                style: GoogleFonts.nunito(fontSize: 10, color: AppColors.textLight)),
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
  final Set<String> _deletingIds = {};

  Future<void> _deleteLog(QueryDocumentSnapshot doc) async {
    setState(() => _deletingIds.add(doc.id));
    final data = doc.data() as Map<String, dynamic>;
    final pagesRead = data['pagesRead'] as int? ?? 0;
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
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: AppColors.borderGrey,
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
                          color: AppColors.textDark)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close,
                        color: AppColors.textMid, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 16, color: AppColors.borderGrey),
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
                  final docs = ((snap.data?.docs ?? [])
                        .where((d) => !_deletingIds.contains(d.id))
                        .toList())
                      ..sort((a, b) {
                        final aT = (a.data() as Map)['createdAt'] as Timestamp?;
                        final bT = (b.data() as Map)['createdAt'] as Timestamp?;
                        if (aT == null || bT == null) return 0;
                        return bT.compareTo(aT);
                      });

                  if (docs.isEmpty) {
                    return Center(
                      child: Text('Henüz okuma kaydı yok.',
                          style: GoogleFonts.nunito(color: AppColors.textMid)),
                    );
                  }

                  return ListView.builder(
                    controller: controller,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                    itemCount: docs.length,
                    itemBuilder: (context, i) {
                      final doc = docs[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Dismissible(
                          key: ValueKey(doc.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            decoration: BoxDecoration(
                                color: AppColors.errorRed,
                                borderRadius: BorderRadius.circular(10)),
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 16),
                            child: const Icon(Icons.delete_outline,
                                color: Colors.white, size: 20),
                          ),
                          confirmDismiss: (_) async {
                            return await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16)),
                                title: const Text('Kaydı sil',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                                content: const Text(
                                  'Bu okuma kaydı silinsin mi?\nHasanat ve toplam sayfa güncellenir.',
                                  style: TextStyle(color: AppColors.textMid),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(ctx, false),
                                    child: const Text('İptal',
                                        style: TextStyle(
                                            color: AppColors.textMid)),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.errorRed,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8)),
                                    ),
                                    onPressed: () =>
                                        Navigator.pop(ctx, true),
                                    child: const Text('Sil',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            ) ??
                                false;
                          },
                          onDismissed: (_) => _deleteLog(doc),
                          child: _LogRowDetailed(doc: doc),
                        ),
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
  const _LogRowDetailed({required this.doc});

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
        ? Icons.arrow_forward
        : method == 'cuz'
            ? Icons.layers_outlined
            : Icons.menu_book_outlined;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.lightGrey,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 14, color: AppColors.textMid),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(pageText,
                    style: GoogleFonts.nunito(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark)),
                if (dateText.isNotEmpty)
                  Text(dateText,
                      style: GoogleFonts.nunito(
                          fontSize: 11, color: AppColors.textLight)),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.tealLight,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text('$pagesRead sy.',
                style: GoogleFonts.nunito(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.teal)),
          ),
        ],
      ),
    );
  }
}
