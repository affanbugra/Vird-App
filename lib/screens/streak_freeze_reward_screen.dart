import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─── Ice Palette ──────────────────────────────────────────────────────────────
const _kBg        = Color(0xFF0B1628);  // midnight navy
const _kIce       = Color(0xFF60C8F0);  // medium ice blue
const _kIceSoft   = Color(0xFFA8E0F8);  // light ice
const _kIceGlow   = Color(0xFFE8F6FF);  // near-white ice
const _kIceDark   = Color(0xFF3A9AC4);  // deeper ice

// ─── Entry point ──────────────────────────────────────────────────────────────

class StreakFreezeRewardScreen extends StatefulWidget {
  final int milestoneDays;
  final int freezesGranted;

  const StreakFreezeRewardScreen({
    super.key,
    required this.milestoneDays,
    required this.freezesGranted,
  });

  static Future<void> show(
    BuildContext context, {
    required int milestoneDays,
    required int freezesGranted,
  }) =>
      Navigator.of(context).push(PageRouteBuilder(
        opaque: true,
        pageBuilder: (_, _, _) => StreakFreezeRewardScreen(
          milestoneDays: milestoneDays,
          freezesGranted: freezesGranted,
        ),
        transitionsBuilder: (_, anim, _, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 350),
      ));

  @override
  State<StreakFreezeRewardScreen> createState() =>
      _StreakFreezeRewardScreenState();
}

class _StreakFreezeRewardScreenState extends State<StreakFreezeRewardScreen>
    with TickerProviderStateMixin {
  late final AnimationController _introCtrl;
  late final AnimationController _rotCtrl;
  late final AnimationController _pulseCtrl;
  late final AnimationController _sparkCtrl;

  late final Animation<double> _crystalScale;
  late final Animation<double> _crystalOpacity;
  late final Animation<double> _badgeScale;
  late final Animation<double> _textOpacity;
  late final Animation<double> _textY;
  late final Animation<double> _ctaSlide;

  @override
  void initState() {
    super.initState();

    _introCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600))
      ..forward();

    _rotCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 14))
      ..repeat();

    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2400))
      ..repeat(reverse: true);

    _sparkCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat();

    _crystalScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.15, end: 1.1)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 70,
      ),
      TweenSequenceItem(tween: Tween(begin: 1.1, end: 1.0), weight: 30),
    ]).animate(
        CurvedAnimation(parent: _introCtrl, curve: const Interval(0.0, 0.75)));

    _crystalOpacity = CurvedAnimation(
        parent: _introCtrl,
        curve: const Interval(0.0, 0.25, curve: Curves.easeIn));

    _badgeScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.15)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 80,
      ),
      TweenSequenceItem(tween: Tween(begin: 1.15, end: 1.0), weight: 20),
    ]).animate(
        CurvedAnimation(parent: _introCtrl, curve: const Interval(0.3, 0.82)));

    _textOpacity = CurvedAnimation(
        parent: _introCtrl,
        curve: const Interval(0.48, 0.88, curve: Curves.easeOut));

    _textY = Tween<double>(begin: 14.0, end: 0.0).animate(
        CurvedAnimation(
            parent: _introCtrl,
            curve: const Interval(0.48, 0.88, curve: Curves.easeOut)));

    _ctaSlide = Tween<double>(begin: 32.0, end: 0.0).animate(CurvedAnimation(
        parent: _introCtrl,
        curve: const Interval(0.68, 1.0, curve: Curves.elasticOut)));
  }

  @override
  void dispose() {
    _introCtrl.dispose();
    _rotCtrl.dispose();
    _pulseCtrl.dispose();
    _sparkCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: Stack(
        children: [
          // Subtle radial background glow
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (_, _) => CustomPaint(
                painter: _BackgroundGlowPainter(pulse: _pulseCtrl.value),
              ),
            ),
          ),
          SafeArea(
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
                          color: _kIce.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close_rounded,
                            size: 18, color: _kIceSoft),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // Crystal animation
                AnimatedBuilder(
                  animation: Listenable.merge(
                      [_introCtrl, _rotCtrl, _pulseCtrl, _sparkCtrl]),
                  builder: (_, _) => Opacity(
                    opacity: _crystalOpacity.value,
                    child: Transform.scale(
                      scale: _crystalScale.value,
                      child: SizedBox(
                        width: 190,
                        height: 190,
                        child: CustomPaint(
                          painter: _SnowflakePainter(
                            rotation: _rotCtrl.value * math.pi * 2,
                            pulse: _pulseCtrl.value,
                            sparkT: _sparkCtrl.value,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // Shield badge
                AnimatedBuilder(
                  animation: _introCtrl,
                  builder: (_, _) => Transform.scale(
                    scale: _badgeScale.value,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 22, vertical: 11),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [_kIceDark, _kIce],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: [
                          BoxShadow(
                            color: _kIce.withValues(alpha: 0.38),
                            blurRadius: 22,
                            offset: const Offset(0, 7),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.shield_rounded,
                              color: Colors.white, size: 21),
                          const SizedBox(width: 8),
                          Text(
                            '+${widget.freezesGranted} Seri Dondurma Hakkı',
                            style: GoogleFonts.nunito(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Text content
                AnimatedBuilder(
                  animation: _introCtrl,
                  builder: (_, _) => Opacity(
                    opacity: _textOpacity.value,
                    child: Transform.translate(
                      offset: Offset(0, _textY.value),
                      child: Column(
                        children: [
                          Text(
                            'TEBRİKLER',
                            style: GoogleFonts.nunito(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _kIce,
                              letterSpacing: 3.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          RichText(
                            textAlign: TextAlign.center,
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: '${widget.milestoneDays}',
                                  style: GoogleFonts.nunito(
                                    fontSize: 52,
                                    fontWeight: FontWeight.w900,
                                    color: _kIceSoft,
                                    height: 1.0,
                                  ),
                                ),
                                TextSpan(
                                  text: '\ngünlük seri!',
                                  style: GoogleFonts.nunito(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 44),
                            child: Text(
                              '${widget.milestoneDays} günlük serine özel ödül!\n'
                              'Serinle özgürce devam et.',
                              style: GoogleFonts.nunito(
                                fontSize: 14,
                                color: _kIceSoft.withValues(alpha: 0.7),
                                height: 1.6,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const Spacer(),

                // CTA
                AnimatedBuilder(
                  animation: _introCtrl,
                  builder: (_, _) => Transform.translate(
                    offset: Offset(0, _ctaSlide.value),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _kIce,
                            foregroundColor: _kBg,
                            padding:
                                const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                            elevation: 10,
                            shadowColor: _kIce.withValues(alpha: 0.38),
                          ),
                          child: Text(
                            'Harika!',
                            style: GoogleFonts.nunito(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 36),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Background radial glow ───────────────────────────────────────────────────

class _BackgroundGlowPainter extends CustomPainter {
  final double pulse;
  const _BackgroundGlowPainter({required this.pulse});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.38;
    final r = size.width * (0.55 + pulse * 0.08);
    canvas.drawCircle(
      Offset(cx, cy),
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFF60C8F0).withValues(alpha: 0.07 + pulse * 0.03),
            const Color(0xFF60C8F0).withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r)),
    );
  }

  @override
  bool shouldRepaint(_BackgroundGlowPainter o) => o.pulse != pulse;
}

// ─── Snowflake CustomPainter ──────────────────────────────────────────────────

class _SnowflakePainter extends CustomPainter {
  final double rotation;
  final double pulse;
  final double sparkT;

  const _SnowflakePainter({
    required this.rotation,
    required this.pulse,
    required this.sparkT,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final armLen = size.width / 2 * 0.78;
    final scale = 0.93 + pulse * 0.07;

    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(rotation);
    canvas.scale(scale);

    _drawHalo(canvas, armLen);

    for (int i = 0; i < 6; i++) {
      canvas.save();
      canvas.rotate(i * math.pi / 3);
      _drawArm(canvas, armLen);
      canvas.restore();
    }

    _drawCenter(canvas, pulse);
    canvas.restore();

    _drawOrbitSparkles(canvas, Offset(cx, cy), armLen * (scale + 0.22));
  }

  void _drawHalo(Canvas canvas, double r) {
    final opacity = 0.14 + pulse * 0.09;
    canvas.drawCircle(
      Offset.zero,
      r * 1.05,
      Paint()
        ..shader = RadialGradient(
          colors: [
            _kIce.withValues(alpha: opacity),
            _kIce.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: r * 1.05)),
    );
  }

  void _drawArm(Canvas canvas, double armLen) {
    final linePaint = Paint()
      ..color = _kIceSoft
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Main arm
    canvas.drawLine(Offset.zero, Offset(0, -armLen), linePaint);

    final branchPaint = Paint()
      ..color = _kIce
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final b1y = -armLen * 0.35;
    final b2y = -armLen * 0.60;
    final bLen = armLen * 0.23;
    const ang = math.pi / 4; // 45°

    for (final by in [b1y, b2y]) {
      // Right branch
      canvas.drawLine(
        Offset(0, by),
        Offset(math.sin(ang) * bLen, by - math.cos(ang) * bLen),
        branchPaint,
      );
      // Left branch
      canvas.drawLine(
        Offset(0, by),
        Offset(-math.sin(ang) * bLen, by - math.cos(ang) * bLen),
        branchPaint,
      );
    }

    // Tip diamond
    _drawDiamond(canvas, Offset(0, -armLen), armLen * 0.09);
  }

  void _drawDiamond(Canvas canvas, Offset pos, double r) {
    final path = Path()
      ..moveTo(pos.dx, pos.dy - r)
      ..lineTo(pos.dx + r * 0.55, pos.dy)
      ..lineTo(pos.dx, pos.dy + r)
      ..lineTo(pos.dx - r * 0.55, pos.dy)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..color = _kIceGlow
        ..style = PaintingStyle.fill,
    );
  }

  void _drawCenter(Canvas canvas, double pulse) {
    // Glow
    canvas.drawCircle(
      Offset.zero,
      9 + pulse * 3,
      Paint()
        ..color = _kIce.withValues(alpha: 0.35 + pulse * 0.15)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    // Solid center
    canvas.drawCircle(Offset.zero, 5.5, Paint()..color = _kIceGlow);
  }

  void _drawOrbitSparkles(Canvas canvas, Offset center, double orbitR) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    for (int i = 0; i < 9; i++) {
      final baseAng = (i / 9) * math.pi * 2;
      final t = (sparkT + i * 0.11) % 1.0;
      final angle = baseAng + sparkT * math.pi * 0.15;
      final dist = orbitR * (0.65 + (i % 3) * 0.18);

      final opacity = math.sin(t * math.pi).clamp(0.0, 1.0) * 0.75;
      if (opacity < 0.04) continue;
      final sz = 1.8 + (i % 3) * 1.1;

      canvas.drawCircle(
        Offset(math.cos(angle) * dist, math.sin(angle) * dist),
        sz,
        Paint()..color = _kIceSoft.withValues(alpha: opacity),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SnowflakePainter o) =>
      o.rotation != rotation || o.pulse != pulse || o.sparkT != sparkT;
}
