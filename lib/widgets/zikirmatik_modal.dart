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

  void _showManualCountDialog() {
    final controller = TextEditingController(text: _count > 0 ? _count.toString() : '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Adet Gir',
          style: GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Okuduğunuz adeti girin',
              style: GoogleFonts.nunito(color: const Color(0xFFB3B3B3), fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: GoogleFonts.outfit(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
              autofocus: true,
              decoration: InputDecoration(
                hintText: '0',
                hintStyle: GoogleFonts.outfit(color: Colors.white24, fontSize: 28),
                enabledBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white24),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.teal, width: 2),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('İptal', style: GoogleFonts.nunito(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.teal,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            onPressed: () {
              final val = (int.tryParse(controller.text) ?? _count).clamp(0, widget.targetCount);
              Navigator.pop(ctx);
              setState(() => _count = val);
              widget.onCountChanged(_count);
              HapticFeedback.mediumImpact();
            },
            child: Text('Uygula', style: GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
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
    final Color accentColor = isCompleted ? AppColors.successGreen : AppColors.teal;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Ambient Glowing Background
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 220,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 1.0,
                  colors: [
                    accentColor.withValues(alpha: 0.18),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // ── HEADER ──────────────────────────────────
                  Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 24),
                                onPressed: () => Navigator.pop(context, _count),
                              ),
                            ),
                          ),
                          Text(
                            'ZİKİRMATİK',
                            style: GoogleFonts.nunito(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.tealSoft,
                              letterSpacing: 1.5,
                            ),
                          ),
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  icon: Icon(
                                    _soundEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                                    color: _soundEnabled ? AppColors.tealSoft : Colors.white24,
                                    size: 20,
                                  ),
                                  onPressed: () => setState(() => _soundEnabled = !_soundEnabled),
                                ),
                                const SizedBox(width: 12),
                                IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  icon: Icon(
                                    _vibrateEnabled ? Icons.vibration_rounded : Icons.phone_android_rounded,
                                    color: _vibrateEnabled ? AppColors.tealSoft : Colors.white24,
                                    size: 20,
                                  ),
                                  onPressed: () => setState(() => _vibrateEnabled = !_vibrateEnabled),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        widget.title,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.nunito(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      if (widget.arabicTitle != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Text(
                            widget.arabicTitle!,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.amiri(
                              fontSize: 22,
                              color: AppColors.goldSoft,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Text(
                        widget.description,
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.nunito(
                          fontSize: 11,
                          color: Colors.white54,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),

                  // ── SAYAÇ + BUTON + ALT SATIR ────────────────
                  Column(
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 144,
                            height: 144,
                            child: CircularProgressIndicator(
                              value: progress,
                              strokeWidth: 6,
                              backgroundColor: Colors.white10,
                              valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 150),
                                style: GoogleFonts.outfit(
                                  fontSize: 42,
                                  fontWeight: FontWeight.w900,
                                  color: isCompleted ? AppColors.successGreen : Colors.white,
                                  shadows: [
                                    Shadow(
                                      blurRadius: 14,
                                      color: accentColor.withValues(alpha: 0.4),
                                    ),
                                  ],
                                ),
                                child: Text('$_count'),
                              ),
                              Text(
                                '/ ${widget.targetCount}',
                                style: GoogleFonts.nunito(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white38,
                                ),
                              ),
                              if (isCompleted) ...[
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.successGreen.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
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
                      const SizedBox(height: 18),
                      GestureDetector(
                        onTap: _increment,
                        child: AnimatedScale(
                          scale: _btnScale,
                          duration: const Duration(milliseconds: 80),
                          child: Container(
                            width: 76,
                            height: 76,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF1E1E1E),
                              border: Border.all(color: accentColor, width: 2.5),
                              boxShadow: [
                                BoxShadow(
                                  color: accentColor.withValues(alpha: 0.25),
                                  blurRadius: 14,
                                  spreadRadius: 1,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Icon(Icons.touch_app_rounded, size: 30, color: accentColor),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton.icon(
                                onPressed: _reset,
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                icon: const Icon(Icons.refresh_rounded, color: Colors.white54, size: 16),
                                label: Text(
                                  'SIFIRLA',
                                  style: GoogleFonts.nunito(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white54,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              TextButton.icon(
                                onPressed: _showManualCountDialog,
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                icon: const Icon(Icons.edit_rounded, color: Colors.white54, size: 14),
                                label: Text(
                                  'ADET GİR',
                                  style: GoogleFonts.nunito(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white54,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: accentColor,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                              elevation: 3,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () => Navigator.pop(context, _count),
                            child: Text(
                              'KAYDET VE KAPAT',
                              style: GoogleFonts.nunito(
                                fontSize: 11,
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
