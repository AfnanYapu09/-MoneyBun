import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../bootstrap/providers.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../data/remote/auth_service.dart';
import '../../../core/widgets/app_icons.dart';
import '../../../core/widgets/bun_avatar.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/wordmark.dart';
import 'widgets/auth_field.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _passwordFocus = FocusNode();
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authServiceProvider);
    return Scaffold(
      backgroundColor: context.palette.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(28, 36, 28, 30),
          children: [
            const SizedBox(height: 14),
            const Center(child: BunAvatar(size: 84)),
            const SizedBox(height: 14),
            const Center(child: Wordmark(size: 30)),
            const SizedBox(height: 8),
            Center(
              child: Text('เข้าสู่ระบบเพื่อจดเงินต่อ',
                  style: AppTypography.body(
                      size: 14, color: context.palette.ink2)),
            ),
            const SizedBox(height: 30),
            AuthField(
              icon: AppIcons.mail,
              hint: 'อีเมล',
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              onSubmitted: (_) => _passwordFocus.requestFocus(),
            ),
            const SizedBox(height: 12),
            AuthField(
              icon: AppIcons.lock,
              hint: 'รหัสผ่าน',
              controller: _password,
              obscure: true,
              focusNode: _passwordFocus,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              onSubmitted: (_) => _login(),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: InkWell(
                onTap: () => context.push('/forgot-password'),
                child: Text('ลืมรหัสผ่าน?',
                    style: AppTypography.heading(
                        size: 13,
                        weight: FontWeight.w400,
                        color: AppColors.terra)),
              ),
            ),
            const SizedBox(height: 14),
            PrimaryButton(
                label: 'เข้าสู่ระบบ', loading: _busy, onPressed: _login),
            const SizedBox(height: 22),
            Row(children: [
              Expanded(child: Divider(color: context.palette.line)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('หรือ',
                    style: AppTypography.body(
                        size: 13, color: context.palette.ink3)),
              ),
              Expanded(child: Divider(color: context.palette.line)),
            ]),
            const SizedBox(height: 22),
            Row(children: [
              SocialButton(
                  icon: AppIcons.google,
                  label: 'Google',
                  onPressed: _busy ? null : _google),
              // Apple Sign-In only works on iOS/macOS — hide it elsewhere so it
              // isn't a guaranteed-to-fail button.
              if (auth?.supportsApple ?? false) ...[
                const SizedBox(width: 12),
                SocialButton(
                    icon: AppIcons.apple,
                    label: 'Apple',
                    onPressed: _busy ? null : _apple),
              ],
            ]),
            const SizedBox(height: 24),
            Center(
              child: GestureDetector(
                onTap: () => context.push('/signup'),
                child: Text.rich(TextSpan(
                  text: 'ยังไม่มีบัญชี? ',
                  style:
                      AppTypography.body(size: 14, color: context.palette.ink2),
                  children: [
                    TextSpan(
                      text: 'สมัครเลย',
                      style: AppTypography.heading(
                          size: 14,
                          weight: FontWeight.w500,
                          color: AppColors.terra),
                    ),
                  ],
                )),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: _continueAsGuest,
                child: Text('ใช้งานต่อแบบไม่ล็อกอิน',
                    style: AppTypography.body(
                        size: 13, color: context.palette.ink3)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _run(Future<void> Function() action) async {
    final auth = ref.read(authServiceProvider);
    if (auth == null) {
      _snack('ยังไม่ได้ตั้งค่า Firebase — ใช้งานแบบไม่ล็อกอินได้เลย');
      return;
    }
    setState(() => _busy = true);
    try {
      await action();
      await ref.read(settingsRepositoryProvider).setAuthMode('signedIn');
      await ref.read(syncEngineProvider)?.sync();
      if (mounted) context.go('/home');
    } catch (e) {
      _snack(authErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _continueAsGuest() async {
    await ref.read(settingsRepositoryProvider).setAuthMode('guest');
    if (mounted) context.go('/home');
  }

  Future<void> _login() async {
    final email = _email.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _snack('กรอกอีเมลให้ถูกต้อง');
      return;
    }
    if (_password.text.isEmpty) {
      _snack('กรอกรหัสผ่าน');
      return;
    }
    await _run(() async {
      await ref
          .read(authServiceProvider)!
          .signInWithEmail(email, _password.text);
    });
  }

  Future<void> _google() => _run(() async {
        await ref.read(authServiceProvider)!.signInWithGoogle();
      });

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
