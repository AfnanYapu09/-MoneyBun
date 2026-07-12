import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../bootstrap/providers.dart';

/// moneyBun splash — ported from the owner's reference design:
/// a plain cream stage, the pixel Bun jumps up out of the empty ground,
/// lands with a squash + tiny rebound (then breathes and blinks), and the
/// "moneyBun" wordmark reveals left-to-right beside it. Routing happens once
/// BOTH the animation has played and the restored auth state is known.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  // ---- palette (from the reference) ----
  static const cream = Color(0xFFF1EEE4);
  static const ink = Color(0xFF1A1714);
  static const money = Color(0xFF4A443C);

  // ---- geometry ----
  static const double cell = 12; // pixel size
  static const int cols = 14, rows = 16;
  double get bunW => cols * cell; // 168
  double get bunH => rows * cell; // 192
  static const double gap = 26; // space between bun and wordmark
  static const double apex = 150; // jump height above the resting spot
  static const double wordSize = 96;

  // ---- timeline (ms inside the controller) ----
  static const int total = 2800;
  static const int riseMs = 400; // ground -> apex
  static const int fallMs = 300; // apex -> land
  static const int enterEnd = riseMs + fallMs; // 700
  static const int revealStart = enterEnd + 170; // 870
  static const int revealMs = 620;

  late final AnimationController _c;
  double _cachedWordWidth = 0;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: total),
    )..forward();
    _boot();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _boot() async {
    try {
      final settings = await ref.read(settingsRepositoryProvider).read();
      final auth = ref.read(authServiceProvider);
      // Resolve the restored auth state concurrently with the animation.
      // currentUser can still be null right after launch until Firebase
      // finishes reading its persisted session, so fall back to the first
      // authStateChanges emission (bounded) — otherwise a returning user
      // would flash the login screen before the router redirect bounces them
      // back to Home.
      final Future<bool> signedInFuture = auth == null
          ? Future.value(false)
          : auth.currentUser != null
              ? Future.value(true)
              : auth
                  .authStateChanges()
                  .first
                  .timeout(const Duration(seconds: 2), onTimeout: () => null)
                  .then((u) => u != null);
      // Leave right after the wordmark has fully revealed (the jump + reveal
      // finish by ~1.5s) — the breathing/blink keeps playing under the page
      // fade, so the exit feels alive without padding the wait.
      await Future.delayed(const Duration(milliseconds: 2000));
      final signedIn = await signedInFuture;
      if (!mounted) return;
      if (!settings.onboardingSeen) {
        context.go('/onboarding');
        return;
      }
      // Cloud-only: the app requires a signed-in account. The router's
      // redirect enforces this for every route as a safety net.
      context.go(signedIn ? '/home' : '/login');
    } catch (_) {
      // Whatever failed (settings read, auth state), never strand the user on
      // the splash forever — the router redirect sends a signed-in user home.
      if (mounted) context.go('/login');
    }
  }

  double _easeOut(double t) => 1 - (1 - t) * (1 - t) * (1 - t);
  double _easeIn(double t) => t * t * t;

  double _wordWidth() {
    if (_cachedWordWidth > 0) return _cachedWordWidth;
    final tp = TextPainter(
      text: _wordSpan(),
      textDirection: TextDirection.ltr,
    )..layout();
    return _cachedWordWidth = tp.width;
  }

  @override
  Widget build(BuildContext context) {
    final below = bunH + 70.0; // start point, fully under the ground line

    return Scaffold(
      backgroundColor: cream,
      body: Center(
        // The lockup is wider than a phone screen at design size — scale it
        // down to fit with comfortable side padding.
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, _) {
                final t = _c.value * total;

                double y = 0, sx = 1, sy = 1;
                _Pose pose = _Pose.ground;

                if (t < enterEnd) {
                  pose = _Pose.air;
                  if (t < riseMs) {
                    final p = _easeOut(t / riseMs);
                    y = below + (-apex - below) * p;
                    sy = 1 + 0.12 * (t / riseMs);
                    sx = 1 - 0.09 * (t / riseMs);
                  } else {
                    final p = _easeIn((t - riseMs) / fallMs);
                    y = -apex * (1 - p);
                    sy = 1 + 0.12 * (1 - p);
                    sx = 1 - 0.09 * (1 - p);
                  }
                  if (t > enterEnd - 50) pose = _Pose.ground;
                } else {
                  final tb = t - enterEnd;
                  if (tb < 130) {
                    final k = tb / 130;
                    sy = 0.8 + 0.2 * k;
                    sx = 1.18 - 0.18 * k;
                  } else {
                    final settle = (1 - tb / 300).clamp(0.0, 1.0);
                    y = -20 * math.sin((tb / 300) * math.pi) * settle;
                    final bt = tb / 1000;
                    sy = 1 + math.sin(bt * 2.1) * 0.012; // breathing
                    sx = 1 - math.sin(bt * 2.1) * 0.012;
                  }
                  if ((tb > 820 && tb < 940) || (tb > 2100 && tb < 2220)) {
                    pose = _Pose.blink;
                  }
                }

                final hf =
                    1 - (y.abs().clamp(0, apex) / apex); // shadow strength

                double reveal = 0;
                if (t >= revealStart) {
                  reveal = _easeOut(
                    ((t - revealStart) / revealMs).clamp(0.0, 1.0),
                  );
                }

                final lockupW = bunW + gap + _wordWidth();

                return SizedBox(
                  width: lockupW,
                  height: bunH,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // ground shadow
                      Positioned(
                        left: bunW * 0.09,
                        bottom: -12,
                        child: Opacity(
                          opacity: 0.05 + 0.19 * hf,
                          child: Container(
                            width: bunW * 0.82 * (0.45 + 0.55 * hf),
                            height: 16,
                            decoration: BoxDecoration(
                              color: ink.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                      ),

                      // bun — clipped at the ground line so it emerges from
                      // the empty floor
                      Positioned(
                        left: 0,
                        bottom: 0,
                        width: bunW,
                        child: ClipRect(
                          child: SizedBox(
                            height: bunH + apex + 80,
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: Transform.translate(
                                offset: Offset(0, y),
                                child: Transform(
                                  alignment: Alignment.bottomCenter,
                                  transform: Matrix4.diagonal3Values(sx, sy, 1),
                                  child: CustomPaint(
                                    size: Size(bunW, bunH),
                                    painter: _BunPainter(pose, cell),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // wordmark, revealed left -> right
                      Positioned(
                        left: bunW + gap,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: ClipRect(
                            clipper: _RevealClipper(reveal),
                            child: Text.rich(_wordSpan()),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  static const List<FontVariation> _axes = [
    FontVariation('opsz', 144),
    FontVariation('SOFT', 0),
    FontVariation('WONK', 1), // <- the curly y tail
  ];

  TextSpan _wordSpan() {
    const base = TextStyle(
      fontFamily: 'FrauncesVar',
      fontSize: wordSize,
      height: 0.9,
      letterSpacing: -wordSize * 0.01,
    );
    return TextSpan(
      children: [
        TextSpan(
          text: 'money',
          style: base.copyWith(
            color: money,
            fontVariations: const [FontVariation('wght', 500), ..._axes],
          ),
        ),
        TextSpan(
          text: 'Bun',
          style: base.copyWith(
            color: ink,
            fontVariations: const [FontVariation('wght', 600), ..._axes],
          ),
        ),
      ],
    );
  }
}

enum _Pose { ground, air, blink }

/// left -> right wipe used to reveal the wordmark. Clips ONLY horizontally —
/// the rect extends far above and below the text box so the y's descender
/// (which overflows the tight 0.9 line height) isn't chopped into a "v".
class _RevealClipper extends CustomClipper<Rect> {
  _RevealClipper(this.t);
  final double t; // 0..1

  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(0, -size.height, size.width * t, size.height * 3);

  @override
  bool shouldReclip(_RevealClipper old) => old.t != t;
}

/// Draws the Bun mascot pixel-by-pixel from a 14x16 character grid.
///   X = body   D = nose/shadow   K = eye   . = empty
class _BunPainter extends CustomPainter {
  _BunPainter(this.pose, this.cell);
  final _Pose pose;
  final double cell;

  static const List<String> ground = [
    "...XX....XX...",
    "...XX....XX...",
    "...XX....XX...",
    "...XX....XX...",
    "..XXXX..XXXX..",
    "..XXXXXXXXXX..",
    ".XXXXXXXXXXXX.",
    "XXXKKXXXXKKXXX",
    "XXXKKXXXXKKXXX",
    "XXXXXXXXXXXXXX",
    "XXXXXXDDXXXXXX",
    "XXXXXXXXXXXXXX",
    ".XXXXXXXXXXXX.",
    ".XXXXXXXXXXXX.",
    ".XX.XX..XX.XX.",
    ".XX.XX..XX.XX.",
  ];

  List<String> get _map {
    switch (pose) {
      case _Pose.air: // feet tucked up (single leg row)
        return [...ground.sublist(0, 14), ".XX.XX..XX.XX.", ".............."];
      case _Pose.blink: // eyes closed
        return [
          for (int i = 0; i < ground.length; i++)
            (i == 7 || i == 8) ? "XXXXXXXXXXXXXX" : ground[i],
        ];
      case _Pose.ground:
        return ground;
    }
  }

  static const _orange = Color(0xFFC4694A);
  static const _deep = Color(0xFFA9543A);
  static const _eye = Color(0xFF1A1714);

  @override
  void paint(Canvas canvas, Size size) {
    final m = _map;
    final paint = Paint()..style = PaintingStyle.fill;
    for (int r = 0; r < m.length; r++) {
      for (int c = 0; c < m[r].length; c++) {
        final ch = m[r][c];
        if (ch == '.') continue;
        paint.color = ch == 'K' ? _eye : (ch == 'D' ? _deep : _orange);
        // 0.5px overlap removes hairline seams between cells
        canvas.drawRect(
          Rect.fromLTWH(c * cell - 0.5, r * cell - 0.5, cell + 1, cell + 1),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_BunPainter old) => old.pose != pose;
}
