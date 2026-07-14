import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../bootstrap/providers.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/app_icons.dart';
import '../../../core/widgets/bun_avatar.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/wordmark.dart';
import '../../../l10n/generated/app_localizations.dart';
import 'auth_errors.dart';
import 'widgets/auth_field.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Apple Sign-In only works on iOS/macOS; hide the button elsewhere so it
    // isn't offered on Android where it can only fail.
    final appleAvailable = defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
    return Scaffold(
      backgroundColor: context.palette.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(28, 36, 28, 30),
          children: [
            const SizedBox(height: 30),
            // Brand lockup: mascot beside the wordmark, like the logo image.
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                BunAvatar(size: 64),
                SizedBox(width: 14),
                Wordmark(size: 40),
              ],
            ),
            const SizedBox(height: 10),
            Center(
              child: Text(
                l10n.authLoginSubtitle,
                style: AppTypography.body(
                  size: 14,
                  color: context.palette.ink2,
                ),
              ),
            ),
            const SizedBox(height: 30),
            AuthField(
              icon: AppIcons.mail,
              hint: l10n.authEmail,
              controller: _email,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            AuthField(
              icon: AppIcons.lock,
              hint: l10n.authPassword,
              controller: _password,
              obscure: true,
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: InkWell(
                onTap: () => context.push('/forgot-password'),
                child: Text(
                  l10n.authForgotPassword,
                  style: AppTypography.heading(
                    size: 13,
                    weight: FontWeight.w400,
                    color: AppColors.terra,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            PrimaryButton(
              label: l10n.authLogin,
              loading: _busy,
              onPressed: _login,
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(child: Divider(color: context.palette.line)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    l10n.authOr,
                    style: AppTypography.body(
                      size: 13,
                      color: context.palette.ink3,
                    ),
                  ),
                ),
                Expanded(child: Divider(color: context.palette.line)),
              ],
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                SocialButton(
                  icon: AppIcons.google,
                  label: 'Google',
                  onPressed: _busy ? null : _google,
                ),
                if (appleAvailable) ...[
                  const SizedBox(width: 12),
                  SocialButton(
                    icon: AppIcons.apple,
                    label: 'Apple',
                    onPressed: _busy ? null : _apple,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 24),
            Center(
              child: GestureDetector(
                onTap: () => context.push('/signup'),
                child: Text.rich(
                  TextSpan(
                    text: l10n.authNoAccount,
                    style: AppTypography.body(
                      size: 14,
                      color: context.palette.ink2,
                    ),
                    children: [
                      TextSpan(
                        text: l10n.authSignUpNow,
                        style: AppTypography.heading(
                          size: 14,
                          weight: FontWeight.w500,
                          color: AppColors.terra,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _run(Future<void> Function() action) async {
    // Single-flight: the social buttons stay tappable while an email login is
    // in flight (and vice versa) — overlapping GoogleSignIn.authenticate()
    // calls throw on Android and stack error snacks.
    if (_busy) return;
    final auth = ref.read(authServiceProvider);
    if (auth == null) {
      _snack(AppLocalizations.of(context).authFirebaseNotConfigured);
      return;
    }
    // Captured before the await: the auth-state redirect can dispose this
    // screen the moment Firebase emits the signed-in user, after which
    // ref.read throws and the seeding below would be silently skipped.
    final db = ref.read(databaseProvider);
    final settingsRepo = ref.read(settingsRepositoryProvider);
    setState(() => _busy = true);
    try {
      await action();
      // Ensure the starter categories/accounts exist. This is the only entry
      // point for first-time Google/Apple users (they never pass the signup
      // screen, whose seeding otherwise covers this), and the local DB may
      // have been wiped by a previous sign-out. Safe for returning users:
      // seeds carry updatedAt 0, so their real cloud rows win the pull's
      // last-write-wins and overwrite the defaults.
      await db.seedDefaults();
      // Re-attach this account's profile photo (kept on disk across the
      // sign-out wipe; only the pointer was cleared).
      final uid = auth.currentUser?.uid;
      if (uid != null) await settingsRepo.restoreAvatarPath(uid);
      // Enter the app immediately; SyncController kicks off the first sync in
      // the background on the auth-state change, so login no longer blocks on a
      // full push+pull.
      if (mounted) context.go('/home');
    } catch (e) {
      if (!mounted) return;
      // The user closing the Google/Apple account sheet themselves is not a
      // failure — stay silent instead of flashing "เข้าสู่ระบบไม่สำเร็จ".
      if (isAuthCancelled(e)) return;
      final l10n = AppLocalizations.of(context);
      _snack(authErrorMessage(e, l10n, fallback: l10n.authLoginFailed));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _login() {
    // Captured before the sign-in await — the auth redirect can dispose this
    // screen the moment Firebase emits the user, after which ref.read throws
    // (silently swallowed by _run's catch) and the tour flag is never set.
    // Nullable here: _run itself refuses to invoke the action when auth is
    // null (Firebase not configured), so the `!` inside never fires early.
    final auth = ref.read(authServiceProvider);
    final settingsRepo = ref.read(settingsRepositoryProvider);
    return _run(() async {
      await auth!.signInWithEmail(_email.text, _password.text);
      // An email login is by definition a returning user — never replay the
      // first-run walkthrough for them on this device.
      await settingsRepo.setHomeTourSeen(true);
    });
  }

  Future<void> _google() async {
    final auth = ref.read(authServiceProvider);
    if (auth == null) {
      _snack(AppLocalizations.of(context).authFirebaseNotConfigured);
      return;
    }
    // Captured before the await for the same reason as in _run.
    final db = ref.read(databaseProvider);
    final settingsRepo = ref.read(settingsRepositoryProvider);
    setState(() => _busy = true);
    try {
      final result = await auth.signInWithGoogle();
      // null = user dismissed the account chooser; stay on the login screen.
      if (result != null) {
        // Ensure the starter categories/accounts exist — same as _run: a
        // previous sign-out wiped the local DB, and a brand-new Google account
        // has no cloud rows to restore them from. Safe for returning users
        // (seeds carry updatedAt 0 and lose last-write-wins to real rows).
        await db.seedDefaults();
        // Show the walkthrough only when this Google sign-in just created the
        // account; a returning user goes straight in without it.
        await settingsRepo.setHomeTourSeen(!result.isNew);
        // Re-attach this account's profile photo (kept on disk across the
        // sign-out wipe; only the pointer was cleared).
        final uid = auth.currentUser?.uid;
        if (uid != null) await settingsRepo.restoreAvatarPath(uid);
        if (mounted) context.go('/home');
      }
    } catch (e) {
      if (!mounted) return;
      // The user closing the account sheet themselves is not a failure —
      // stay silent, matching _run.
      if (isAuthCancelled(e)) return;
      final l10n = AppLocalizations.of(context);
      _snack(authErrorMessage(e, l10n, fallback: l10n.authLoginFailed));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _apple() => _run(() async {
        await ref.read(authServiceProvider)!.signInWithApple();
      });

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(m)));
  }
}
