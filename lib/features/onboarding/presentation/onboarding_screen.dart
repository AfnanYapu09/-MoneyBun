import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../bootstrap/providers.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/app_icons.dart';
import '../../../core/widgets/app_motion.dart';
import '../../../core/widgets/bun_avatar.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../l10n/generated/app_localizations.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  static const _pageCount = 3;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _seen() =>
      ref.read(settingsRepositoryProvider).setOnboardingSeen(true);

  Future<void> _finish(String route) async {
    await _seen();
    if (mounted) context.go(route);
  }

  void _next() {
    _controller.nextPage(
      duration: const Duration(milliseconds: 340),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isLast = _page == _pageCount - 1;
    final pages = [
      (
        stage: const _SlipScanStage(),
        title: l10n.onb1Title,
        body: l10n.onb1Body,
      ),
      (
        stage: const _BudgetStage(),
        title: l10n.onb2Title,
        body: l10n.onb2Body,
      ),
      (
        stage: const _CloudStage(),
        title: l10n.onb3Title,
        body: l10n.onb3Body,
      ),
    ];
    return Scaffold(
      backgroundColor: context.palette.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 30),
          child: Column(
            children: [
              // Keep the header height stable so the pages don't jump when
              // Skip disappears on the last slide.
              SizedBox(
                height: 44,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 180),
                    opacity: isLast ? 0 : 1,
                    child: TextButton(
                      onPressed: isLast ? null : () => _finish('/login'),
                      child: Text(
                        l10n.onbSkip,
                        style: AppTypography.body(
                          size: 14,
                          color: context.palette.ink3,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemCount: _pageCount,
                  itemBuilder: (_, i) => _OnbPage(
                    controller: _controller,
                    index: i,
                    active: _page == i,
                    stage: pages[i].stage,
                    title: pages[i].title,
                    body: pages[i].body,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _pageCount,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    width: i == _page ? 22 : 7,
                    height: 7,
                    margin: const EdgeInsets.symmetric(horizontal: 3.5),
                    decoration: BoxDecoration(
                      color: i == _page
                          ? AppColors.terra
                          : context.palette.line,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              // Fixed-height footer: one button on early pages, two on the
              // last, without the layout shifting underneath the PageView.
              SizedBox(
                height: 120,
                child: isLast
                    ? Column(
                        children: [
                          PrimaryButton(
                            label: l10n.onbGetStarted,
                            // Cloud-only: new users create an account to start.
                            onPressed: () => _finish('/signup'),
                          ),
                          const SizedBox(height: 12),
                          SecondaryButton(
                            label: l10n.onbHaveAccount,
                            onPressed: () => _finish('/login'),
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          PrimaryButton(label: l10n.onbNext, onPressed: _next),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnbPage extends StatelessWidget {
  const _OnbPage({
    required this.controller,
    required this.index,
    required this.active,
    required this.stage,
    required this.title,
    required this.body,
  });

  final PageController controller;
  final int index;
  final bool active;
  final Widget stage;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        children: [
          const SizedBox(height: 8),
          // Gentle parallax: the stage drifts slower than the swipe.
          AnimatedBuilder(
            animation: controller,
            builder: (_, child) {
              double delta = 0;
              if (controller.hasClients &&
                  controller.position.haveDimensions) {
                delta = (controller.page ?? index.toDouble()) - index;
              }
              return Transform.translate(
                offset: Offset(delta * 44, 0),
                child: child,
              );
            },
            child: stage,
          ),
          const SizedBox(height: 30),
          // Remount on activation so the copy replays its rise-in each time
          // the page comes into view.
          KeyedSubtree(
            key: ValueKey(active),
            child: Column(
              children: [
                RiseIn(
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: AppTypography.heading(
                      size: 25,
                      weight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                RiseIn(
                  delay: const Duration(milliseconds: 90),
                  child: Text(
                    body,
                    textAlign: TextAlign.center,
                    style: AppTypography.body(
                      size: 15,
                      color: context.palette.ink2,
                      height: 1.55,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---- Stages -----------------------------------------------------------------

/// Rounded washed backdrop with pixel-style corner deco, sized for all three
/// scenes so the pages line up.
class _Stage extends StatelessWidget {
  const _Stage({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 300,
      height: 260,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 280,
            height: 248,
            decoration: BoxDecoration(
              color: context.palette.terraWash,
              borderRadius: BorderRadius.circular(48),
            ),
          ),
          // Pixel confetti echoing the mascot's blocky style.
          const _PixelDot(top: 26, left: 30, size: 10, alpha: 0.35),
          const _PixelDot(top: 52, left: 48, size: 6, alpha: 0.22),
          const _PixelDot(bottom: 34, right: 36, size: 12, alpha: 0.3),
          const _PixelDot(bottom: 58, right: 22, size: 7, alpha: 0.2),
          ...children,
        ],
      ),
    );
  }
}

class _PixelDot extends StatelessWidget {
  const _PixelDot({
    this.top,
    this.left,
    this.right,
    this.bottom,
    required this.size,
    required this.alpha,
  });

  final double? top, left, right, bottom;
  final double size;
  final double alpha;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      bottom: bottom,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.terra.withValues(alpha: alpha),
          borderRadius: BorderRadius.circular(size * 0.28),
        ),
      ),
    );
  }
}

/// Loops a soft vertical bob; [phase] staggers siblings so they don't move in
/// lockstep.
class _Bob extends StatefulWidget {
  const _Bob({required this.child, this.phase = 0, this.amplitude = 5});

  final Widget child;
  final double phase;
  final double amplitude;

  @override
  State<_Bob> createState() => _BobState();
}

class _BobState extends State<_Bob> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) => Transform.translate(
        offset: Offset(
          0,
          math.sin((_c.value + widget.phase) * 2 * math.pi) * widget.amplitude,
        ),
        child: child,
      ),
      child: widget.child,
    );
  }
}

class _FloatChip extends StatelessWidget {
  const _FloatChip({required this.icon, this.size = 46});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: context.palette.bg,
        borderRadius: BorderRadius.circular(size * 0.32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: size * 0.48, color: AppColors.terra),
    );
  }
}

/// Page 1 — Bun reading a slip: mascot, a tilted mock slip card, scan + slip
/// chips bobbing around it.
class _SlipScanStage extends StatelessWidget {
  const _SlipScanStage();

  @override
  Widget build(BuildContext context) {
    return const _Stage(
      children: [
        Positioned(bottom: 44, child: BunAvatar(size: 118)),
        Positioned(
          top: 34,
          left: 34,
          child: _Bob(
            phase: 0.15,
            amplitude: 6,
            child: _MockSlipCard(),
          ),
        ),
        Positioned(
          top: 44,
          right: 38,
          child: _Bob(
            phase: 0.55,
            child: _FloatChip(icon: AppIcons.scanLine),
          ),
        ),
        Positioned(
          bottom: 52,
          right: 44,
          child: _Bob(
            phase: 0.85,
            amplitude: 4,
            child: _FloatChip(icon: AppIcons.receiptText, size: 40),
          ),
        ),
      ],
    );
  }
}

/// A little fake bank slip — language-neutral bars instead of text.
class _MockSlipCard extends StatelessWidget {
  const _MockSlipCard();

  @override
  Widget build(BuildContext context) {
    Widget bar(double w, Color c) => Container(
          width: w,
          height: 7,
          decoration: BoxDecoration(
            color: c,
            borderRadius: BorderRadius.circular(4),
          ),
        );
    final line = context.palette.line;
    return Transform.rotate(
      angle: -0.07,
      child: Container(
        width: 108,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: context.palette.bg,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: context.palette.greenTint,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    AppIcons.check,
                    size: 9,
                    color: context.palette.greenFg,
                  ),
                ),
                const SizedBox(width: 7),
                bar(42, line),
              ],
            ),
            const SizedBox(height: 9),
            bar(80, line),
            const SizedBox(height: 6),
            bar(58, line),
            const SizedBox(height: 10),
            bar(66, AppColors.terra.withValues(alpha: 0.75)),
          ],
        ),
      ),
    );
  }
}

/// Page 2 — Bun the accountant: calculator mascot with a mini bar chart and a
/// piggy-bank chip.
class _BudgetStage extends StatelessWidget {
  const _BudgetStage();

  @override
  Widget build(BuildContext context) {
    return const _Stage(
      children: [
        Positioned(bottom: 38, child: BunCalculator(width: 196)),
        Positioned(
          top: 38,
          left: 40,
          child: _Bob(
            phase: 0.2,
            child: _MiniChartChip(),
          ),
        ),
        Positioned(
          top: 52,
          right: 40,
          child: _Bob(
            phase: 0.7,
            amplitude: 4,
            child: _FloatChip(icon: AppIcons.piggyBank, size: 42),
          ),
        ),
      ],
    );
  }
}

class _MiniChartChip extends StatelessWidget {
  const _MiniChartChip();

  @override
  Widget build(BuildContext context) {
    Widget bar(double h, Color c) => Container(
          width: 8,
          height: h,
          decoration: BoxDecoration(
            color: c,
            borderRadius: BorderRadius.circular(3),
          ),
        );
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
      decoration: BoxDecoration(
        color: context.palette.bg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          bar(12, context.palette.greenFg.withValues(alpha: 0.8)),
          const SizedBox(width: 5),
          bar(20, context.palette.amberFg.withValues(alpha: 0.8)),
          const SizedBox(width: 5),
          bar(27, AppColors.terra),
        ],
      ),
    );
  }
}

/// Page 3 — safe in the cloud: mascot under a big cloud chip, with phone and
/// laptop chips staying in sync.
class _CloudStage extends StatelessWidget {
  const _CloudStage();

  @override
  Widget build(BuildContext context) {
    return const _Stage(
      children: [
        Positioned(bottom: 40, child: BunAvatar(size: 116)),
        Positioned(
          top: 30,
          child: _Bob(
            phase: 0.1,
            amplitude: 6,
            child: _FloatChip(icon: AppIcons.cloud, size: 54),
          ),
        ),
        Positioned(
          top: 84,
          left: 42,
          child: _Bob(
            phase: 0.5,
            amplitude: 4,
            child: _FloatChip(icon: AppIcons.smartphone, size: 40),
          ),
        ),
        Positioned(
          top: 84,
          right: 42,
          child: _Bob(
            phase: 0.9,
            amplitude: 4,
            child: _FloatChip(icon: AppIcons.laptop, size: 40),
          ),
        ),
      ],
    );
  }
}
