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
import '../../../data/remote/auth_service.dart';
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
  bool _agree = false;
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
    return SubScreenScaffold(
      title: '',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
        children: [
          const Center(child: BunAvatar(size: 70)),
          const SizedBox(height: 12),
          Center(
            child: Text('สร้างบัญชีใหม่',
                style:
                    AppTypography.heading(size: 25, weight: FontWeight.w600)),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text('เริ่มจดเงินกับน้องบันใน 1 นาที',
                style: AppTypography.body(
                    size: 14.5, color: context.palette.ink2)),
          ),
          const SizedBox(height: 24),
          AuthField(
            icon: AppIcons.userRound,
            hint: 'ชื่อที่แสดง',
            controller: _name,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.name],
            onSubmitted: (_) => FocusScope.of(context).nextFocus(),
          ),
          const SizedBox(height: 12),
          AuthField(
            icon: AppIcons.mail,
            hint: 'อีเมล',
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            onSubmitted: (_) => FocusScope.of(context).nextFocus(),
          ),
          const SizedBox(height: 12),
          AuthField(
            icon: AppIcons.lock,
            hint: 'รหัสผ่าน',
            controller: _password,
            obscure: true,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.newPassword],
            onSubmitted: (_) => _signup(),
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
                      ? const Icon(AppIcons.check,
                          size: 14, color: Colors.white)
                      : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    text: 'ฉันยอมรับ ',
                    style: AppTypography.body(
                        size: 13, color: context.palette.ink2, height: 1.5),
                    children: [
                      TextSpan(
                          text: 'เงื่อนไขการใช้งาน',
                          style: AppTypography.body(
                              size: 13, color: AppColors.terra)),
                      const TextSpan(text: ' และ '),
                      TextSpan(
                          text: 'นโยบายความเป็นส่วนตัว',
                          style: AppTypography.body(
                              size: 13, color: AppColors.terra)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          PrimaryButton(
              label: 'สมัครสมาชิก', loading: _busy, onPressed: _signup),
          const SizedBox(height: 24),
          Center(
            child: GestureDetector(
              onTap: () => context.pop(),
              child: Text.rich(TextSpan(
                text: 'มีบัญชีแล้ว? ',
                style:
                    AppTypography.body(size: 14, color: context.palette.ink2),
                children: [
                  TextSpan(
                    text: 'เข้าสู่ระบบ',
                    style: AppTypography.heading(
                        size: 14,
                        weight: FontWeight.w500,
                        color: AppColors.terra),
                  ),
                ],
              )),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _signup() async {
    if (_busy) return;
    if (!_agree) {
      _snack('กรุณายอมรับเงื่อนไขการใช้งาน');
      return;
    }
    final email = _email.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _snack('กรอกอีเมลให้ถูกต้อง');
      return;
    }
    if (_password.text.length < 6) {
      _snack('รหัสผ่านอย่างน้อย 6 ตัว');
      return;
    }
    final auth = ref.read(authServiceProvider);
    if (auth == null) {
      _snack('ยังไม่ได้ตั้งค่า Firebase — ใช้งานแบบไม่ล็อกอินได้เลย');
      return;
    }
    setState(() => _busy = true);
    try {
      await auth.signUpWithEmail(_name.text, email, _password.text);
      final repo = ref.read(settingsRepositoryProvider);
      await repo.setAuthMode('signedIn');
      if (_name.text.trim().isNotEmpty) {
        await repo.setDisplayName(_name.text.trim());
      }
      if (mounted) context.go('/home');
    } catch (e) {
      _snack(authErrorMessage(e));
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
