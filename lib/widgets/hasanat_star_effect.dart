import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Hasanat değeri artığında kutu etrafında parlayan yıldızlar animasyonu gösteren wrapper.
///
/// Kart hafifçe büyüyüp küçülür, dışına altın sarısı bir glow yayılır
/// ve merkezinden dışarı doğru yıldızlar fırlar.
class HasanatStarEffect extends StatefulWidget {
  final int hasanatValue;
  final Widget child;
  final BorderRadius borderRadius;

  const HasanatStarEffect({
    super.key,
    required this.hasanatValue,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
  });

  @override
  State<HasanatStarEffect> createState() => _HasanatStarEffectState();
}

class _HasanatStarEffectState extends State<HasanatStarEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isFirstBuild = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
  }

  @override
  void didUpdateWidget(covariant HasanatStarEffect oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.hasanatValue > oldWidget.hasanatValue && !_isFirstBuild) {
      // Modal'ın kapanması için hafif gecikme
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

        // Pop efekti: %5 büyüyüp küçülür
        final scale = isAnimating
            ? 1.0 + 0.05 * math.sin(t * math.pi)
            : 1.0;

        return Transform.scale(
          scale: scale,
          child: CustomPaint(
            // Dış glow arkada
            painter: isAnimating 
                ? _StarGlowPainter(progress: t, borderRadius: widget.borderRadius) 
                : null,
            // Yıldızlar önde
            foregroundPainter: isAnimating 
                ? _StarForegroundPainter(progress: t) 
                : null,
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

// ─── Dış Altın Parıltı ────────────────────────────────────────────────────────

class _StarGlowPainter extends CustomPainter {
  final double progress;
  final BorderRadius borderRadius;

  _StarGlowPainter({required this.progress, required this.borderRadius});

  @override
  void paint(Canvas canvas, Size size) {
    final glowIntensity = progress < 0.2 
        ? Curves.easeOut.transform(progress / 0.2) 
        : progress < 0.6 
            ? 1.0 
            : 1.0 - Curves.easeIn.transform((progress - 0.6) / 0.4);

    if (glowIntensity <= 0.01) return;

    final rect = Offset.zero & size;
    final rrect = borderRadius.toRRect(rect);

    for (int i = 3; i >= 1; i--) {
      final spread = i * 4.0 * glowIntensity;
      final opacity = (0.3 * glowIntensity * (4 - i) / 3).clamp(0.0, 1.0);

      canvas.drawRRect(
        rrect.inflate(spread),
        Paint()
          ..color = const Color(0xFFFFC107).withValues(alpha: opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = spread * 0.8
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, spread * 1.5),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StarGlowPainter old) => old.progress != progress;
}

// ─── Dışarı Saçılan Yıldızlar ─────────────────────────────────────────────────

class _StarForegroundPainter extends CustomPainter {
  final double progress;

  _StarForegroundPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;

    final centerX = size.width / 2;
    final centerY = size.height / 2;

    // Sabit seed kullanarak animasyon süresince yıldızların pozisyonlarının titrememesini sağlıyoruz
    final rng = math.Random(100); 
    // Daha yoğun yıldızlar
    final int numStars = 45; 

    // Patlama için hızlı çıkış eğrisi
    final travelProgress = Curves.easeOutCubic.transform(progress);
    
    for (int i = 0; i < numStars; i++) {
      // Yıldızları merkezde değil, kutunun iç alanına biraz dağıtarak başlatıyoruz
      final startX = centerX + (rng.nextDouble() - 0.5) * size.width * 0.6;
      final startY = centerY + (rng.nextDouble() - 0.5) * size.height * 0.6;

      final angle = rng.nextDouble() * 2 * math.pi;
      // Çok uzağa uçmasınlar, kısa mesafe yayılsınlar
      final speed = 0.2 + rng.nextDouble() * 0.5; 
      final distance = travelProgress * 60 * speed;
      
      final x = startX + math.cos(angle) * distance;
      final y = startY + math.sin(angle) * distance;

      // Yıldızlar önce büyür sonra yavaşça küçülür
      final sizeScale = progress < 0.2 
          ? progress / 0.2 
          : 1.0 - Curves.easeIn.transform((progress - 0.2) / 0.8);
      
      final baseSize = 6.0 + rng.nextDouble() * 12.0; // Biraz daha irili ufaklı
      final starSize = baseSize * sizeScale;
      
      // Yıldızların etrafında dönmesi
      final rotationDir = rng.nextBool() ? 1 : -1;
      final rotation = travelProgress * math.pi * 3 * rotationDir + rng.nextDouble() * math.pi;
      
      final opacity = progress < 0.6 ? 1.0 : 1.0 - ((progress - 0.6) / 0.4);
      
      if (starSize < 0.5 || opacity <= 0) continue;

      final isGold = rng.nextDouble() > 0.4;
      final color = isGold ? const Color(0xFFFFC107) : const Color(0xFFFFEB3B);

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rotation);
      
      final path = _createStarPath(starSize, starSize * 0.45);
      
      canvas.drawPath(
        path,
        Paint()
          ..color = color.withValues(alpha: opacity)
          ..style = PaintingStyle.fill
      );
      
      canvas.restore();
    }
  }

  Path _createStarPath(double radius, double innerRadius) {
    final path = Path();
    final int points = 5;
    final double step = math.pi / points;
    for (int i = 0; i < 2 * points; i++) {
      final double r = (i % 2 == 0) ? radius : innerRadius;
      final double angle = i * step - math.pi / 2;
      final x = r * math.cos(angle);
      final y = r * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant _StarForegroundPainter old) => old.progress != progress;
}
