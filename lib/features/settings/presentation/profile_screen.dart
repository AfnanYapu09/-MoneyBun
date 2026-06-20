import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../bootstrap/providers.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/app_icons.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/profile_avatar.dart';
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
            child: GestureDetector(
              onTap: _pickAvatar,
              child: Stack(
                children: [
                  ProfileAvatar(size: 96, avatarPath: settings?.avatarPath),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: const BoxDecoration(
                        color: AppColors.terra,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(AppIcons.camera,
                          size: 15, color: AppColors.reverse),
                    ),
                  ),
                ],
              ),
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

  /// Pick a photo from the gallery, copy it into the app's documents dir, and
  /// store its path — so the avatar is actually changed and persists.
  Future<void> _pickAvatar() async {
    final old = ref.read(appSettingsProvider).value?.avatarPath;
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      imageQuality: 85,
    );
    if (picked == null) return;
    final name = 'avatar_${DateTime.now().millisecondsSinceEpoch}'
        '${p.extension(picked.path)}';
    final dir = await getApplicationDocumentsDirectory();
    final dest = p.join(dir.path, name);
    await File(picked.path).copy(dest);
    await ref.read(settingsRepositoryProvider).setAvatarPath(dest);
    // Best-effort cleanup of the previous photo.
    if (old != null && old.isNotEmpty && old != dest) {
      try {
        File(old).deleteSync();
      } catch (_) {}
    }
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
