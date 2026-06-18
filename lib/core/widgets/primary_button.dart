import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';

/// Full-width 54px primary button (accent fill, cream text, radius 16).
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.color,
    this.foreground = AppColors.reverse,
    this.loading = false,
    this.height = 54,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? color;
  final Color foreground;
  final bool loading;
  final double height;

  @override
  Widget build(BuildContext context) {
    final bg = color ?? Theme.of(context).colorScheme.primary;
    final enabled = onPressed != null && !loading;
    return SizedBox(
      width: double.infinity,
      height: height,
      child: Material(
        color: enabled ? bg : bg.withValues(alpha: 0.5),
        borderRadius: Tokens.input,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: Tokens.input,
          child: Center(
            child: loading
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.4, color: foreground),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, size: 20, color: foreground),
                        const SizedBox(width: 8),
                      ],
                      Text(label,
                          style: AppTypography.heading(
                              size: 17,
                              weight: FontWeight.w500,
                              color: foreground)),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// Full-width outlined button (1.5px line border, ink text).
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.dashed = false,
    this.color,
    this.height = 54,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool dashed;
  final Color? color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.onSurface;
    final border = color ?? AppColors.line;
    return SizedBox(
      width: double.infinity,
      height: height,
      child: Material(
        color: Colors.transparent,
        borderRadius: Tokens.input,
        child: InkWell(
          onTap: onPressed,
          borderRadius: Tokens.input,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: Tokens.input,
              border: Border.all(color: border, width: 1.5),
            ),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 20, color: c),
                    const SizedBox(width: 8),
                  ],
                  Text(label,
                      style: AppTypography.heading(
                          size: 16, weight: FontWeight.w500, color: c)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 50px outlined social-login button (icon + label).
class SocialButton extends StatelessWidget {
  const SocialButton({
    super.key,
    required this.icon,
    required this.label,
    this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    return Expanded(
      child: SizedBox(
        height: 50,
        child: Material(
          color: surface,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(14),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Tokens.hairline(),
              ),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 18, color: AppColors.ink),
                    const SizedBox(width: 9),
                    Text(label,
                        style: AppTypography.heading(
                            size: 14, weight: FontWeight.w500)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
