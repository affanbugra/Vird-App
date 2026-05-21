import 'package:flutter/material.dart';

// ─── Staggered Fade + Slide Animasyonu ─────────────────────────────────────
/// Liste elemanlarını sırayla fade+slide ile gösterir.
/// [index] öğenin sıradaki yeri, [child] animasyonlanacak widget.
class StaggeredFadeSlide extends StatefulWidget {
  final int index;
  final Widget child;
  final Duration delay;
  final Duration duration;
  final Offset beginOffset;

  const StaggeredFadeSlide({
    super.key,
    required this.index,
    required this.child,
    this.delay = const Duration(milliseconds: 60),
    this.duration = const Duration(milliseconds: 400),
    this.beginOffset = const Offset(0, 0.08),
  });

  @override
  State<StaggeredFadeSlide> createState() => _StaggeredFadeSlideState();
}

class _StaggeredFadeSlideState extends State<StaggeredFadeSlide>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween(begin: widget.beginOffset, end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    Future.delayed(widget.delay * widget.index, () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

// ─── FadeIn animasyonu ─────────────────────────────────────────────────────
/// Tekil widget'ları fade-in yapar.
class FadeIn extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Duration delay;

  const FadeIn({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 500),
    this.delay = Duration.zero,
  });

  @override
  State<FadeIn> createState() => _FadeInState();
}

class _FadeInState extends State<FadeIn> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    Future.delayed(widget.delay, () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
      child: widget.child,
    );
  }
}

// ─── Scale Bounce animasyonu ───────────────────────────────────────────────
/// Küçükten büyüğe bounce efekti ile görünür.
class ScaleBounce extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Duration delay;

  const ScaleBounce({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 600),
    this.delay = Duration.zero,
  });

  @override
  State<ScaleBounce> createState() => _ScaleBounceState();
}

class _ScaleBounceState extends State<ScaleBounce>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    Future.delayed(widget.delay, () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: widget.child,
    );
  }
}

// ─── Animated Counter ──────────────────────────────────────────────────────
/// Sayıları 0'dan hedef değere animasyonlu olarak sayar.
class AnimatedCounter extends StatelessWidget {
  final int value;
  final TextStyle? style;
  final String suffix;
  final Duration duration;

  const AnimatedCounter({
    super.key,
    required this.value,
    this.style,
    this.suffix = '',
    this.duration = const Duration(milliseconds: 800),
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: value),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text('$v$suffix', style: style),
    );
  }
}

// ─── Animated Progress Bar ─────────────────────────────────────────────────
/// İlerleme çubuğunu 0'dan hedef değere animasyonlu olarak doldurur.
class AnimatedProgressBar extends StatelessWidget {
  final double value;
  final Duration duration;
  final Color backgroundColor;
  final Color valueColor;
  final double height;

  const AnimatedProgressBar({
    super.key,
    required this.value,
    this.duration = const Duration(milliseconds: 900),
    this.backgroundColor = const Color(0xFFE5E5E5),
    this.valueColor = const Color(0xFF2A7F8C),
    this.height = 6,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: LinearProgressIndicator(
          value: v,
          minHeight: height,
          backgroundColor: backgroundColor,
          valueColor: AlwaysStoppedAnimation<Color>(valueColor),
        ),
      ),
    );
  }
}

// ─── Sayfa Geçiş Animasyonu ────────────────────────────────────────────────
/// Material page route yerine kullanılan güzel geçiş animasyonu.
class SlideUpRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  SlideUpRoute({required this.page})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: const Duration(milliseconds: 350),
          reverseTransitionDuration: const Duration(milliseconds: 300),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curve = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );
            return SlideTransition(
              position: Tween(
                begin: const Offset(0, 0.15),
                end: Offset.zero,
              ).animate(curve),
              child: FadeTransition(opacity: curve, child: child),
            );
          },
        );
}

// ─── Pulse animasyonu ──────────────────────────────────────────────────────
/// Dikkat çekmek için hafif pulse efekti uygular.
class Pulse extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final double minScale;
  final double maxScale;

  const Pulse({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 1500),
    this.minScale = 0.97,
    this.maxScale = 1.03,
  });

  @override
  State<Pulse> createState() => _PulseState();
}

class _PulseState extends State<Pulse> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration)
      ..repeat(reverse: true);
    _scale = Tween(begin: widget.minScale, end: widget.maxScale)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(scale: _scale, child: widget.child);
  }
}
