import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/colors.dart';

/// The flat paper card primitive: surface fill, 1px hairline border, rounded
/// corners, NO shadow. The single most-used container in the design.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = Tokens.rCard,
    this.color,
    this.border = true,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? color;
  final bool border;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final surface = color ?? Theme.of(context).colorScheme.surface;
    final shape = BorderRadius.circular(radius);
    final box = DecoratedBox(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: shape,
        border: border ? Tokens.hairline(_lineFor(context)) : null,
      ),
      child: Padding(padding: padding, child: child),
    );
    if (onTap == null) return box;
    return Material(
      color: Colors.transparent,
      borderRadius: shape,
      child: InkWell(
        onTap: onTap,
        borderRadius: shape,
        child: box,
      ),
    );
  }

  Color _lineFor(BuildContext context) =>
      Theme.of(context).dividerTheme.color ?? AppColors.line;
}
