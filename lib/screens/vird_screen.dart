import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../app_colors.dart';

IconData _iconFromName(String name) {
  switch (name) {
    case 'notifications': return Icons.notifications_outlined;
    case 'trophy':        return Icons.emoji_events_outlined;
    case 'moon':          return Icons.nightlight_round;
    case 'prayer':        return Icons.self_improvement_outlined;
    case 'headphones':    return Icons.headphones_outlined;
    case 'book':          return Icons.menu_book_outlined;
    case 'calendar':      return Icons.calendar_today_outlined;
    case 'heart':         return Icons.favorite_outline;
    case 'people':        return Icons.group_outlined;
    case 'quote':         return Icons.format_quote;
    case 'bookmark':      return Icons.bookmark_border;
    case 'school':        return Icons.school;
    default:              return Icons.star_outline;
  }
}

const _allUpdates = [
  _Update(iconName: 'book',     title: 'Kuran Okuma & Hatim Takibi',  desc: 'Günlük okuma alışkanlığı, hatim takibi, Streak, Hasanat ve Kuran Haritası.',  eta: 'Yayında ✓', released: true),
  _Update(iconName: 'people',   title: 'Arkadaşlarınla Takipleş',     desc: 'Arkadaşlarını ekle, okuma aktivitelerini takip et, birlikte ilerle.',          eta: 'Yakında'),
  _Update(iconName: 'quote',    title: 'Ayet & Hadisler',              desc: 'Günlük bildirimler, favori ayet ve hadisleri seç ve kategorize et.',           eta: 'Yakında'),
  _Update(iconName: 'bookmark', title: 'Tefsir Takibi',                desc: 'Tefsir okumak isteyenler için ayrı takip ve ilerleme sistemi.',                eta: 'Yakında'),
  _Update(iconName: 'prayer',   title: 'Namaz Takibi',                 desc: 'Beş vakit namaz için günlük takip ve hatırlatmalar.',                          eta: 'Yakında'),
  _Update(iconName: 'school',   title: 'İslami Kulüpler',              desc: 'Üniversite İslami kulüplerini takip et, etkinliklerden haberdar ol.',          eta: 'Yakında'),
  _Update(iconName: 'moon',     title: 'Ramazan Güncellemesi',         desc: 'Oruç takibi, teravih cami hedefleri, üniversite iftarları ve daha fazlası.',   eta: 'Ramazan 2027'),
];

class _Update {
  final String iconName;
  final String title;
  final String desc;
  final String eta;
  final bool released;
  const _Update({required this.iconName, required this.title, required this.desc, required this.eta, this.released = false});
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
  bool _showAllUpdates = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 28,
        bottom: 36, left: 24, right: 24,
      ),
      child: Column(
        children: [
          // Logo
          DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 18, offset: const Offset(0, 6))],
            ),
            child: ClipOval(
              child: Container(
                width: 112, height: 112,
                color: AppColors.white,
                padding: const EdgeInsets.all(10),
                child: Image.asset('assets/images/vird_logo.png', fit: BoxFit.contain),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Arapça
          Directionality(
            textDirection: TextDirection.rtl,
            child: Text(
              'عَنْ عَائِشَةَ: أَنَّ رَسُولَ اللَّهِ (صَلَّى اللَّهُ عَلَيْهِ وَ سَلَّمْ) سُئِلَ:\nأَيُّ الْعَمَلِ أَحَبُّ إِلَى اللَّهِ؟ قَالَ: "أَدْوَمُهُ وَإِنْ قَلَّ."',
              textAlign: TextAlign.center,
              style: GoogleFonts.amiri(fontSize: 18, height: 1.9, color: Colors.white),
            ),
          ),

          // Ayırıcı
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (_) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: 4, height: 4,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.5), shape: BoxShape.circle),
              )),
            ),
          ),

          // Türkçe meal
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

  // ─── Yakında geliyor ─────────────────────────────────────────────────────
  Widget _buildComingSection() {
    const mainCount = 4;
    final extra = _allUpdates.sublist(mainCount);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 32, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHead(kicker: 'Yol Haritası', title: 'Yakında geliyor'),

          // İlk 4 kart — MVP yeşil, kalanlar giderek şeffaflaşır
          ...List.generate(mainCount, (i) {
            final op = i < 2 ? 1.0 : (1.0 - (i - 1) * 0.35).clamp(0.2, 1.0);
            return Opacity(
              opacity: op,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _UpdateCard(update: _allUpdates[i]),
              ),
            );
          }),

          // Genişletilmiş kartlar
          if (_showAllUpdates)
            ...List.generate(extra.length, (i) {
              final op = (0.85 - i * 0.2).clamp(0.15, 1.0);
              return Opacity(
                opacity: op,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _UpdateCard(update: extra[i]),
                ),
              );
            }),

          const SizedBox(height: 4),
          Center(
            child: GestureDetector(
              onTap: () => setState(() => _showAllUpdates = !_showAllUpdates),
              child: Text(
                _showAllUpdates ? 'daha az göster' : 've daha fazlası…',
                style: GoogleFonts.nunito(fontSize: 12, color: AppColors.textLight, fontWeight: FontWeight.w600, letterSpacing: 0.4),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Bir özellik öner ─────────────────────────────────────────────────────
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
                Text('Vird\'i birlikte büyütüyoruz. Eklenmesini istediğin özelliği yaz.',
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
                  Text(_submitError!,
                    style: GoogleFonts.nunito(fontSize: 13, color: AppColors.errorRed)),
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
                      const TextSpan(text: ' olmasına katkı sunmak için tasarlandı. Az ama düzenli — Resûlullah\'ın (sav) en sevdiği amel.'),
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
          const SizedBox(height: 24),
          Center(
            child: Text(
              'YTÜ · İstanbul · v 1.00',
              style: GoogleFonts.nunito(fontSize: 12, color: AppColors.textLight, fontWeight: FontWeight.w600, letterSpacing: 0.3),
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

class _UpdateCard extends StatelessWidget {
  final _Update update;
  const _UpdateCard({required this.update});

  static const _green = Color(0xFF58CC02);
  static const _greenBg = Color(0xFFD7FFB8);

  @override
  Widget build(BuildContext context) {
    final barColor  = update.released ? _green        : AppColors.teal;
    final iconBg    = update.released ? _greenBg      : AppColors.tealLight;
    final iconColor = update.released ? _green        : AppColors.teal;
    final badgeBg   = update.released ? _greenBg      : AppColors.tealLight;
    final badgeFg   = update.released ? _green        : AppColors.teal;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.lightGrey,
        border: Border.all(color: AppColors.borderGrey),
        borderRadius: BorderRadius.circular(16),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: barColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(15),
                  bottomLeft: Radius.circular(15),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(12)),
                      child: Icon(_iconFromName(update.iconName), color: iconColor, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(update.title,
                                  style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(999)),
                                child: Text(update.eta,
                                  style: GoogleFonts.nunito(fontSize: 10, fontWeight: FontWeight.w700, color: badgeFg, letterSpacing: 0.5)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(update.desc,
                            style: GoogleFonts.nunito(fontSize: 13.5, color: AppColors.textMid, height: 1.4)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
    final bg = widget.disabled ? AppColors.borderGrey : AppColors.teal;
    final shadow = widget.disabled ? Colors.transparent : AppColors.tealDark;
    final textColor = widget.disabled ? AppColors.textLight : AppColors.white;

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
