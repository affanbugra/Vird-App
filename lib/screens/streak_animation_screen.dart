import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../app_theme.dart';

// ─── Palette ──────────────────────────────────────────────────────────────────
const _kAccent      = Color(0xFFF5A623);
const _kFgSoft      = Color(0x8C1F1B14);
const _kCheckColor  = Color(0xFF2B1610);
const _kTodayOrange = Color(0xFFE8821C);

// Mesajlar streak_messages.json'dan — {X} placeholder'ı gerçek sayıyla değiştirilir
const _kMessages = [
  // range 1
  (min: 1, max: 1, msgs: [
    'Bismillah! İlk adımın hayırlı olsun. Artık geri dönüş yok 😄',
    '"Ameller niyetlere göredir." Sen bugün güzel bir niyet ettin. Allah bu adımını bereketli kılsın.',
    '"Allah katında amellerin en makbulü az da olsa devam üzere yapılanıdır." Allah dâim etsin.',
  ]),
  // range 2-4
  (min: 2, max: 4, msgs: [
    '{X}. günün hayırlı olsun! Alev sönmedi, devam ediyor 🔥',
    'Bugün de geldin. Maşallah! Allah nazardan korusun.',
    '{X} gün üst üste — "Allah katında amellerin en sevimlis, az da olsa devamlı olanıdır." Sen o yoldasın.',
    '{X}. gün! Kendine maşallah demeyi unutma, çok iyi gidiyorsun.',
  ]),
  // range 5-10
  (min: 5, max: 10, msgs: [
    '{X}. gün! Artık bu bir alışkanlık olmaya başladı. Allah dâim etsin 🔥',
    'Bak {X} gün olmuş! Farkında mısın, Kur\'an artık gününün bir parçası.',
    '{X} gün — için çekmeden gelip okumaya başladın mı? İşte o his Kur\'an\'ın seni çağırması 🌿',
  ]),
  // range 11-20
  (min: 11, max: 20, msgs: [
    '{X}. gün! Pek çok insan bu aşamaya gelemez — sen geldin. Allah kabul etsin.',
    '{X} gün boyunca Kur\'an\'la buluşan bir kalp bambaşka bir kalptir. Maşallah sana!',
    '{X}. gün! Bu artık bir rutin, farkında mısın? Seri bozulmadan devam ediyor 💪',
    '{X} gün! Bir şey fark ettik — sen bırakmıyorsun. Allah da bırakmaz seni 🤲',
    '{X}. gün! Bu seri artık senin karakterinin bir parçası. Maşallah, Allah nazardan korusun.',
  ]),
  // range 21-30 (ve üstü)
  (min: 21, max: 999, msgs: [
    '{X}. gün! Bilim der ki alışkanlık 21 günde oluşur. Ama bence Kur\'an çok daha hızlı kalbe yerleşir 😄',
    '{X} gün! Artık Kur\'an günlük bir ihtiyaç oldu senin için. Allah bu nuru dâim etsin 🤲',
    '{X}. gün! Bu noktaya gelen çok az insan geri döner. Sen artık o insanlardan birisin.',
    '{X} gün üst üste! Bir ayı geçiyorsun — bu artık alışkanlık değil, ibadet aşkı 🔥',
    '{X}. gün! Neredeyse bir ay. Allah\'ın rızası da bu devamda, inan.',
  ]),
];

String _getMotivation(int count) {
  final bucket = _kMessages.firstWhere(
    (b) => count >= b.min && count <= b.max,
    orElse: () => _kMessages.last,
  );
  final msg = bucket.msgs[count % bucket.msgs.length];
  return msg.replaceAll('{X}', '$count');
}

// ─── Entry point ──────────────────────────────────────────────────────────────

class StreakAnimationScreen extends StatefulWidget {
  final int count;
  final int? prevCount;
  final List<bool> filled;      // 7 boolean — son 7 gün, index 6 = bugün
  final int todayIndex;         // filled içinde bugünün indeksi (daima 6)
  final List<String> dayLabels; // 7 gün etiketi — dinamik, hafta sınırından bağımsız
  final String ctaLabel;

  const StreakAnimationScreen({
    super.key,
    required this.count,
    this.prevCount,
    required this.filled,
    required this.todayIndex,
    required this.dayLabels,
    this.ctaLabel = 'Mâşâallah, devam et',
  });

  static Future<void> show(
    BuildContext context, {
    required int count,
    int? prevCount,
    required List<bool> filled,
    required int todayIndex,
    required List<String> dayLabels,
    String ctaLabel = 'Mâşâallah, devam et',
  }) =>
      Navigator.of(context).push(PageRouteBuilder(
        opaque: false,
        pageBuilder: (_, _, _) => StreakAnimationScreen(
          count: count,
          prevCount: prevCount,
          filled: filled,
          todayIndex: todayIndex,
          dayLabels: dayLabels,
          ctaLabel: ctaLabel,
        ),
        transitionsBuilder: (_, anim, _, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 200),
      ));

  @override
  State<StreakAnimationScreen> createState() => _StreakAnimationScreenState();
}

class _StreakAnimationScreenState extends State<StreakAnimationScreen>
    with TickerProviderStateMixin {
  // One-shot intro (2200 ms)
  late final AnimationController _intro;
  // Looping idle controllers (start at 1700 ms)
  late final AnimationController _breathe;    // 2600 ms — halo
  late final AnimationController _bodyBreath; // 1900 ms — body
  late final AnimationController _midFlick;   // 1100 ms — mid layer
  late final AnimationController _coreFlick;  //  580 ms — core
  late final AnimationController _shadowCtrl; // 1800 ms — shadow
  late final AnimationController _particles;  // 2000 ms — particles

  // Derived from _intro
  late final Animation<double> _haloIn;
  late final Animation<double> _shadowIn;
  late final Animation<double> _bodyScale;
  late final Animation<double> _bodyTY;
  late final Animation<double> _bodyOpacity;
  late final List<Animation<double>> _whips;
  late final Animation<double> _sparks;
  late final Animation<double> _motivOpacity;
  late final Animation<double> _motivY;
  late final Animation<double> _ctaOpacity;
  late final Animation<double> _ctaY;

  int _displayCount = 0;

  @override
  void initState() {
    super.initState();
    _displayCount = widget.prevCount ?? widget.count;

    _intro = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2200))
      ..forward();

    _breathe    = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));
    _bodyBreath = AnimationController(vsync: this, duration: const Duration(milliseconds: 1900));
    _midFlick   = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
    _coreFlick  = AnimationController(vsync: this, duration: const Duration(milliseconds: 580));
    _shadowCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));
    _particles  = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))
      ..repeat();

    Future.delayed(const Duration(milliseconds: 1700), () {
      if (!mounted) return;
      _breathe.repeat(reverse: true);
      _bodyBreath.repeat(reverse: true);
      _midFlick.repeat(reverse: true);
      _coreFlick.repeat(reverse: true);
      _shadowCtrl.repeat(reverse: true);
    });

    if (widget.prevCount != null && widget.prevCount != widget.count) {
      Future.delayed(const Duration(milliseconds: 1300), _startRolling);
    }

    // Intro animation intervals
    _haloIn = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.0, 0.636, curve: Curves.easeOut),
    );
    _shadowIn = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.363, 0.682, curve: Curves.easeOut),
    );
    _bodyScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.05, end: 1.06)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 75,
      ),
      TweenSequenceItem(tween: Tween(begin: 1.06, end: 1.0), weight: 25),
    ]).animate(CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.09, 0.82),
    ));
    _bodyTY = Tween<double>(begin: 1.0, end: 0.0).animate(CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.09, 0.82, curve: Curves.easeOut),
    ));
    _bodyOpacity = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.09, 0.22, curve: Curves.easeIn),
    );
    _whips = [0.127, 0.163, 0.200, 0.236].map((d) => CurvedAnimation(
      parent: _intro,
      curve: Interval(d, (d + 0.5).clamp(0.0, 1.0), curve: Curves.easeInOut),
    )).toList();
    _sparks = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.477, 0.841, curve: Curves.easeOut),
    );
    _motivOpacity = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.59, 0.86, curve: Curves.easeOut),
    );
    _motivY = Tween<double>(begin: 8.0, end: 0.0).animate(CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.59, 0.86, curve: Curves.elasticOut),
    ));
    _ctaOpacity = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.77, 1.0, curve: Curves.easeOut),
    );
    _ctaY = Tween<double>(begin: 24.0, end: 0.0).animate(CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.77, 1.0, curve: Curves.elasticOut),
    ));
  }

  void _startRolling() {
    if (!mounted) return;
    final start = widget.prevCount!;
    final end   = widget.count;
    final t0    = DateTime.now().millisecondsSinceEpoch;
    const dur   = 700;

    void tick() {
      if (!mounted) return;
      final elapsed = DateTime.now().millisecondsSinceEpoch - t0;
      final t = (elapsed / dur).clamp(0.0, 1.0);
      final eased = 1.0 - math.pow(1 - t, 3).toDouble();
      setState(() => _displayCount = (start + (end - start) * eased).round());
      if (t < 1.0) WidgetsBinding.instance.addPostFrameCallback((_) => tick());
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => tick());
  }

  @override
  void dispose() {
    _intro.dispose();
    _breathe.dispose();
    _bodyBreath.dispose();
    _midFlick.dispose();
    _coreFlick.dispose();
    _shadowCtrl.dispose();
    _particles.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Close button
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 16, right: 20),
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: context.colors.textPrimary.withValues(alpha: 0.07),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.close_rounded,
                        size: 18, color: context.colors.textSecondary),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Flame
            _buildFlame(),

            const SizedBox(height: 12),

            // Rolling count
            AnimatedBuilder(
              animation: _intro,
              builder: (_, _) => Text(
                '$_displayCount',
                style: const TextStyle(
                  fontSize: 76,
                  fontWeight: FontWeight.w900,
                  color: _kAccent,
                  height: 1.0,
                  letterSpacing: -1.5,
                ),
              ),
            ),

            const SizedBox(height: 6),

            const Text(
              'günlük seri',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _kFgSoft),
            ),

            const SizedBox(height: 28),

            // Day row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _DayRow(
                filled: widget.filled,
                todayIndex: widget.todayIndex,
                accent: _kAccent,
                dayLabels: widget.dayLabels,
              ),
            ),

            const Spacer(),

            // Motivation — centered between calendar and button
            AnimatedBuilder(
              animation: _intro,
              builder: (_, _) => Opacity(
                opacity: _motivOpacity.value,
                child: Transform.translate(
                  offset: Offset(0, _motivY.value),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 44),
                    child: Text(
                      _getMotivation(widget.count),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _kFgSoft,
                        height: 1.55,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const Spacer(),

            // CTA
            AnimatedBuilder(
              animation: _intro,
              builder: (_, _) => Opacity(
                opacity: _ctaOpacity.value,
                child: Transform.translate(
                  offset: Offset(0, _ctaY.value),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _kAccent,
                          foregroundColor: const Color(0xFF1A1414),
                          padding: const EdgeInsets.symmetric(vertical: 17),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          elevation: 4,
                          shadowColor: _kAccent.withValues(alpha: 0.35),
                        ),
                        child: Text(
                          widget.ctaLabel,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }

  Widget _buildFlame() {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _intro,
        _breathe,
        _bodyBreath,
        _midFlick,
        _coreFlick,
        _shadowCtrl,
        _particles,
      ]),
      builder: (_, _) {
        final idleBlend = ((_intro.value - 0.77) / 0.23).clamp(0.0, 1.0);
        return SizedBox(
          width: 220,
          height: 220,
          child: CustomPaint(
            painter: _FlamePainter(
              haloIn: _haloIn.value,
              haloBreathe: _breathe.value,
              shadowIn: _shadowIn.value,
              shadowBreathe: _shadowCtrl.value,
              bodyScale: _bodyScale.value,
              bodyTY: _bodyTY.value,
              bodyOpacity: _bodyOpacity.value,
              bodyBreatheScale: 1.0 + _bodyBreath.value * 0.04,
              bodyBreatheY: -_bodyBreath.value * 3.4,
              midFlick: _midFlick.value,
              coreFlick: _coreFlick.value,
              whips: _whips.map((a) => a.value).toList(),
              sparks: _sparks.value,
              particleT: _particles.value,
              idleBlend: idleBlend,
            ),
          ),
        );
      },
    );
  }
}

// ─── Flame CustomPainter ──────────────────────────────────────────────────────

class _FlamePainter extends CustomPainter {
  final double haloIn, haloBreathe;
  final double shadowIn, shadowBreathe;
  final double bodyScale, bodyTY, bodyOpacity;
  final double bodyBreatheScale, bodyBreatheY;
  final double midFlick, coreFlick;
  final List<double> whips;
  final double sparks, particleT, idleBlend;

  const _FlamePainter({
    required this.haloIn,
    required this.haloBreathe,
    required this.shadowIn,
    required this.shadowBreathe,
    required this.bodyScale,
    required this.bodyTY,
    required this.bodyOpacity,
    required this.bodyBreatheScale,
    required this.bodyBreatheY,
    required this.midFlick,
    required this.coreFlick,
    required this.whips,
    required this.sparks,
    required this.particleT,
    required this.idleBlend,
  });

  // SVG paths in SVG coordinate space (viewBox -110 -120 220 240)
  static final Path _bodyPath = Path()
    ..moveTo(0, -90)
    ..cubicTo(-20, -62, -44, -32, -50, 4)
    ..cubicTo(-54, 38, -38, 72, 0, 80)
    ..cubicTo(38, 72, 54, 38, 50, 4)
    ..cubicTo(44, -32, 20, -62, 0, -90)
    ..close();

  static final Path _midPath = Path()
    ..moveTo(0, -60)
    ..cubicTo(-12, -38, -28, -16, -30, 18)
    ..cubicTo(-32, 46, -18, 64, 0, 66)
    ..cubicTo(18, 64, 32, 46, 30, 18)
    ..cubicTo(28, -16, 12, -38, 0, -60)
    ..close();

  static final Path _corePath = Path()
    ..moveTo(0, -32)
    ..cubicTo(-8, -14, -16, 4, -14, 28)
    ..cubicTo(-12, 48, -4, 56, 0, 56)
    ..cubicTo(4, 56, 12, 48, 14, 28)
    ..cubicTo(16, 4, 8, -14, 0, -32)
    ..close();

  static final List<Path> _whipPaths = [
    Path()
      ..moveTo(-58, 16)
      ..quadraticBezierTo(-78, -22, -52, -52)
      ..quadraticBezierTo(-22, -72, 4, -54),
    Path()
      ..moveTo(62, 12)
      ..quadraticBezierTo(82, -28, 56, -56)
      ..quadraticBezierTo(26, -74, -2, -56),
    Path()
      ..moveTo(-42, 44)
      ..quadraticBezierTo(-66, 26, -62, -8)
      ..quadraticBezierTo(-54, -36, -32, -48),
    Path()
      ..moveTo(48, 48)
      ..quadraticBezierTo(72, 28, 64, -6)
      ..quadraticBezierTo(54, -34, 32, -48),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    // Map SVG viewBox (-110,-120,220,240) to widget size
    canvas.translate(size.width / 2, size.height * 120 / 240);
    canvas.scale(size.width / 220, size.height / 240);

    _drawHalo(canvas);
    _drawShadow(canvas);
    _drawBody(canvas);
    _drawWhips(canvas);
    _drawParticles(canvas);
    _drawSparks(canvas);
  }

  void _drawHalo(Canvas canvas) {
    if (haloIn <= 0) return;
    final opacity = (0.7 + haloBreathe * 0.3) * haloIn;
    final scale   = 0.55 + haloIn * 0.45 * (0.96 + haloBreathe * 0.1);
    canvas.save();
    canvas.scale(scale);
    final rect  = Rect.fromCenter(center: const Offset(0, -5), width: 190, height: 190);
    final paint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, 0.1),
        radius: 0.6,
        colors: [
          const Color(0xFFFFE4A8).withValues(alpha: 0.55 * opacity),
          const Color(0xFFFF7A2E).withValues(alpha: 0.18 * opacity),
          const Color(0x00FF7A2E),
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(rect);
    canvas.drawOval(rect, paint);
    canvas.restore();
  }

  void _drawShadow(Canvas canvas) {
    if (shadowIn <= 0) return;
    final scaleX  = (0.5 + shadowIn * 0.5) * (1.0 + shadowBreathe * 0.08);
    final opacity = (0.85 + shadowBreathe * 0.15) * shadowIn;
    canvas.save();
    canvas.scale(scaleX, 1.0);
    canvas.drawOval(
      const Rect.fromLTWH(-42, 86, 84, 12),
      Paint()
        ..color = Color.fromARGB(
            (opacity * 0.35 * 255).round(), 245, 166, 35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.restore();
  }

  void _drawBody(Canvas canvas) {
    if (bodyOpacity <= 0) return;

    final effectiveScale = bodyScale * (idleBlend >= 1 ? bodyBreatheScale : 1.0);
    final effectiveTY    = bodyTY * 68.0 + (idleBlend >= 1 ? bodyBreatheY : 0.0);

    // transform-origin: center bottom (0, 80)
    canvas.save();
    canvas.translate(0, 80);
    canvas.scale(effectiveScale);
    canvas.translate(0, effectiveTY - 80);

    canvas.saveLayer(
      null,
      Paint()..color = Color.fromARGB((bodyOpacity * 255).round(), 255, 255, 255),
    );

    // Outer body
    final bodyBounds = const Rect.fromLTRB(-54, -90, 54, 80);
    canvas.drawPath(
      _bodyPath,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFD86B), Color(0xFFF5A623), Color(0xFFE8421C)],
          stops: [0.0, 0.55, 1.0],
        ).createShader(bodyBounds),
    );

    // Mid layer
    final mScaleX = idleBlend >= 1 ? (0.98 + midFlick * 0.06) : 1.0;
    final mScaleY = idleBlend >= 1 ? (0.96 + midFlick * 0.10) : 1.0;
    final mTY     = idleBlend >= 1 ? (2.0 - midFlick * 4.0) : 0.0;
    canvas.save();
    canvas.translate(0, mTY);
    canvas.scale(mScaleX, mScaleY);
    canvas.drawPath(
      _midPath,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFF7A2E), Color(0xFFD93B17)],
        ).createShader(const Rect.fromLTRB(-30, -60, 30, 66)),
    );
    canvas.restore();

    // Core
    final cScaleX = idleBlend >= 1 ? (0.92 + coreFlick * 0.14) : 1.0;
    final cScaleY = idleBlend >= 1 ? (0.94 + coreFlick * 0.16) : 1.0;
    final cTY     = idleBlend >= 1 ? (3.0 - coreFlick * 6.0) : 0.0;
    final cOp     = idleBlend >= 1 ? (0.88 + coreFlick * 0.12) : 1.0;
    canvas.save();
    canvas.translate(0, cTY);
    canvas.scale(cScaleX, cScaleY);
    canvas.saveLayer(
        null, Paint()..color = Color.fromARGB((cOp * 255).round(), 255, 255, 255));
    canvas.drawPath(
      _corePath,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white, Color(0xFFFFE9B8), Color(0xFFFFB870)],
          stops: [0.0, 0.5, 1.0],
        ).createShader(const Rect.fromLTRB(-16, -32, 16, 56)),
    );
    canvas.restore(); // core saveLayer
    canvas.restore(); // core transforms

    canvas.restore(); // body saveLayer
    canvas.restore(); // body transform-origin
  }

  void _drawWhips(Canvas canvas) {
    const whipColors = [
      Color(0xFFF5A623),
      Color(0xFFFFB870),
      Color(0xFFF5A623),
      Color(0xFFFFD86B),
    ];
    const strokeWidths = [9.0, 9.0, 7.0, 7.0];

    for (int i = 0; i < 4; i++) {
      final t = whips[i];
      if (t <= 0 || t >= 1) continue;

      // Opacity keyframes: 0→1 at 20%, hold, 0.7 at 80%, 0 at 100%
      final opacity = t < 0.2
          ? t / 0.2
          : t < 0.8
              ? 1.0 - (t - 0.2) / 0.6 * 0.3
              : 0.7 * (1.0 - (t - 0.8) / 0.2);
      if (opacity <= 0) continue;

      // dashoffset 100→-100 → visible segment slides through
      final dashOffset = 100.0 - 200.0 * t;
      final startFrac  = math.max(0.0, -dashOffset) / 100.0;
      final endFrac    = math.min(1.0, (100.0 - dashOffset) / 100.0);
      if (endFrac <= startFrac) continue;

      // Transform: scale 0.7→1→0.4, rotate -25→0→35 deg
      final scale  = t < 0.55 ? 0.7 + t / 0.55 * 0.3 : 1.0 - (t - 0.55) / 0.45 * 0.6;
      final rotDeg = t < 0.55 ? -25.0 + t / 0.55 * 25.0 : (t - 0.55) / 0.45 * 35.0;
      final tY     = t > 0.55 ? -(t - 0.55) / 0.45 * 20.0 : 0.0;

      canvas.save();
      canvas.scale(scale);
      canvas.rotate(rotDeg * math.pi / 180);
      canvas.translate(0, tY);

      final metrics = _whipPaths[i].computeMetrics().first;
      final segment = metrics.extractPath(
          startFrac * metrics.length, endFrac * metrics.length);

      canvas.drawPath(
        segment,
        Paint()
          ..color = whipColors[i].withValues(alpha: opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidths[i]
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
      );
      canvas.restore();
    }
  }

  void _drawParticles(Canvas canvas) {
    if (bodyOpacity < 0.2) return;
    const colors = [
      Color(0xFFFFE9B8),
      Color(0xFFFFB870),
      Color(0xFFFF7A2E),
      Color(0xFFFFD86B),
    ];

    for (int i = 0; i < 16; i++) {
      final startAng = (i / 16) * math.pi * 2;
      final sx  = math.cos(startAng) * (28 + (i % 3) * 6);
      final sy  = 30 + math.sin(startAng) * 18;
      final tx  = sx * 0.4 + (i.isOdd ? 8.0 : -8.0);
      final ty  = -110.0 - (i % 4) * 8;
      final mx  = (sx + tx) / 2 + (i.isOdd ? 12.0 : -12.0);
      final my  = (sy + ty) / 2;
      final sz  = 1.5 + (i % 3) * 0.8;
      final dur = (1600 + (i % 4) * 200).toDouble();
      final del = ((i * 90) % 1400).toDouble();

      final phase = ((particleT * 2000 + (2000 - del)) % dur) / dur;

      final opacity = phase < 0.15
          ? phase / 0.15
          : phase < 0.55
              ? 0.9
              : 0.9 * (1.0 - (phase - 0.55) / 0.45);
      if (opacity <= 0.02) continue;

      // Quadratic bezier position
      final p  = phase;
      final px = (1 - p) * (1 - p) * sx + 2 * (1 - p) * p * mx + p * p * tx;
      final py = (1 - p) * (1 - p) * sy + 2 * (1 - p) * p * my + p * p * ty;

      final pScale = phase < 0.15
          ? 0.3 + phase / 0.15 * 0.7
          : phase < 0.55
              ? 1.0 - (phase - 0.15) / 0.4 * 0.2
              : 0.8 - (phase - 0.55) / 0.45 * 0.6;

      canvas.drawCircle(
        Offset(px, py),
        sz * pScale,
        Paint()
          ..color = colors[i % colors.length]
              .withValues(alpha: opacity * bodyOpacity),
      );
    }
  }

  void _drawSparks(Canvas canvas) {
    if (sparks <= 0 || sparks >= 1) return;
    for (int i = 0; i < 10; i++) {
      final ang  = (i / 10) * math.pi * 2 - math.pi / 2;
      final dist = 78.0 + (i % 3) * 8;

      final opacity = sparks < 0.25 ? sparks / 0.25 : 1.0 - (sparks - 0.25) / 0.75;
      final pScale  = sparks < 0.25 ? sparks / 0.25 * 1.4 : 1.4 - (sparks - 0.25) / 0.75 * 1.1;
      final cx = math.cos(ang) * dist * sparks;
      final cy = math.sin(ang) * dist * sparks;

      canvas.drawCircle(
        Offset(cx, cy),
        3 * pScale,
        Paint()
          ..color = (i.isEven ? const Color(0xFFFFD86B) : const Color(0xFFFFE9B8))
              .withValues(alpha: opacity)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
    }
  }

  @override
  bool shouldRepaint(_FlamePainter o) => true;
}

// ─── Day Row ──────────────────────────────────────────────────────────────────

class _DayRow extends StatefulWidget {
  final List<bool> filled;
  final int todayIndex;
  final Color accent;
  final List<String> dayLabels; // dinamik gün etiketleri

  const _DayRow({
    required this.filled,
    required this.todayIndex,
    required this.accent,
    required this.dayLabels,
  });

  @override
  State<_DayRow> createState() => _DayRowState();
}

class _DayRowState extends State<_DayRow> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final CurvedAnimation _pillCurve;
  bool _todayVisible = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _pillCurve = CurvedAnimation(
        parent: _ctrl, curve: const Cubic(0.34, 1.2, 0.4, 1));
    Future.delayed(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      setState(() => _todayVisible = true);
      _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _pillCurve.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  List<({int start, int end})> _buildBlocks(List<bool> filled) {
    final blocks = <({int start, int end})>[];
    int? blockStart;
    for (int i = 0; i < 7; i++) {
      if (filled[i]) {
        blockStart ??= i;
        if (i == 6 || !filled[i + 1]) {
          blocks.add((start: blockStart, end: i));
          blockStart = null;
        }
      }
    }
    return blocks;
  }

  Positioned _pillWidget(({int start, int end}) b, double cellW) => Positioned(
        top: 2,
        bottom: 2,
        left: b.start * cellW + 4,
        child: Container(
          width: (b.end - b.start + 1) * cellW - 8,
          decoration: BoxDecoration(
            color: widget.accent.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final cellW = constraints.maxWidth / 7;

      // Previous filled day (before today)
      int prevFilled = -1;
      for (int i = widget.todayIndex - 1; i >= 0; i--) {
        if (widget.filled[i]) { prevFilled = i; break; }
      }

      // Base blocks — week without today
      final baseFilled = List<bool>.from(widget.filled)..[widget.todayIndex] = false;
      final baseBlocks = _buildBlocks(baseFilled);

      // Today's pill geometry
      final adjacentLeft = prevFilled == widget.todayIndex - 1;
      final connectingBlock =
          adjacentLeft ? baseBlocks.where((b) => b.end == prevFilled).firstOrNull : null;
      final pillStart = connectingBlock?.start ?? widget.todayIndex;
      final pillBaseW = adjacentLeft ? (prevFilled - pillStart + 1) * cellW - 8 : 0.0;
      final pillFullW = (widget.todayIndex - pillStart + 1) * cellW - 8;
      final pillLeft  = pillStart * cellW + 4;

      // Circle area: 38px stack — circles sit at top:4..bottom:4 (30px), pills at top:2..bottom:2 (34px)
      const double stackH    = 38;
      const double circleTop = 4.0;
      const double tokenSize = 24;
      // Token centered on circle center: circleTop + circleSize/2 - tokenSize/2 = 4+15-12 = 7
      const double tokenBase = 7.0;

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Day labels
          Row(
            children: List.generate(7, (i) {
              final isToday = i == widget.todayIndex;
              return SizedBox(
                width: cellW,
                child: Text(
                  widget.dayLabels[i], // Bug 5: dinamik etiket
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isToday ? _kTodayOrange : const Color(0x591F1B14),
                    letterSpacing: 0.5,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 6),

          // Circle area with pills and token
          SizedBox(
            height: stackH,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Base pills (before animation triggers)
                if (!_todayVisible) ...baseBlocks.map((b) => _pillWidget(b, cellW)),

                if (_todayVisible) ...[
                  // Static pills not adjacent to today
                  ...baseBlocks
                      .where((b) => b.end < widget.todayIndex - 1)
                      .map((b) => _pillWidget(b, cellW)),

                  // Today's pill: elastic extension
                  AnimatedBuilder(
                    animation: _pillCurve,
                    builder: (_, _) {
                      final w = pillBaseW + (pillFullW - pillBaseW) * _pillCurve.value;
                      return Positioned(
                        top: 2,
                        bottom: 2,
                        left: pillLeft,
                        child: Container(
                          width: w.clamp(0.0, double.infinity),
                          decoration: BoxDecoration(
                            color: widget.accent.withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      );
                    },
                  ),

                  // Token: parabolic arc slide or first-day drop
                  AnimatedBuilder(
                    animation: _ctrl,
                    builder: (_, _) {
                      final t = _ctrl.value;
                      double x, y, opacity;

                      if (prevFilled != -1) {
                        final fromX = (prevFilled + 0.5) * cellW;
                        final toX   = (widget.todayIndex + 0.5) * cellW;
                        x = fromX + (toX - fromX) * Curves.easeInOut.transform(t);
                        y = tokenBase + 4.0 * t * (1.0 - t) * -20.0;
                        opacity = t < 0.10 ? t / 0.10 : t < 0.75 ? 1.0 : (1.0 - (t - 0.75) / 0.15).clamp(0.0, 1.0);
                      } else {
                        x = (widget.todayIndex + 0.5) * cellW;
                        y = tokenBase + (1.0 - Curves.easeOut.transform(t)) * -36.0;
                        opacity = t < 0.15 ? t / 0.15 : t < 0.70 ? 1.0 : (1.0 - (t - 0.70) / 0.15).clamp(0.0, 1.0);
                      }

                      return Positioned(
                        top: y,
                        left: x - tokenSize / 2,
                        child: Opacity(
                          opacity: opacity,
                          child: Container(
                            width: tokenSize,
                            height: tokenSize,
                            decoration: BoxDecoration(
                              color: widget.accent,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: widget.accent.withValues(alpha: 0.45),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],

                // Circles row
                Row(
                  children: List.generate(7, (i) {
                    final isToday  = i == widget.todayIndex;
                    final isFilled = _todayVisible
                        ? (i == widget.todayIndex || widget.filled[i])
                        : widget.filled[i];
                    return SizedBox(
                      width: cellW,
                      child: Padding(
                        padding: const EdgeInsets.only(top: circleTop),
                        child: Center(
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: isFilled
                                  ? Colors.transparent
                                  : const Color(0xFF1F1B14).withValues(alpha: 0.07),
                              shape: BoxShape.circle,
                            ),
                            child: isFilled
                                ? Center(child: _CheckMark(animate: isToday && _todayVisible))
                                : null,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ],
      );
    });
  }
}

// ─── Animated check mark ──────────────────────────────────────────────────────

class _CheckMark extends StatefulWidget {
  final bool animate;
  const _CheckMark({required this.animate});

  @override
  State<_CheckMark> createState() => _CheckMarkState();
}

class _CheckMarkState extends State<_CheckMark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 320));
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.25), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1.25, end: 1.0), weight: 40),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    if (widget.animate) {
      Future.delayed(const Duration(milliseconds: 520), () {
        if (mounted) _ctrl.forward();
      });
    } else {
      _ctrl.value = 1.0;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scale,
      builder: (_, _) => Transform.scale(
        scale: _scale.value,
        child: SizedBox(
          width: 18,
          height: 18,
          child: CustomPaint(painter: _CheckPainter()),
        ),
      ),
    );
  }
}

class _CheckPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _kCheckColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(size.width * 0.2, size.height * 0.52)
      ..lineTo(size.width * 0.42, size.height * 0.72)
      ..lineTo(size.width * 0.8, size.height * 0.3);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_) => false;
}
