import 'dart:ui';

import 'package:flutter/material.dart';

/// Softly blurs its child with a gentle breathing pulse while [active] —
/// used on the Home money figures while the first cloud pull is running, so
/// the numbers read as "loading" instead of showing a misleading zero.
class SyncBlur extends StatefulWidget {
  const SyncBlur({super.key, required this.active, required this.child});

  final bool active;
  final Widget child;

  @override
  State<SyncBlur> createState() => _SyncBlurState();
}

class _SyncBlurState extends State<SyncBlur>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    if (widget.active) _c.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(SyncBlur old) {
    super.didUpdateWidget(old);
    if (widget.active && !_c.isAnimating) {
      _c.repeat(reverse: true);
    } else if (!widget.active && _c.isAnimating) {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return widget.child;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) {
        final sigma = 3.5 + _c.value * 2.5;
        return Opacity(
          opacity: 0.85 - _c.value * 0.15,
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
