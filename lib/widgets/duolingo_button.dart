import 'package:flutter/material.dart';

class DuolingoButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final Color color;
  final Color bottomColor;
  final Color disabledColor;
  final double height;
  final bool isLoading;
  final double borderRadius;

  const DuolingoButton({
    super.key,
    required this.onPressed,
    required this.child,
    required this.color,
    required this.bottomColor,
    this.disabledColor = const Color(0xFFD4D4D4),
    this.height = 44.0,
    this.isLoading = false,
    this.borderRadius = 999.0,
  });

  @override
  State<DuolingoButton> createState() => _DuolingoButtonState();
}

class _DuolingoButtonState extends State<DuolingoButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    const double depth = 4.0;
    final bool isDisabled = widget.onPressed == null || widget.isLoading;
    
    final Color topColor = isDisabled ? widget.disabledColor : widget.color;
    final Color btmColor = isDisabled ? widget.disabledColor : widget.bottomColor;

    return GestureDetector(
      onTapDown: isDisabled ? null : (_) => setState(() => _isPressed = true),
      onTapUp: isDisabled ? null : (_) {
        setState(() => _isPressed = false);
        widget.onPressed!();
      },
      onTapCancel: isDisabled ? null : () => setState(() => _isPressed = false),
      child: SizedBox(
        height: widget.height + depth,
        child: Stack(
          children: [
            // Alt katman (gövde / kalınlık)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              top: depth,
              child: Container(
                decoration: BoxDecoration(
                  color: btmColor,
                  borderRadius: BorderRadius.circular(widget.borderRadius),
                ),
              ),
            ),
            // Üst katman (buton yüzeyi)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 50),
              left: 0,
              right: 0,
              bottom: (isDisabled || _isPressed) ? 0 : depth,
              top: (isDisabled || _isPressed) ? depth : 0,
              child: Container(
                decoration: BoxDecoration(
                  color: topColor,
                  borderRadius: BorderRadius.circular(widget.borderRadius),
                ),
                alignment: Alignment.center,
                child: widget.isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : widget.child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
