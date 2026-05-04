import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Seri değeri artığında kutu içinde alev animasyonu gösteren wrapper.
///
/// Faz 1 (0–0.35): Alevler aşağıdan yukarı doğru kutuyu doldurur
/// Faz 2 (0.35–0.65): Tam alev, ikon büyür ve sallanır
/// Faz 3 (0.65–1.0): Alevler söner, yeni değer ortaya çıkar
class SeriFireEffect extends StatefulWidget {
  final int seriValue;
  final Widget child;
  final BorderRadius borderRadius;

  const SeriFireEffect({
    super.key,
    required this.seriValue,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
  });

  @override
  State<SeriFireEffect> createState() => _SeriFireEffectState();
}

class _SeriFireEffectState extends State<SeriFireEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isFirstBuild = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
  }

  @override
  void didUpdateWidget(covariant SeriFireEffect oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.seriValue > oldWidget.seriValue && !_isFirstBuild) {
      // Bottom sheet'in kapanmasını beklemek için gecikme ekliyoruz
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) _controller.forward(from: 0);
      });
    }
    _isFirstBuild = false;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        final isAnimating = _controller.isAnimating;

        // Scale: kartı hafifçe büyüt, sonra geri
        final scale = isAnimating
            ? 1.0 + 0.04 * math.sin(t * math.pi)
            : 1.0;

        return Transform.scale(
          scale: scale,
          child: CustomPaint(
            painter: isAnimating
                ? _OuterGlowPainter(
                    progress: t,
                    borderRadius: widget.borderRadius,
                  )
                : null,
            foregroundPainter: isAnimating
                ? _FlameOverlayPainter(
                    progress: t,
                    borderRadius: widget.borderRadius,
                  )
                : null,
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

// ─── İç alev overlay ──────────────────────────────────────────────────────────

class _FlameOverlayPainter extends CustomPainter {
  final double progress;
  final BorderRadius borderRadius;

  _FlameOverlayPainter({required this.progress, required this.borderRadius});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    canvas.save();
    canvas.clipRRect(borderRadius.toRRect(Offset.zero & size));

    // Sönme fazında saydamlık
    final masterOpacity = progress < 0.75 
        ? 1.0 
        : 1.0 - Curves.easeIn.transform((progress - 0.75) / 0.25);
        
    if (masterOpacity <= 0) {
      canvas.restore();
      return;
    }

    // Patlama fazında alevin yukarı çıkış hızı
    final heightScale = progress < 0.2 
        ? Curves.easeOutCubic.transform(progress / 0.2) 
        : 1.0;

    final time = progress * 15; // Alevin dalgalanma hızı

    // Arka Plan (En koyu ve en yüksek)
    _drawFlameLayer(
      canvas, size, time, heightScale, masterOpacity, 
      tongueCount: 5, maxHeightFactor: 0.95, 
      baseColor: const Color(0xFFFF5722), seed: 42
    );
    
    // Orta Katman (Turuncu)
    _drawFlameLayer(
      canvas, size, time, heightScale, masterOpacity, 
      tongueCount: 4, maxHeightFactor: 0.70, 
      baseColor: const Color(0xFFFF9800), seed: 43
    );
    
    // Ön Katman (Sarı, en alçak)
    _drawFlameLayer(
      canvas, size, time, heightScale, masterOpacity, 
      tongueCount: 3, maxHeightFactor: 0.45, 
      baseColor: const Color(0xFFFFEB3B), seed: 44
    );

    // Kıvılcımlar
    if (heightScale > 0.4) {
      _drawSparks(canvas, size, time, heightScale, masterOpacity);
    }

    canvas.restore();
  }

  void _drawFlameLayer(
    Canvas canvas, 
    Size size, 
    double time, 
    double heightScale, 
    double opacity, {
    required int tongueCount, 
    required double maxHeightFactor, 
    required Color baseColor, 
    required int seed,
  }) {
    final rng = math.Random(seed);
    final path = Path();
    
    // Alt kısmı tamamen kapatıp boşluk kalmamasını sağlıyoruz
    path.addRect(Rect.fromLTRB(0, size.height - (size.height * 0.1 * heightScale), size.width, size.height));

    for (int i = 0; i < tongueCount; i++) {
      // Dilleri eşit aralıklarla tabana yay
      final cx = size.width * (i / (tongueCount == 1 ? 1 : tongueCount - 1)); 
      final w = size.width * (0.6 + rng.nextDouble() * 0.4); // Geniş tabanlar
      
      final flicker = math.sin(time * (1.2 + rng.nextDouble()) + i);
      final currentHeight = size.height * maxHeightFactor * heightScale * (0.7 + 0.3 * flicker);
      
      if (currentHeight < 1) continue;

      // Ateş dillerinin sağa sola hafif yalpalaması
      final sway = math.sin(time * 0.8 + i) * 12 * heightScale;
      final tipX = cx + sway;
      final tipY = size.height - currentHeight;

      path.moveTo(cx - w / 2, size.height);
      path.quadraticBezierTo(
        cx - w / 4 + sway * 0.5, size.height - currentHeight * 0.5, 
        tipX, tipY
      );
      path.quadraticBezierTo(
        cx + w / 4 + sway * 0.5, size.height - currentHeight * 0.5, 
        cx + w / 2, size.height
      );
    }
    
    canvas.drawPath(
      path,
      Paint()
        ..color = baseColor.withValues(alpha: baseColor.a * opacity)
        ..style = PaintingStyle.fill
    );
  }

  void _drawSparks(Canvas canvas, Size size, double time, double heightScale, double opacity) {
    final rng = math.Random(123);
    final sparkCount = 10;

    for (int i = 0; i < sparkCount; i++) {
      final startX = size.width * rng.nextDouble();
      final speedY = 1.0 + rng.nextDouble() * 2.0;
      final speedX = 0.5 + rng.nextDouble() * 1.5;
      
      // time ile kıvılcımlar yukarı hareket eder
      final travel = (time * speedY * 8 + i * 20);
      final y = size.height - (travel % (size.height * 1.2));
      
      if (y > size.height - 10) continue; // Tabanda patlamadan görünmesinler
      
      final sway = math.sin(time * speedX + i) * 15;
      final x = startX + sway;

      final sparkOpacity = (0.4 + rng.nextDouble() * 0.6) * opacity;
      final sparkSize = (1.0 + rng.nextDouble() * 2.0) * heightScale;

      final color = Color.lerp(const Color(0xFFFF9800), const Color(0xFFFFEB3B), rng.nextDouble())!;

      canvas.drawCircle(
        Offset(x.clamp(2.0, size.width - 2.0), y), 
        sparkSize, 
        Paint()..color = color.withValues(alpha: sparkOpacity)
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FlameOverlayPainter old) => old.progress != progress;
}

// ─── Dış glow ─────────────────────────────────────────────────────────────────

class _OuterGlowPainter extends CustomPainter {
  final double progress;
  final BorderRadius borderRadius;

  _OuterGlowPainter({required this.progress, required this.borderRadius});

  @override
  void paint(Canvas canvas, Size size) {
    // Glow: hızla görünür, yavaşça söner
    final glowIntensity = progress < 0.35
        ? Curves.easeOut.transform(progress / 0.35)
        : progress < 0.60
            ? 1.0
            : 1.0 - Curves.easeIn.transform((progress - 0.60) / 0.40);

    if (glowIntensity <= 0.01) return;

    final rect = Offset.zero & size;
    final rrect = borderRadius.toRRect(rect);

    // 3 katmanlı dış glow
    for (int i = 3; i >= 1; i--) {
      final spread = i * 4.0 * glowIntensity;
      final opacity = (0.2 * glowIntensity * (4 - i) / 3).clamp(0.0, 1.0);

      canvas.drawRRect(
        rrect.inflate(spread),
        Paint()
          ..color = const Color(0xFFFF6B00).withValues(alpha: opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = spread * 0.8
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, spread * 1.5),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _OuterGlowPainter old) => old.progress != progress;
}
