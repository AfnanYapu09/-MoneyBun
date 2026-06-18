import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../bootstrap/providers.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/bun_avatar.dart';
import '../../../core/widgets/primary_button.dart';

class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  Future<void> _seen(WidgetRef ref) =>
      ref.read(settingsRepositoryProvider).setOnboardingSeen(true);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 16, 28, 30),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () async {
                    await _seen(ref);
                    if (context.mounted) context.go('/home');
                  },
                  child: Text('ข้าม',
                      style:
                          AppTypography.body(size: 14, color: AppColors.ink3)),
                ),
              ),
              const Spacer(),
              Container(
                width: 256,
                height: 230,
                decoration: BoxDecoration(
                  color: AppColors.terraWash,
                  borderRadius: BorderRadius.circular(44),
                ),
                alignment: Alignment.center,
                child: const BunAvatar(size: 150),
              ),
              const SizedBox(height: 24),
              Text('ให้น้องบันช่วยนับเงินให้',
                  textAlign: TextAlign.center,
                  style:
                      AppTypography.heading(size: 25, weight: FontWeight.w600)),
              const SizedBox(height: 10),
              Text(
                'จดทุกบาทที่ใช้ แล้วดูสรุปรายรับรายจ่ายของคุณ\nแบบเข้าใจง่ายในที่เดียว',
                textAlign: TextAlign.center,
                style: AppTypography.body(
                    size: 15, color: AppColors.ink2, height: 1.55),
              ),
              const Spacer(),
              PrimaryButton(
                label: 'เริ่มใช้งาน',
                onPressed: () async {
                  await _seen(ref);
                  await ref
                      .read(settingsRepositoryProvider)
                      .setAuthMode('guest');
                  if (context.mounted) context.go('/home');
                },
              ),
              const SizedBox(height: 12),
              SecondaryButton(
                label: 'ฉันมีบัญชีอยู่แล้ว',
                onPressed: () async {
                  await _seen(ref);
                  if (context.mounted) context.go('/login');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
