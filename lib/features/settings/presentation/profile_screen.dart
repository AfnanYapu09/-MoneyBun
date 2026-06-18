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

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _name = TextEditingController();
  final _username = TextEditingController();
  bool _init = false;

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider).value;
    if (!_init && settings != null) {
      _name.text = settings.displayName;
      _username.text = settings.username;
      _init = true;
    }

    return SubScreenScaffold(
      title: 'โปรไฟล์ของฉัน',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          Center(
            child: Stack(
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: AppColors.terra,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  alignment: Alignment.center,
                  child: const BunAvatar(size: 64, variant: BunVariant.reverse),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: AppColors.paper,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.line),
                    ),
                    child: const Icon(AppIcons.camera,
                        size: 15, color: AppColors.terra700),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _Field(label: 'ชื่อที่แสดง', controller: _name),
          const SizedBox(height: 14),
          _Field(label: 'ชื่อผู้ใช้', controller: _username, prefix: '@'),
          const SizedBox(height: 28),
          PrimaryButton(label: 'บันทึก', onPressed: _save),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final repo = ref.read(settingsRepositoryProvider);
    await repo.setDisplayName(
        _name.text.trim().isEmpty ? 'คุณบัน' : _name.text.trim());
    await repo.setUsername(
        _username.text.trim().isEmpty ? 'moneybun' : _username.text.trim());
    if (mounted) context.pop();
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.controller, this.prefix});
  final String label;
  final TextEditingController controller;
  final String? prefix;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: AppTypography.body(size: 12.5, color: AppColors.ink3)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          decoration: InputDecoration(prefixText: prefix),
        ),
      ],
    );
  }
}
