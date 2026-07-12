import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../l10n/generated/app_localizations.dart';

/// Anchor keys for the first-run Home walkthrough. Each key must be attached
/// to exactly one widget (MainShell owns the FAB and nav items, HomeScreen
/// owns the period chip and spending card).
class HomeTourKeys {
  const HomeTourKeys._();
  static final fab = GlobalKey(debugLabel: 'tour-fab');
  static final wallet = GlobalKey(debugLabel: 'tour-wallet');
  static final periodChip = GlobalKey(debugLabel: 'tour-period');
  static final spendingCard = GlobalKey(debugLabel: 'tour-spending');
  static final slipRow = GlobalKey(debugLabel: 'tour-slip-row');
  static final recent = GlobalKey(debugLabel: 'tour-recent');
  static final navStats = GlobalKey(debugLabel: 'tour-stats');
  static final navSettings = GlobalKey(debugLabel: 'tour-settings');
}

class _TourStep {
  const _TourStep({
    required this.key,
    required this.title,
    required this.body,
    this.holeRadius = 20,
  });

  final GlobalKey key;
  final String title;
  final String body;
  final double holeRadius;
}

/// First-run walkthrough: a dimmed overlay with a spotlight hole moving from
/// one Home anchor to the next, with a friendly tooltip card. Tap anywhere to
/// advance, or skip. The overlay swallows all input, so the app underneath
/// can't be interacted with mid-tour (no FAB/sheet conflicts by construction).
class HomeTour {
  const HomeTour._();

  /// Shows the tour and completes when it finishes or is skipped. Steps whose
  /// anchor isn't currently laid out are silently dropped. Returns whether the
  /// tour was actually displayed — callers should only persist the seen-flag
  /// on true, so a launch where no anchor was ready gets another chance.
  static Future<bool> start(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final steps = <_TourStep>[
      _TourStep(
        key: HomeTourKeys.fab,
        title: l10n.tourFabTitle,
        body: l10n.tourFabBody,
        holeRadius: 30,
      ),
      _TourStep(
        key: HomeTourKeys.wallet,
        title: l10n.tourWalletTitle,
        body: l10n.tourWalletBody,
        holeRadius: 16,
      ),
      _TourStep(
        key: HomeTourKeys.periodChip,
        title: l10n.tourPeriodTitle,
        body: l10n.tourPeriodBody,
      ),
      _TourStep(
        key: HomeTourKeys.spendingCard,
        title: l10n.tourSpendTitle,
        body: l10n.tourSpendBody,
        holeRadius: 24,
      ),
      _TourStep(
        key: HomeTourKeys.recent,
        title: l10n.tourRecentTitle,
        body: l10n.tourRecentBody,
        holeRadius: 14,
      ),
      // Only present when a scanned slip row is on screen — skipped otherwise.
      _TourStep(
        key: HomeTourKeys.slipRow,
        title: l10n.tourSlipRowTitle,
        body: l10n.tourSlipRowBody,
        holeRadius: 18,
      ),
      _TourStep(
        key: HomeTourKeys.navStats,
        title: l10n.tourStatsTitle,
        body: l10n.tourStatsBody,
        holeRadius: 16,
      ),
      _TourStep(
        key: HomeTourKeys.navSettings,
        title: l10n.tourSettingsTitle,
        body: l10n.tourSettingsBody,
        holeRadius: 16,
      ),
    ].where((s) => s.key.currentContext != null).toList();
    if (steps.isEmpty) return Future.value(false);

    final completer = Completer<bool>();
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _TourOverlay(
        steps: steps,
        onDone: () {
          entry.remove();
          completer.complete(true);
        },
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(entry);
    return completer.future;
  }
}

class _TourOverlay extends StatefulWidget {
  const _TourOverlay({required this.steps, required this.onDone});

  final List<_TourStep> steps;
  final VoidCallback onDone;

  @override
  State<_TourOverlay> createState() => _TourOverlayState();
}

class _TourOverlayState extends State<_TourOverlay> {
  int _index = 0;
  Rect? _target;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  void _measure() {
    if (!mounted) return;
    final step = widget.steps[_index];
    final ctx = step.key.currentContext;
    final box = ctx?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) {
      // Anchor vanished (e.g. rebuilt away) — skip this step.
      _advance();
      return;
    }
    final rect = (box.localToGlobal(Offset.zero) & box.size).inflate(8);
    setState(() => _target = rect);
  }

  void _advance() {
    if (_index >= widget.steps.length - 1) {
      widget.onDone();
      return;
    }
    setState(() => _index++);
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final step = widget.steps[_index];
    final isLast = _index == widget.steps.length - 1;
    final screen = MediaQuery.of(context).size;
    final target = _target;

    return Material(
      type: MaterialType.transparency,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _advance,
        child: Stack(
          children: [
            // Dim everything except an animated spotlight hole on the anchor.
            Positioned.fill(
              child: target == null
                  ? const ColoredBox(color: Color(0x99211C18))
                  : TweenAnimationBuilder<Rect?>(
                      tween: RectTween(begin: target, end: target),
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      builder: (_, rect, __) => CustomPaint(
                        painter: _SpotlightPainter(
                          hole: rect!,
                          radius: step.holeRadius,
                        ),
                      ),
                    ),
            ),
            if (target != null)
              _TooltipCard(
                target: target,
                screen: screen,
                title: step.title,
                body: step.body,
                counter: l10n.tourStepOf(_index + 1, widget.steps.length),
                nextLabel: isLast ? l10n.tourDone : l10n.tourNext,
                skipLabel: l10n.tourSkip,
                showSkip: !isLast,
                onNext: _advance,
                onSkip: widget.onDone,
              ),
          ],
        ),
      ),
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  const _SpotlightPainter({required this.hole, required this.radius});

  final Rect hole;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final dim = Path()..addRect(Offset.zero & size);
    final cut = Path()
      ..addRRect(RRect.fromRectAndRadius(hole, Radius.circular(radius)));
    canvas.drawPath(
      Path.combine(PathOperation.difference, dim, cut),
      Paint()..color = const Color(0x99211C18),
    );
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) =>
      old.hole != hole || old.radius != radius;
}

class _TooltipCard extends StatelessWidget {
  const _TooltipCard({
    required this.target,
    required this.screen,
    required this.title,
    required this.body,
    required this.counter,
    required this.nextLabel,
    required this.skipLabel,
    required this.showSkip,
    required this.onNext,
    required this.onSkip,
  });

  final Rect target;
  final Size screen;
  final String title;
  final String body;
  final String counter;
  final String nextLabel;
  final String skipLabel;
  final bool showSkip;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    // Place the card on whichever side of the anchor has more room.
    final below = target.center.dy < screen.height / 2;
    return Positioned(
      left: 24,
      right: 24,
      top: below ? target.bottom + 18 : null,
      bottom: below ? null : screen.height - target.top + 18,
      child: Align(
        alignment: Alignment.center,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 330),
          child: GestureDetector(
            // Card taps shouldn't fall through to the barrier's tap-to-advance.
            onTap: () {},
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
              decoration: BoxDecoration(
                color: context.palette.bg,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: AppTypography.heading(
                      size: 16,
                      weight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    body,
                    style: AppTypography.body(
                      size: 13.5,
                      color: context.palette.ink2,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Text(
                        counter,
                        style: AppTypography.body(
                          size: 12.5,
                          color: context.palette.ink3,
                        ),
                      ),
                      const Spacer(),
                      if (showSkip) ...[
                        TextButton(
                          onPressed: onSkip,
                          child: Text(
                            skipLabel,
                            style: AppTypography.body(
                              size: 13.5,
                              color: context.palette.ink3,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                      ],
                      SizedBox(
                        height: 40,
                        child: FilledButton(
                          onPressed: onNext,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.terra,
                            foregroundColor: AppColors.reverse,
                            padding:
                                const EdgeInsets.symmetric(horizontal: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(13),
                            ),
                          ),
                          child: Text(
                            nextLabel,
                            style: AppTypography.heading(
                              size: 14,
                              weight: FontWeight.w500,
                              color: AppColors.reverse,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
