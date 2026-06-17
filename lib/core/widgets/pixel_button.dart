import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/pixel_theme.dart';
import '../theme/typography.dart';

/// A chunky pixel button. On press it sinks into its own shadow for a tactile,
/// 8-bit feel.
class PixelButton extends StatefulWidget {
  const PixelButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.color = AppColors.bunOrange,
    this.foreground = AppColors.white,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color color;
  final Color foreground;
  final bool expand;

  @override
  State<PixelButton> createState() => _PixelButtonState();
}

class _PixelButtonState extends State<PixelButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final pressed = _down && enabled;
    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _down = true) : null,
      onTapUp: enabled ? (_) => setState(() => _down = false) : null,
      onTapCancel: enabled ? () => setState(() => _down = false) : null,
      onTap: widget.onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 60),
        transform: Matrix4.translationValues(
          pressed ? PixelTokens.shadowOffset.dx : 0,
          pressed ? PixelTokens.shadowOffset.dy : 0,
          0,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: enabled ? widget.color : AppColors.gray300,
          borderRadius: PixelTokens.borderRadius,
          border: PixelTokens.inkBorder(),
          boxShadow: pressed ? null : PixelTokens.hardShadow(),
        ),
        child: Row(
          mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (widget.icon != null) ...[
              Icon(widget.icon, size: 18, color: widget.foreground),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                widget.label,
                textAlign: TextAlign.center,
                style: AppTypography.body(
                  size: 15,
                  weight: FontWeight.w800,
                  color: widget.foreground,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
