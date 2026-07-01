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
import 'auth_errors.dart';
import 'widgets/auth_field.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _agree = true;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SubScreenScaffold(
      title: '',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
        children: [
          const Center(child: BunAvatar(size: 70)),
          const SizedBox(height: 12),
          Center(
            child: Text(
              l10n.authCreateAccount,
              style: AppTypography.heading(size: 25, weight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              l10n.authSignUpSubtitle,
              style: AppTypography.body(
                size: 14.5,
                color: context.palette.ink2,
              ),
            ),
          ),
          const SizedBox(height: 24),
          AuthField(
            icon: AppIcons.userRound,
            hint: l10n.authDisplayName,
            controller: _name,
          ),
          const SizedBox(height: 12),
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
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: () => setState(() => _agree = !_agree),
                child: Container(
                  width: 20,
                  height: 20,
                  margin: const EdgeInsets.only(top: 1),
                  decoration: BoxDecoration(
                    color: _agree ? AppColors.terra : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: _agree
                        ? null
                        : Border.all(color: context.palette.line, width: 1.5),
                  ),
                  child: _agree
                      ? const Icon(
                          AppIcons.check,
                          size: 14,
                          color: Colors.white,
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    text: l10n.authAgreePrefix,
                    style: AppTypography.body(
                      size: 13,
                      color: context.palette.ink2,
                      height: 1.5,
                    ),
                    children: [
                      // Emphasised (not link-styled) — the app ships no separate
                      // Terms/Privacy pages, so these name the documents without
                      // pretending to be tappable links that go nowhere.
                      TextSpan(
                        text: l10n.authTermsOfService,
                        style: TextStyle(
                          color: context.palette.ink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      TextSpan(text: l10n.authAnd),
                      TextSpan(
                        text: l10n.authPrivacyPolicy,
                        style: TextStyle(
                          color: context.palette.ink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          PrimaryButton(
            label: l10n.authSignUp,
            loading: _busy,
            onPressed: _signup,
          ),
          const SizedBox(height: 24),
          Center(
            child: GestureDetector(
              onTap: () => context.pop(),
              child: Text.rich(
                TextSpan(
                  text: l10n.authHaveAccount,
                  style: AppTypography.body(
                    size: 14,
                    color: context.palette.ink2,
                  ),
                  children: [
                    TextSpan(
                      text: l10n.authLogin,
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
    );
  }

  Future<void> _signup() async {
    if (!_agree) {
      _snack(AppLocalizations.of(context).authMustAcceptTerms);
      return;
    }
    final auth = ref.read(authServiceProvider);
    if (auth == null) {
      _snack(AppLocalizations.of(context).authFirebaseNotConfigured);
      return;
    }
    setState(() => _busy = true);
    try {
      await auth.signUpWithEmail(_name.text, _email.text, _password.text);
      final repo = ref.read(settingsRepositoryProvider);
      // Ensure the starter categories/accounts exist — the local DB may have
      // been wiped on a previous sign-out (idempotent on a fresh install).
      await ref.read(databaseProvider).seedDefaults();
      // A brand-new account has no cloud data to pull, so the first sync is
      // already "done" — this keeps the Home first-load skeleton from flashing
      // for a user who has nothing to wait for.
      await repo.setFirstSyncDone(true);
      if (_name.text.trim().isNotEmpty) {
        await repo.setDisplayName(_name.text.trim());
      }
      if (mounted) context.go('/home');
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      _snack(authErrorMessage(e, l10n, fallback: l10n.authSignUpFailed));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(m)));
  }
}
