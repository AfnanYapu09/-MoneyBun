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
  final _phone = TextEditingController();
  bool _init = false;

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider).value;
    if (!_init && settings != null) {
      _name.text = settings.displayName;
      _username.text = settings.username;
      _phone.text = settings.phone;
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
                    borderRadius: BorderRadius.circular(30),
                  ),
                  alignment: Alignment.center,
                  child: const BunAvatar(size: 70, variant: BunVariant.reverse),
                ),
                Positioned(
                  right: -4,
                  bottom: -4,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.paper,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.line),
                    ),
                    child: const Icon(AppIcons.camera,
                        size: 16, color: AppColors.terra700),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _Field(label: 'ชื่อที่แสดง', controller: _name),
          const SizedBox(height: 12),
          _Field(label: 'ชื่อผู้ใช้', controller: _username, prefix: '@'),
          const SizedBox(height: 12),
          _Field(
              label: 'อีเมล',
              value: ref.watch(authStateProvider).value?.email ?? '—'),
          const SizedBox(height: 12),
          _Field(
              label: 'เบอร์โทร',
              controller: _phone,
              keyboardType: TextInputType.phone),
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
    await repo.setPhone(_phone.text.trim());
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(const SnackBar(content: Text('บันทึกโปรไฟล์แล้ว')));
    context.pop();
  }
}

/// A design "FieldBox": paper container with a small label and either an
/// editable value (when [controller] is set) or a static read-only [value].
class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    this.controller,
    this.value,
    this.prefix,
    this.keyboardType,
  });
  final String label;
  final TextEditingController? controller;
  final String? value;
  final String? prefix;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: AppTypography.body(size: 12.5, color: AppColors.ink3)),
          const SizedBox(height: 3),
          if (controller != null)
            TextField(
              controller: controller,
              keyboardType: keyboardType,
              style: AppTypography.body(size: 15.5),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                filled: false,
                prefixText: prefix,
                contentPadding: EdgeInsets.zero,
              ),
            )
          else
            Text(value ?? '—', style: AppTypography.body(size: 15.5)),
        ],
      ),
    );
  }
}
