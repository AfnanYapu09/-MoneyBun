import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../bootstrap/providers.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/app_icons.dart';
import '../../../core/widgets/bun_avatar.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/sub_screen_scaffold.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../domain/plan.dart';
import '../domain/quota_period.dart';

/// ตั้งค่า → (แถบโควต้า) → แพลนสมาชิก: swipeable ticket cards for the three
/// tiers. Free (espresso) limits some features, Pro (terracotta) is unlocked
/// by referral credits (+300 per friend, permanent), Ultra (black & gold,
/// paid) has no limits. The bottom button follows the visible card.
class PlanScreen extends ConsumerStatefulWidget {
  const PlanScreen({super.key});

  @override
  ConsumerState<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends ConsumerState<PlanScreen> {
  late final PageController _pageCtrl;
  double _page = 0;

  @override
  void initState() {
    super.initState();
    // Open on the card of the plan the user is currently on.
    final initial = switch (ref.read(planProvider).tier) {
      PlanTier.free => 0,
      PlanTier.pro => 1,
      PlanTier.ultra => 2,
    };
    _page = initial.toDouble();
    _pageCtrl = PageController(viewportFraction: 0.86, initialPage: initial)
      ..addListener(() {
        final p = _pageCtrl.page;
        if (p != null && mounted) setState(() => _page = p);
      });
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final plan = ref.watch(planProvider);

    return SubScreenScaffold(
      title: l10n.settingsPlan,
      body: Column(
        children: [
          Expanded(
            // Cap the card height so it reads as a card, not a wall — and
            // centre what's left of the screen around it.
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 560),
                child: PageView(
                  controller: _pageCtrl,
                  children: [
                    _CarouselItem(
                      index: 0,
                      page: _page,
                      child: _PlanCard(
                        tier: PlanTier.free,
                        title: l10n.planFree,
                        active: plan.isFree,
                        numberText: '${Plan.freeScanLimit}',
                        unitText: l10n.planSlipsUnit,
                        details: [
                          l10n.planFreeDetail1,
                          l10n.planFreeDetail2,
                          l10n.planBackfillNote,
                          l10n.planFreeDetail3,
                          l10n.planFreeDetail4,
                        ],
                        missing: [
                          l10n.planFreeDetail5,
                          l10n.planRecurringFeature,
                        ],
                      ),
                    ),
                    _CarouselItem(
                      index: 1,
                      page: _page,
                      child: _PlanCard(
                        tier: PlanTier.pro,
                        title: l10n.planPro,
                        active: plan.isPro,
                        numberText: '+${QuotaPeriod.referralCredit}',
                        unitText: l10n.planCreditsPerFriendUnit,
                        details: [
                          l10n.planUltraDetail1,
                          l10n.planUltraDetail2,
                          l10n.planRecurringFeature,
                          l10n.planFreeDetail5,
                          l10n.planUltraDetail3,
                        ],
                      ),
                    ),
                    _CarouselItem(
                      index: 2,
                      page: _page,
                      child: _PlanCard(
                        tier: PlanTier.ultra,
                        title: l10n.planUltra,
                        active: plan.isUltra,
                        numberText: l10n.planUnlimitedNumber,
                        unitText: l10n.planUltraScanUnlimited,
                        priceLine: l10n.planUltraPriceLine,
                        details: [
                          l10n.planUltraAll,
                          l10n.planUltraScanUnlimited,
                          l10n.planUltraSupport,
                          l10n.planUltraDetail5,
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _PageDots(page: _page, count: 3),
          const SizedBox(height: 4),
        ],
      ),
      footer: _footer(context, l10n, plan),
    );
  }

  /// The pinned bottom action follows the visible card: the Ultra page offers
  /// the paid upgrade (contact the developer — no in-app billing yet); other
  /// pages offer the referral unlock. Already-on-that-tier states show hints.
  Widget _footer(BuildContext context, AppLocalizations l10n, Plan plan) {
    if (plan.isUltra) {
      return Text(
        l10n.planUltraActiveHint,
        textAlign: TextAlign.center,
        style: AppTypography.body(size: 12.5, color: context.palette.ink3),
      );
    }
    if (_page.round() == 2) {
      return PrimaryButton(
        label: l10n.planUltraContactCta,
        onPressed: () => context.push('/settings/help'),
      );
    }
    if (plan.isPro) {
      final credits = ref.watch(membershipProvider).value?.creditBalance ?? 0;
      return Text(
        credits > 0
            ? '${l10n.planCreditsBalance(credits)} — ${l10n.planCreditsFooter}'
            : l10n.planCreditsFooter,
        textAlign: TextAlign.center,
        style: AppTypography.body(size: 12.5, color: context.palette.ink3),
      );
    }
    return PrimaryButton(
      label: l10n.planUnlockCta,
      onPressed: () => context.push('/settings/referral'),
    );
  }
}

/// Scales the off-screen card down slightly so the active card pops — the
/// classic carousel depth cue.
class _CarouselItem extends StatelessWidget {
  const _CarouselItem({
    required this.index,
    required this.page,
    required this.child,
  });

  final int index;
  final double page;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final distance = (page - index).abs().clamp(0.0, 1.0);
    final scale = 1 - 0.06 * distance;
    return Transform.scale(scale: scale, child: child);
  }
}

/// Per-tier card identity: header gradient, accents, and hero-number shading.
class _TierStyle {
  const _TierStyle({
    required this.headerGradient,
    required this.numberGradient,
    required this.accent,
    required this.glow,
    this.icon,
    this.light = false,
  });

  final List<Color> headerGradient;
  final List<Color> numberGradient;

  /// Colour of the small pixel accents in the header.
  final Color accent;

  /// The card's drop-shadow colour.
  final Color glow;

  /// Icon shown before the plan name (Pro/Ultra only).
  final IconData? icon;

  /// Whether the header sits on a LIGHT background (Free) — needs dark ink
  /// and a white/dark-tinted chip instead of the cream-tinted glass that
  /// Pro/Ultra's dark headers use (which would vanish against a light bg).
  final bool light;

  /// Soft blush pink — clearly its own thing next to Pro's saturated
  /// terracotta and Ultra's black-and-gold, while still reading as "part of
  /// the same warm family" via the terracotta-toned hero number.
  static const free = _TierStyle(
    headerGradient: [Color(0xFFFCEEE8), AppColors.terraTint],
    numberGradient: [AppColors.terra, AppColors.terra700],
    accent: AppColors.terra,
    glow: AppColors.terra,
    light: true,
  );

  static const pro = _TierStyle(
    headerGradient: [AppColors.terra, AppColors.terra700],
    numberGradient: [AppColors.reverse, Color(0xFFF3D8A0)],
    accent: AppColors.reverse,
    glow: AppColors.terra,
    icon: AppIcons.sparkles,
  );

  static const ultra = _TierStyle(
    headerGradient: [Color(0xFF211C18), Color(0xFF0E0C0A)],
    numberGradient: [Color(0xFFFFE9B8), Color(0xFFD9A93F)],
    accent: Color(0xFFF3D8A0),
    glow: Color(0xFFD9A93F),
    icon: AppIcons.crown,
  );

  static _TierStyle of(PlanTier tier) => switch (tier) {
        PlanTier.free => free,
        PlanTier.pro => pro,
        PlanTier.ultra => ultra,
      };
}

/// A two-part "membership ticket" card. The TOP half is each tier's identity
/// (espresso / terracotta / black-and-gold); the BOTTOM half (what you get)
/// is styled the SAME on every card, separated by a ticket perforation.
/// [missing] rows render dimmed with an ✗ — what the tier does NOT include.
class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.tier,
    required this.title,
    required this.active,
    required this.numberText,
    required this.unitText,
    required this.details,
    this.missing = const [],
    this.priceLine,
  });

  final PlanTier tier;
  final String title;
  final bool active;
  final String numberText;
  final String unitText;
  final List<String> details;
  final List<String> missing;
  final String? priceLine;

  /// Fixed header height so the ticket notches sit exactly on the seam.
  static const double _topH = 208;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final style = _TierStyle.of(tier);
    final headerInk = style.light ? AppColors.ink : AppColors.reverse;
    final headerInk2 = style.light
        ? context.palette.ink2
        : AppColors.reverse.withValues(alpha: 0.88);
    final isUltra = tier == PlanTier.ultra;
    // On Free's light header, chips/badges need a white/dark-tinted chip
    // instead of the reverse-tinted glass Pro/Ultra use (which would vanish
    // against a light background).
    final chipBg = style.light
        ? context.palette.surface
        : AppColors.reverse.withValues(alpha: 0.14);
    final badgeBg = style.light
        ? context.palette.surface
        : AppColors.reverse.withValues(alpha: 0.22);
    final badgeInk = style.light ? AppColors.terra700 : AppColors.reverse;
    final decorCircle = style.light
        ? AppColors.terra.withValues(alpha: 0.10)
        : AppColors.reverse
            .withValues(alpha: tier == PlanTier.pro ? 0.10 : 0.05);

    return Container(
      margin: const EdgeInsets.fromLTRB(8, 6, 8, 18),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(30),
        // strokeAlignOutside keeps the whole ring against the page's cream
        // background (outside the card's own fill), instead of overlapping
        // the header's own colour — which is how the terra active-ring used
        // to nearly vanish into Pro's terra header (and Free's espresso one).
        border: Border.all(
          color: active ? AppColors.terra : context.palette.line,
          width: active ? 2 : 1,
          strokeAlign: BorderSide.strokeAlignOutside,
        ),
        boxShadow: [
          BoxShadow(
            color: style.glow.withValues(alpha: isUltra ? 0.35 : 0.18),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ---- Top: the tier's own identity ----
              Container(
                height: _topH,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: style.headerGradient,
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      top: -55,
                      right: -45,
                      child: Container(
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(
                          color: decorCircle,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 88,
                      right: 46,
                      child: _Pixel(
                        size: 9,
                        color: style.accent.withValues(alpha: 0.5),
                      ),
                    ),
                    Positioned(
                      top: 112,
                      right: 70,
                      child: _Pixel(
                        size: 6,
                        color: style.accent.withValues(alpha: 0.4),
                      ),
                    ),
                    Positioned(
                      top: 140,
                      right: 36,
                      child: _Pixel(
                        size: 7,
                        color: style.accent.withValues(alpha: 0.3),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: chipBg,
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: BunAvatar(
                                  size: 42,
                                  variant: tier == PlanTier.free
                                      ? BunVariant.normal
                                      : BunVariant.reverse,
                                ),
                              ),
                              const Spacer(),
                              if (active)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 11,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: badgeBg,
                                    borderRadius: BorderRadius.circular(99),
                                  ),
                                  child: Text(
                                    l10n.planCurrentBadge,
                                    style: AppTypography.body(
                                      size: 11.5,
                                      weight: FontWeight.w500,
                                      color: badgeInk,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              if (style.icon != null) ...[
                                Icon(
                                  style.icon,
                                  size: 21,
                                  color: isUltra ? style.accent : headerInk,
                                ),
                                const SizedBox(width: 8),
                              ],
                              Text(
                                title,
                                style: AppTypography.heading(
                                  size: 22,
                                  weight: FontWeight.w600,
                                  color: headerInk,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              ShaderMask(
                                shaderCallback: (r) => LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: style.numberGradient,
                                ).createShader(r),
                                child: Text(
                                  numberText,
                                  style: AppTypography.heading(
                                    size: 46,
                                    weight: FontWeight.w600,
                                    color: Colors.white,
                                    height: 1.0,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 9),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Text(
                                  unitText,
                                  style: AppTypography.body(
                                    size: 14,
                                    color: headerInk2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (priceLine != null) ...[
                            const SizedBox(height: 5),
                            Text(
                              priceLine!,
                              style: AppTypography.heading(
                                size: 13.5,
                                weight: FontWeight.w500,
                                color: style.accent,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // ---- Bottom: what you get — identical styling on every tier --
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.planIncludesLabel,
                        style: AppTypography.heading(
                          size: 13,
                          weight: FontWeight.w500,
                          color: context.palette.ink3,
                        ),
                      ),
                      const SizedBox(height: 12),
                      for (final d in details)
                        _FeatureRow(text: d, included: true),
                      for (final d in missing)
                        _FeatureRow(text: d, included: false),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // ---- Ticket perforation on the seam ----
          Positioned(
            top: _topH - 1,
            left: 26,
            right: 26,
            child: _DashedLine(color: context.palette.line),
          ),
          Positioned(
            top: _topH - 11,
            left: -11,
            child: _Notch(color: context.palette.bg),
          ),
          Positioned(
            top: _topH - 11,
            right: -11,
            child: _Notch(color: context.palette.bg),
          ),
        ],
      ),
    );
  }
}

/// One feature row: a green check for what's included, a dimmed ✗ for what
/// the tier locks.
class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.text, required this.included});
  final String text;
  final bool included;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: included
                  ? context.palette.greenTint
                  : context.palette.surfaceAlt,
              shape: BoxShape.circle,
            ),
            child: Icon(
              included ? AppIcons.check : AppIcons.x,
              size: 13,
              color: included ? context.palette.greenFg : context.palette.ink3,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: AppTypography.body(
                size: 14,
                color: included ? context.palette.ink2 : context.palette.ink3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One of the ticket's side cut-outs: a circle in the screen's background
/// colour, overlapping the card edge so the seam reads as a perforation.
class _Notch extends StatelessWidget {
  const _Notch({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

/// A square "pixel" — the mascot's visual language as a tiny accent.
class _Pixel extends StatelessWidget {
  const _Pixel({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(width: size, height: size, color: color);
  }
}

/// The perforation's dashed line.
class _DashedLine extends StatelessWidget {
  const _DashedLine({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        const dash = 6.0, gap = 5.0;
        final count = (box.maxWidth / (dash + gap)).floor();
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var i = 0; i < count; i++)
              Container(width: dash, height: 1.5, color: color),
          ],
        );
      },
    );
  }
}

/// The carousel's page indicator: an elongated active dot.
class _PageDots extends StatelessWidget {
  const _PageDots({required this.page, required this.count});
  final double page;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++) ...[
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: (page.round() == i) ? 22 : 7,
            height: 7,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: (page.round() == i)
                  ? AppColors.terra
                  : context.palette.toggleOff,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        ],
      ],
    );
  }
}
