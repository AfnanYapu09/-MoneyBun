import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/typography.dart';
import 'app_icons.dart';
import 'bun_avatar.dart';

/// The "น้องบันกำลังอ่านสลิป" block: a bobbing Bun, animated typing dots, and a
/// mini slip with a sweeping scan line. Shown during a slip scan.
class BunScanningBlock extends StatefulWidget {
  const BunScanningBlock({super.key});

  @override
  State<BunScanningBlock> createState() => _BunScanningBlockState();
}

class _BunScanningBlockState extends State<BunScanningBlock>
    with TickerProviderStateMixin {
  late final AnimationController _bob = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat(reverse: true);
  late final AnimationController _scan = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);
  late final AnimationController _dots = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  )..repeat();

  @override
  void dispose() {
    _bob.dispose();
    _scan.dispose();
    _dots.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.palette.line),
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _bob,
            builder: (_, child) => Transform.translate(
              offset: Offset(0, -3 * _bob.value),
              child: child,
            ),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: context.palette.terraWash,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const BunAvatar(size: 30),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Row(
              children: [
                Text('น้องบันกำลังอ่านสลิป',
                    style: AppTypography.heading(
                        size: 14.5, weight: FontWeight.w500)),
                const SizedBox(width: 6),
                _Dots(controller: _dots),
              ],
            ),
          ),
          _MiniSlip(scan: _scan),
        ],
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.controller});
  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return AnimatedBuilder(
          animation: controller,
          builder: (_, __) {
            final phase = (controller.value - i * 0.18) % 1.0;
            final lift = phase < 0.5 ? phase * 2 : (1 - phase) * 2;
            return Padding(
              padding: const EdgeInsets.only(left: 3),
              child: Transform.translate(
                offset: Offset(0, -2 * lift),
                child: Opacity(
                  opacity: 0.25 + 0.75 * lift,
                  child: Container(
                    width: 4,
                    height: 4,
                    decoration: const BoxDecoration(
                      color: AppColors.terra,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }
}

class _MiniSlip extends StatelessWidget {
  const _MiniSlip({required this.scan});
  final AnimationController scan;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 56,
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: context.palette.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SlipLine(widthFactor: 0.70, color: AppColors.terraTint),
              const SizedBox(height: 4),
              _SlipLine(widthFactor: 0.95, color: context.palette.line),
              const SizedBox(height: 4),
              _SlipLine(widthFactor: 0.85, color: context.palette.line),
              const Spacer(),
              const _SlipLine(widthFactor: 0.55, color: AppColors.terraTint),
            ],
          ),
          AnimatedBuilder(
            animation: scan,
            builder: (_, __) => Positioned(
              left: 0,
              right: 0,
              top: 42 * scan.value,
              child: Container(
                height: 3,
                decoration: BoxDecoration(
                  color: AppColors.terra,
                  boxShadow: [
                    BoxShadow(
                        color: AppColors.terra, blurRadius: 8, spreadRadius: 1),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SlipLine extends StatelessWidget {
  const _SlipLine({required this.widthFactor, required this.color});
  final double widthFactor;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: widthFactor,
      child: Container(
        height: 4,
        decoration:
            BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
      ),
    );
  }
}

/// Pull-to-refresh hint shown above the list while pulling.
class PullHint extends StatelessWidget {
  const PullHint({super.key, required this.armed});
  final bool armed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 60,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedRotation(
            turns: armed ? 0.5 : 0,
            duration: const Duration(milliseconds: 200),
            child: const Icon(AppIcons.arrowDown,
                size: 16, color: AppColors.terra),
          ),
          const SizedBox(width: 8),
          Text(
            armed ? 'ปล่อยเพื่อให้น้องบันอ่านสลิป' : 'ดึงลงเพื่ออัปเดตสลิป',
            style: AppTypography.body(size: 13.5, color: context.palette.ink3),
          ),
        ],
      ),
    );
  }
}
