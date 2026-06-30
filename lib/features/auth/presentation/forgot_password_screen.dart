import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../bootstrap/providers.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/app_icons.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/sub_screen_scaffold.dart';
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
    return SubScreenScaffold(
      title: 'ลืมรหัสผ่าน',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(28, 8, 28, 28),
        children: [
          Text('กรอกอีเมลของคุณ แล้วเราจะส่งลิงก์ตั้งรหัสผ่านใหม่ให้',
              style: AppTypography.body(
                  size: 14.5, color: context.palette.ink2, height: 1.5)),
          const SizedBox(height: 20),
          AuthField(
              icon: AppIcons.mail,
              hint: 'อีเมล',
              controller: _email,
              keyboardType: TextInputType.emailAddress),
          const SizedBox(height: 24),
          PrimaryButton(label: 'ส่งลิงก์', loading: _busy, onPressed: _send),
        ],
      ),
    );
  }

  Future<void> _send() async {
    final auth = ref.read(authServiceProvider);
    if (auth == null) {
      _snack('ยังไม่ได้ตั้งค่า Firebase');
      return;
    }
    setState(() => _busy = true);
    try {
      await auth.sendPasswordReset(_email.text);
      _snack('ส่งลิงก์ไปที่อีเมลแล้ว');
      if (mounted) context.pop();
    } catch (e) {
      _snack('ส่งไม่สำเร็จ ตรวจสอบอีเมลอีกครั้ง');
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
