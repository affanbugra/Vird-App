import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../app_colors.dart';
import '../app_assets.dart';
import '../data/roadmap_entry.dart';

// ─── Public yardımcı: roadmap sheet'ini herhangi bir context'ten aç ──────────
Future<void> showRoadmapSheet(BuildContext context) async {
  final snap = await FirebaseFirestore.instance
      .collection('roadmap_entries')
      .orderBy('order')
      .get();
  final entries = snap.docs.map(RoadmapEntry.fromDoc).toList();
  if (!context.mounted) return;
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _RoadmapSheet(allEntries: entries),
  );
}

// ─── Ana ekran ─────────────────────────────────────────────────────────────
class VirdScreen extends StatefulWidget {
  const VirdScreen({super.key});
  @override
  State<VirdScreen> createState() => _VirdScreenState();
}

class _VirdScreenState extends State<VirdScreen> {
  final _controller = TextEditingController();
  bool _submitting = false;
  bool _sent = false;
  String? _submitError;

  List<RoadmapEntry> _entries = [];
  StreamSubscription<QuerySnapshot>? _entrySub;

  @override
  void initState() {
    super.initState();
    _entrySub = FirebaseFirestore.instance
        .collection('roadmap_entries')
        .orderBy('order')
        .snapshots()
        .listen((s) {
      if (!mounted) return;
      setState(() {
        _entries = s.docs.map(RoadmapEntry.fromDoc).toList();
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _entrySub?.cancel();
    super.dispose();
  }

  String _currentVersion() {
    final latest = _entries
        .where((e) => e.published && e.type == 'released' && e.version != null)
        .fold<RoadmapEntry?>(null, (prev, e) => prev == null || e.order > prev.order ? e : prev);
    final v = latest?.version ?? 'v 1.00';
    return 'YTÜ · İstanbul · 2026 · $v';
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() { _submitting = true; _submitError = null; });
    try {
      await FirebaseFirestore.instance.collection('feature_requests').add({
        'text':      text,
        'createdAt': FieldValue.serverTimestamp(),
        'uid':       FirebaseAuth.instance.currentUser?.uid,
        'isRead':    false,
        'archived':  false,
      });
      if (!mounted) return;
      setState(() { _sent = true; _submitting = false; });
      Future.delayed(const Duration(milliseconds: 2400), () {
        if (mounted) setState(() { _sent = false; _controller.clear(); });
      });
    } catch (_) {
      if (!mounted) return;
      setState(() { _submitting = false; _submitError = 'Bir hata oluştu, tekrar dene.'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _buildHeader(),
          _buildComingSection(),
          _buildFeatureRequest(),
          _buildAbout(),
          const SizedBox(height: 120),
        ],
      ),
    );
  }

  // ─── Header ──────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      color: AppColors.teal,
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 28,
        bottom: 36, left: 24, right: 24,
      ),
      child: Column(
        children: [
          Text(
            'Hz. Âişe\'den rivayet edildiğine göre, Resûlullah\'a (sav),\n"Allah katında amellerin en sevimlisi hangisidir?" diye soruldu.',
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(fontSize: 14, height: 1.6, color: Colors.white.withValues(alpha: 0.92), fontStyle: FontStyle.italic, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 6),
          Text(
            '"Az da olsa devamlı olanıdır." buyurdu.',
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(fontSize: 15, height: 1.6, color: Colors.white, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Text(
            'M1828 Müslim, Müsâfirîn, 216',
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(fontSize: 11, color: Colors.white.withValues(alpha: 0.6), fontWeight: FontWeight.w600, letterSpacing: 0.3),
          ),
        ],
      ),
    );
  }

  // ─── Yol haritası ────────────────────────────────────────────────────────
  Widget _buildComingSection() {
    final published = _entries.where((e) => e.published).toList();
    final released  = published.where((e) => e.type == 'released').toList();
    final upcoming  = published.where((e) => e.type == 'upcoming').toList();

    final shownReleased = released.length >= 2 ? released.sublist(released.length - 2) : released;
    final shownUpcoming = upcoming.take(3).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 32, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHead(kicker: 'Yol Haritası', title: 'Neler geldi, neler geliyor'),
          if (_entries.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text('Yükleniyor...', style: GoogleFonts.nunito(fontSize: 13, color: AppColors.textLight)),
            ),
          for (final item in shownReleased)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _RoadmapCard(entry: item),
            ),
          for (final item in shownUpcoming)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _RoadmapCard(entry: item),
            ),
          const SizedBox(height: 4),
          if (published.isNotEmpty)
            Center(
              child: GestureDetector(
                onTap: () => _showRoadmapSheet(context, published),
                child: Text(
                  'Tüm sürüm geçmişini gör →',
                  style: GoogleFonts.nunito(fontSize: 12, color: AppColors.textLight, fontWeight: FontWeight.w600, letterSpacing: 0.4),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showRoadmapSheet(BuildContext context, List<RoadmapEntry> allEntries) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RoadmapSheet(allEntries: allEntries),
    );
  }

  // ─── Bir özellik öner ────────────────────────────────────────────────────
  Widget _buildFeatureRequest() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHead(kicker: 'Senin Sesin', title: 'Bir özellik öner'),
          Container(
            decoration: BoxDecoration(
              color: AppColors.lightGrey,
              border: Border.all(color: AppColors.borderGrey),
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Bir fikrin var mı?',
                  style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                const SizedBox(height: 4),
                Text('Paylaşacağın bir fikir, birçok kişi için hayra vesile olabilir.',
                  style: GoogleFonts.nunito(fontSize: 14, color: AppColors.textMid, height: 1.45)),
                const SizedBox(height: 14),
                TextField(
                  controller: _controller,
                  onChanged: (_) => setState(() {}),
                  maxLength: 280,
                  maxLines: 3,
                  style: GoogleFonts.nunito(fontSize: 14.5, color: AppColors.textDark),
                  decoration: InputDecoration(
                    hintText: 'Hangi özelliği istersin?',
                    hintStyle: GoogleFonts.nunito(fontSize: 14.5, color: AppColors.textLight),
                    counterStyle: GoogleFonts.nunito(fontSize: 12, color: AppColors.textLight),
                    filled: true,
                    fillColor: AppColors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.borderGrey, width: 1.5),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.teal, width: 1.5),
                    ),
                  ),
                ),
                if (_submitError != null) ...[
                  const SizedBox(height: 6),
                  Text(_submitError!, style: GoogleFonts.nunito(fontSize: 13, color: AppColors.errorRed)),
                ],
                const SizedBox(height: 4),
                _PrimaryButton(
                  label: _sent ? '✓  GÖNDERİLDİ' : 'GÖNDER',
                  disabled: _sent || _submitting || _controller.text.trim().isEmpty,
                  loading: _submitting,
                  onTap: _submit,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Hakkında ─────────────────────────────────────────────────────────────
  Widget _buildAbout() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHead(kicker: 'Hakkında', title: 'Vird nedir?'),
          Container(
            decoration: BoxDecoration(
              color: AppColors.lightGrey,
              border: Border.all(color: AppColors.borderGrey),
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Allah\'a yaklaşmak için belirli zamanda ve belli miktarda yapılan ibadet, dua ve zikri ifade eden tasavvuf terimi.',
                  style: GoogleFonts.nunito(fontSize: 14, color: AppColors.textMid, height: 1.6, fontStyle: FontStyle.italic),
                ),
                const SizedBox(height: 12),
                RichText(
                  text: TextSpan(
                    style: GoogleFonts.nunito(fontSize: 14.5, color: AppColors.textDark, height: 1.6, fontWeight: FontWeight.w500),
                    children: [
                      const TextSpan(text: 'Vird, ibadetin '),
                      TextSpan(text: 'devamlı',
                        style: GoogleFonts.nunito(fontSize: 14.5, color: AppColors.teal, fontWeight: FontWeight.w700, height: 1.6)),
                      const TextSpan(text: ' olmasına katkı sunmak için tasarlandı. Az ama düzenli — Allah katında amellerin en sevimlisi.'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Bugün Kuran okuma takibiyle başlıyoruz. Yarın namaz, oruç ve diğer alışkanlıklar da burada olacak. Geliştiricinin de bu yolda kendine bir vesilesi; aynı zamanda hayra vesile olabilmek niyetiyle.',
                  style: GoogleFonts.nunito(fontSize: 14, color: AppColors.textMid, height: 1.6),
                ),
              ],
            ),
          ),
          const SizedBox(height: 48),
          Center(
            child: Column(
              children: [
                Image.asset(AppAssets.logo, height: 96, fit: BoxFit.contain),
                const SizedBox(height: 16),
                Text(
                  _currentVersion(),
                  style: GoogleFonts.nunito(fontSize: 12, color: AppColors.textLight, fontWeight: FontWeight.w600, letterSpacing: 0.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Yardımcı widget'lar ──────────────────────────────────────────────────

class _SectionHead extends StatelessWidget {
  final String kicker;
  final String title;
  const _SectionHead({required this.kicker, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(kicker.toUpperCase(),
            style: GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.teal, letterSpacing: 1.4)),
          const SizedBox(height: 4),
          Text(title,
            style: GoogleFonts.nunito(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textDark, letterSpacing: -0.2)),
        ],
      ),
    );
  }
}

// ─── Kompakt yol haritası kartı ──────────────────────────────────────────────
class _RoadmapCard extends StatelessWidget {
  final RoadmapEntry entry;
  const _RoadmapCard({required this.entry});

  static const _green   = Color(0xFF58CC02);
  static const _greenBg = Color(0xFFD7FFB8);

  @override
  Widget build(BuildContext context) {
    final isReleased = entry.type == 'released';
    final barColor  = isReleased ? _green        : AppColors.teal;
    final badgeBg   = isReleased ? _greenBg      : AppColors.tealLight;
    final badgeFg   = isReleased ? _green        : AppColors.teal;

    final badgeLabel = isReleased ? 'Yayında ✓' : (entry.eta ?? 'Yakında');

    return Container(
      decoration: BoxDecoration(
        color: AppColors.lightGrey,
        border: Border.all(color: AppColors.borderGrey),
        borderRadius: BorderRadius.circular(14),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: barColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(13),
                  bottomLeft: Radius.circular(13),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Başlık satırı
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (entry.version != null) ...[
                          Text(
                            entry.version!,
                            style: GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textLight, letterSpacing: 0.3),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Expanded(
                          child: Text(
                            entry.title,
                            style: GoogleFonts.nunito(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.textDark),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(999)),
                          child: Text(
                            badgeLabel,
                            style: GoogleFonts.nunito(fontSize: 10, fontWeight: FontWeight.w700, color: badgeFg, letterSpacing: 0.3),
                          ),
                        ),
                      ],
                    ),
                    // Tarih (released ise)
                    if (isReleased && entry.date != null) ...[
                      const SizedBox(height: 1),
                      Text(
                        _formatDate(entry.date!),
                        style: GoogleFonts.nunito(fontSize: 10.5, color: AppColors.textLight, fontWeight: FontWeight.w600),
                      ),
                    ],
                    // Bullet listesi
                    if (entry.bullets.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      for (final b in entry.bullets)
                        Padding(
                          padding: const EdgeInsets.only(top: 1),
                          child: Text(
                            '· $b',
                            style: GoogleFonts.nunito(fontSize: 12, color: AppColors.textMid, height: 1.35),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String iso) {
    try {
      final p = iso.split('-');
      if (p.length != 3) return iso;
      const months = ['', 'Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz', 'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara'];
      final m = int.tryParse(p[1]) ?? 0;
      return '${p[2]} ${months[m]} ${p[0]}';
    } catch (_) {
      return iso;
    }
  }
}

class _PrimaryButton extends StatefulWidget {
  final String label;
  final bool disabled;
  final bool loading;
  final VoidCallback onTap;
  const _PrimaryButton({required this.label, required this.disabled, required this.onTap, this.loading = false});

  @override
  State<_PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<_PrimaryButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final bg      = widget.disabled ? AppColors.borderGrey : AppColors.teal;
    final shadow  = widget.disabled ? Colors.transparent   : AppColors.tealDark;
    final textColor = widget.disabled ? AppColors.textLight  : AppColors.white;

    return GestureDetector(
      onTapDown: (_) { if (!widget.disabled) setState(() => _pressed = true); },
      onTapUp: (_) { setState(() => _pressed = false); if (!widget.disabled) widget.onTap(); },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        transform: Matrix4.translationValues(0, _pressed ? 2 : 0, 0),
        height: 52,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          boxShadow: [BoxShadow(color: shadow, offset: Offset(0, _pressed ? 2 : 4), blurRadius: 0)],
        ),
        alignment: Alignment.center,
        child: widget.loading
            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
            : Text(widget.label,
                style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w800, color: textColor, letterSpacing: 1.2)),
      ),
    );
  }
}

// ─── Yol haritası bottom sheet ────────────────────────────────────────────────
class _RoadmapSheet extends StatefulWidget {
  final List<RoadmapEntry> allEntries;
  const _RoadmapSheet({required this.allEntries});

  @override
  State<_RoadmapSheet> createState() => _RoadmapSheetState();
}

class _RoadmapSheetState extends State<_RoadmapSheet> {
  String _tab = 'released';

  @override
  Widget build(BuildContext context) {
    final released = widget.allEntries.where((e) => e.type == 'released').toList().reversed.toList();
    final upcoming = widget.allEntries.where((e) => e.type == 'upcoming').toList();
    final items    = _tab == 'released' ? released : upcoming;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
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
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 4),
                width: 40, height: 4,
                decoration: BoxDecoration(color: AppColors.borderGrey, borderRadius: BorderRadius.circular(999)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
              child: Text('Yol Haritası',
                style: GoogleFonts.nunito(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textDark)),
            ),
            // Sekmeler
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Container(
                height: 38,
                decoration: BoxDecoration(color: AppColors.lightGrey, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    _SheetTab(
                      label: 'Neler Geldi',
                      count: released.length,
                      active: _tab == 'released',
                      onTap: () => setState(() => _tab = 'released'),
                    ),
                    _SheetTab(
                      label: 'Neler Geliyor',
                      count: upcoming.length,
                      active: _tab == 'upcoming',
                      onTap: () => setState(() => _tab = 'upcoming'),
                    ),
                  ],
                ),
              ),
            ),
            // Liste
            Expanded(
              child: Stack(
                children: [
                  ListView.builder(
                    controller: controller,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    itemCount: items.length,
                    itemBuilder: (_, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _RoadmapCard(entry: items[i]),
                    ),
                  ),
                  Positioned(
                    bottom: 0, left: 0, right: 0,
                    child: IgnorePointer(
                      child: Container(
                        height: 100,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [AppColors.white.withValues(alpha: 0), AppColors.white],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetTab extends StatelessWidget {
  final String label;
  final int count;
  final bool active;
  final VoidCallback onTap;
  const _SheetTab({required this.label, required this.count, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: active ? AppColors.teal : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          alignment: Alignment.center,
          child: Text(
            count > 0 ? '$label ($count)' : label,
            style: GoogleFonts.nunito(
              color: active ? Colors.white : AppColors.textMid,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}
