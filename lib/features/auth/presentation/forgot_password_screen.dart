import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../bootstrap/providers.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/app_icons.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/sub_screen_scaffold.dart';
import '../../../l10n/generated/app_localizations.dart';
import 'auth_errors.dart';
import 'widgets/auth_field.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _email = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SubScreenScaffold(
      title: l10n.authForgotPasswordTitle,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(28, 8, 28, 28),
        children: [
          Text(l10n.authForgotPasswordDesc,
              style: AppTypography.body(
                  size: 14.5, color: context.palette.ink2, height: 1.5)),
          const SizedBox(height: 20),
          AuthField(
              icon: AppIcons.mail,
              hint: l10n.authEmail,
              controller: _email,
              keyboardType: TextInputType.emailAddress),
          const SizedBox(height: 24),
          PrimaryButton(
              label: l10n.authSendLink, loading: _busy, onPressed: _send),
        ],
      ),
    );
  }

  Future<void> _send() async {
    final auth = ref.read(authServiceProvider);
    if (auth == null) {
      _snack(AppLocalizations.of(context).authFirebaseNotSet);
      return;
    }
    setState(() => _busy = true);
    try {
      await auth.sendPasswordReset(_email.text);
      _snack(AppLocalizations.of(context).authResetLinkSent);
      if (mounted) context.pop();
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      _snack(authErrorMessage(e, l10n, fallback: l10n.authResetLinkFailed));
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
