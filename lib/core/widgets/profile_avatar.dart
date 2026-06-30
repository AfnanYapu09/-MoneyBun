import 'dart:io';

import 'package:flutter/material.dart';

import '../theme/colors.dart';
import 'bun_avatar.dart';

/// The user's avatar: their chosen photo (from [avatarPath]) when set and the
/// file still exists, otherwise the Bun mascot. Stateless — the caller watches
/// settings and passes the path, so it updates wherever it's shown.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.avatarPath,
    required this.size,
    this.radius,
    this.bunSize,
    this.bunVariant = BunVariant.normal,
    this.bunBackground,
  });

  /// Absolute path to the photo, or null to show the mascot.
  final String? avatarPath;

  /// Diameter (circle) / side length (rounded square) in logical pixels.
  final double size;

  /// Corner radius; null → a full circle.
  final double? radius;

  /// Mascot size for the fallback (defaults to ~72% of [size]).
  final double? bunSize;
  final BunVariant bunVariant;

  /// Background behind the mascot fallback.
  final Color? bunBackground;

  @override
  Widget build(BuildContext context) {
    final path = avatarPath;
    final hasPhoto = path != null && path.isNotEmpty && File(path).existsSync();
    final br = BorderRadius.circular(radius ?? size);

    if (hasPhoto) {
      return ClipRRect(
        borderRadius: br,
        child: Image.file(
          File(path),
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      );
    }
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bunBackground ?? context.palette.terraWash,
        borderRadius: br,
      ),
      child: BunAvatar(size: bunSize ?? size * 0.72, variant: bunVariant),
    );
  }
}
