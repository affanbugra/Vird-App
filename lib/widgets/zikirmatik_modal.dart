import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app_colors.dart';

class ZikirmatikModal extends StatefulWidget {
  final String title;
  final String? arabicTitle;
  final String description;
  final int initialCount;
  final int targetCount;
  final ValueChanged<int> onCountChanged;

  const ZikirmatikModal({
    super.key,
    required this.title,
    this.arabicTitle,
    required this.description,
    required this.initialCount,
    required this.targetCount,
    required this.onCountChanged,
  });

  static Future<int?> show(
    BuildContext context, {
    required String title,
    String? arabicTitle,
    required String description,
    required int initialCount,
    required int targetCount,
    required ValueChanged<int> onCountChanged,
  }) {
    return showGeneralDialog<int>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Zikirmatik',
      barrierColor: Colors.black.withValues(alpha: 0.88),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (ctx, anim1, anim2) {
        return ZikirmatikModal(
          title: title,
          arabicTitle: arabicTitle,
          description: description,
          initialCount: initialCount,
          targetCount: targetCount,
          onCountChanged: onCountChanged,
        );
      },
      transitionBuilder: (ctx, anim1, anim2, child) {
        final curve = CurvedAnimation(parent: anim1, curve: Curves.easeInOutCubic);
        return ScaleTransition(
          scale: anim1.drive(Tween<double>(begin: 0.94, end: 1.0)),
          child: FadeTransition(
            opacity: curve,
            child: child,
          ),
        );
      },
    );
  }

  @override
  State<ZikirmatikModal> createState() => _ZikirmatikModalState();
}

class _ZikirmatikModalState extends State<ZikirmatikModal> {
  late int _count;
  bool _vibrateEnabled = true;
  bool _soundEnabled = true;
  double _btnScale = 1.0;

  @override
  void initState() {
    super.initState();
    _count = widget.initialCount;
  }

  void _increment() {
    if (mounted) {
      setState(() {
        _count++;
        _btnScale = 0.90;
      });
      widget.onCountChanged(_count);

      // Haptic Feedback
      if (_vibrateEnabled) {
        if (_count == widget.targetCount) {
          // Target reached: strong double vibration
          HapticFeedback.heavyImpact();
          Future.delayed(const Duration(milliseconds: 150), () {
            HapticFeedback.heavyImpact();
          });
        } else {
          HapticFeedback.lightImpact();
        }
      }

      // Sound Feedback (System Click)
      if (_soundEnabled) {
        SystemSound.play(SystemSoundType.click);
      }

      // Restore button scale animation
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          setState(() {
            _btnScale = 1.0;
          });
        }
      });
    }
  }

  void _reset() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Sıfırla',
          style: GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Sayacı sıfırlamak istediğinize emin misiniz?',
          style: GoogleFonts.nunito(color: const Color(0xFFB3B3B3)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('İptal', style: GoogleFonts.nunito(color: AppColors.textLight)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.errorRed,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _count = 0);
              widget.onCountChanged(0);
              HapticFeedback.mediumImpact();
            },
            child: Text('Sıfırla', style: GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double progress = widget.targetCount > 0 ? (_count / widget.targetCount).clamp(0.0, 1.0) : 0.0;
    final bool isCompleted = _count >= widget.targetCount;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Ambient Glowing Background
          Positioned(
            top: -100,
            left: -100,
            right: -100,
            child: Container(
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCompleted
                    ? AppColors.successGreen.withValues(alpha: 0.1)
                    : AppColors.teal.withValues(alpha: 0.12),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                children: [
                  // App Bar / Top Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 28),
                        onPressed: () => Navigator.pop(context, _count),
                      ),
                      Text(
                        'ZİKİRMATİK',
                        style: GoogleFonts.nunito(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.tealSoft,
                          letterSpacing: 1.5,
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(
                              _soundEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                              color: _soundEnabled ? AppColors.tealSoft : Colors.white24,
                            ),
                            onPressed: () => setState(() => _soundEnabled = !_soundEnabled),
                          ),
                          IconButton(
                            icon: Icon(
                              _vibrateEnabled ? Icons.vibration_rounded : Icons.phone_android_rounded,
                              color: _vibrateEnabled ? AppColors.tealSoft : Colors.white24,
                            ),
                            onPressed: () => setState(() => _vibrateEnabled = !_vibrateEnabled),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Spacer(),

                  // Zikir Titles & Arabic
                  Text(
                    widget.title,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.nunito(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  if (widget.arabicTitle != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Text(
                        widget.arabicTitle!,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.amiri(
                          fontSize: 26,
                          color: AppColors.goldSoft,
                          height: 1.6,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      widget.description,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.nunito(
                        fontSize: 13,
                        color: Colors.white60,
                        height: 1.45,
                      ),
                    ),
                  ),
                  const Spacer(),

                  // Glowing Progression Ring & Counters
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      // Progress Circle
                      SizedBox(
                        width: 200,
                        height: 200,
                        child: CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 8,
                          backgroundColor: Colors.white10,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isCompleted ? AppColors.successGreen : AppColors.teal,
                          ),
                        ),
                      ),
                      // Core Display (Current Count)
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 150),
                            style: GoogleFonts.outfit(
                              fontSize: 54,
                              fontWeight: FontWeight.w900,
                              color: isCompleted ? AppColors.successGreen : Colors.white,
                              shadows: [
                                Shadow(
                                  blurRadius: 16,
                                  color: isCompleted
                                      ? AppColors.successGreen.withValues(alpha: 0.4)
                                      : AppColors.teal.withValues(alpha: 0.4),
                                )
                              ],
                            ),
                            child: Text('$_count'),
                          ),
                          Text(
                            '/ ${widget.targetCount}',
                            style: GoogleFonts.nunito(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white38,
                            ),
                          ),
                          if (isCompleted) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.successGreen.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'TAMAMLANDI ✓',
                                style: GoogleFonts.nunito(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.successGreen,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                  const Spacer(),

                  // Interactive Big Click Button
                  GestureDetector(
                    onTap: _increment,
                    child: AnimatedScale(
                      scale: _btnScale,
                      duration: const Duration(milliseconds: 80),
                      child: Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF1E1E1E),
                          border: Border.all(
                            color: isCompleted ? AppColors.successGreen : AppColors.teal,
                            width: 3.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isCompleted
                                  ? AppColors.successGreen.withValues(alpha: 0.25)
                                  : AppColors.teal.withValues(alpha: 0.25),
                              blurRadius: 20,
                              spreadRadius: 2,
                              offset: const Offset(0, 4),
                            ),
                            const BoxShadow(
                              color: Colors.black54,
                              blurRadius: 10,
                              offset: Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(
                            Icons.touch_app_rounded,
                            size: 42,
                            color: isCompleted ? AppColors.successGreen : AppColors.teal,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 36),

                  // Bottom Reset & Complete Action
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton.icon(
                        onPressed: _reset,
                        icon: const Icon(Icons.refresh_rounded, color: Colors.white54, size: 20),
                        label: Text(
                          'SIFIRLA',
                          style: GoogleFonts.nunito(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white54,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isCompleted ? AppColors.successGreen : AppColors.teal,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          elevation: 4,
                        ),
                        onPressed: () => Navigator.pop(context, _count),
                        child: Text(
                          'KAYDET VE KAPAT',
                          style: GoogleFonts.nunito(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
