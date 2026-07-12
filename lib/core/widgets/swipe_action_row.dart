import 'package:flutter/material.dart';

import '../theme/colors.dart';
import 'app_icons.dart';

/// iOS-style swipe action: drag the row slightly left and a red trash button
/// stays revealed; ONLY tapping the button triggers [onDeleteTap] (the caller
/// shows the confirm dialog). Dragging back, tapping the row, or opening
/// another row closes it — nothing is ever deleted by the swipe itself.
class SwipeActionRow extends StatefulWidget {
  const SwipeActionRow({
    super.key,
    required this.child,
    required this.onDeleteTap,
    this.backgroundColor,
  });

  final Widget child;
  final Future<void> Function() onDeleteTap;

  /// Opaque backing painted under the sliding child so the trash button never
  /// bleeds through. Defaults to the surface color; pass null-transparent via
  /// [Colors.transparent] for card-style rows that slide over the page bg.
  final Color? backgroundColor;

  @override
  State<SwipeActionRow> createState() => _SwipeActionRowState();
}

class _SwipeActionRowState extends State<SwipeActionRow>
    with SingleTickerProviderStateMixin {
  /// The row currently left open — iOS keeps at most one open at a time.
  static _SwipeActionRowState? _openRow;

  static const _actionWidth = 62.0;

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
  );

  bool get _isOpen => _c.value > 0.5;

  @override
  void dispose() {
    if (_openRow == this) _openRow = null;
    _c.dispose();
    super.dispose();
  }

  void _settle(bool open) {
    if (open) {
      if (_openRow != null && _openRow != this) _openRow!._settle(false);
      _openRow = this;
    } else if (_openRow == this) {
      _openRow = null;
    }
    _c.animateTo(
      open ? 1 : 0,
      curve: Curves.easeOutCubic,
      duration: const Duration(milliseconds: 240),
    );
  }

  void _onDragUpdate(DragUpdateDetails d) {
    _c.value = (_c.value - d.delta.dx / _actionWidth).clamp(0.0, 1.0);
  }

  void _onDragEnd(DragEndDetails d) {
    final v = d.primaryVelocity ?? 0;
    if (v < -250) {
      _settle(true);
    } else if (v > 250) {
      _settle(false);
    } else {
      _settle(_c.value > 0.45);
    }
  }

  Future<void> _tapDelete() async {
    await widget.onDeleteTap();
    // Whether deleted (row will leave the tree) or cancelled, slide shut.
    if (mounted) _settle(false);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: _onDragEnd,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) {
          final t = _c.value;
          return Stack(
            children: [
              // Trash button, revealed behind the sliding row: a compact
              // 44x44 soft-wash square with a red icon.
              Positioned.fill(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Opacity(
                    opacity: t.clamp(0.0, 1.0),
                    child: Transform.scale(
                      scale: 0.7 + 0.3 * t,
                      child: GestureDetector(
                        onTap: t > 0.6 ? _tapDelete : null,
                        child: Container(
                          width: 44,
                          height: 44,
                          margin: const EdgeInsets.only(right: 4),
                          decoration: BoxDecoration(
                            color: context.palette.dangerWash,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            AppIcons.trash2,
                            size: 20,
                            color: context.palette.dangerFg,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // The row itself, sliding left over an opaque surface so the
              // button never bleeds through.
              Transform.translate(
                offset: Offset(-t * _actionWidth, 0),
                child: ColoredBox(
                  color: widget.backgroundColor ?? context.palette.surface,
                  child: _isOpen
                      ? GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _settle(false),
                          child: AbsorbPointer(child: child),
                        )
                      : child,
                ),
              ),
            ],
          );
        },
        child: widget.child,
      ),
    );
  }
}
