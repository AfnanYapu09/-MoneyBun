import 'package:flutter/material.dart';

/// Fade + rise-up entrance for a single child, after an optional [delay].
/// Mirrors the design's `mb-rise` / `mb-stagger` motion.
class RiseIn extends StatefulWidget {
  const RiseIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offset = 12,
  });

  final Widget child;
  final Duration delay;
  final double offset;

  @override
  State<RiseIn> createState() => _RiseInState();
}

class _RiseInState extends State<RiseIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 480),
  );
  late final Animation<double> _curve =
      CurvedAnimation(parent: _c, curve: const Cubic(0.22, 1, 0.36, 1));

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _c.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curve,
      builder: (_, child) => Opacity(
        opacity: _curve.value,
        child: Transform.translate(
          offset: Offset(0, widget.offset * (1 - _curve.value)),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}

/// A Column whose direct children rise-fade in sequence (`mb-stagger`).
class StaggeredColumn extends StatelessWidget {
  const StaggeredColumn({
    super.key,
    required this.children,
    this.spacing = 18,
    this.crossAxisAlignment = CrossAxisAlignment.stretch,
    this.step = const Duration(milliseconds: 40),
    this.base = const Duration(milliseconds: 30),
  });

  final List<Widget> children;
  final double spacing;
  final CrossAxisAlignment crossAxisAlignment;
  final Duration step;
  final Duration base;

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) items.add(SizedBox(height: spacing));
      items.add(RiseIn(
        delay: base + step * i,
        child: children[i],
      ));
    }
    return Column(crossAxisAlignment: crossAxisAlignment, children: items);
  }
}
