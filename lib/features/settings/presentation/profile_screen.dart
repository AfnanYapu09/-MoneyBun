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
import '../../../l10n/generated/app_localizations.dart';

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
    final email = ref.watch(authStateProvider).value?.email ?? '—';
    final l10n = AppLocalizations.of(context);

    return SubScreenScaffold(
      title: l10n.settingsMyProfile,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          _Header(
            avatarPath: settings?.avatarPath,
            name: _name,
            username: _username,
            onPickAvatar: _pickAvatar,
          ),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              color: context.palette.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: context.palette.line),
            ),
            child: Column(
              children: [
                _ProfileRow(
                  icon: AppIcons.userRound,
                  label: l10n.settingsDisplayName,
                  controller: _name,
                  hint: l10n.settingsDisplayNameHint,
                ),
                const _RowDivider(),
                _ProfileRow(
                  icon: AppIcons.hash,
                  label: l10n.settingsUsername,
                  controller: _username,
                  prefix: '@',
                  hint: 'moneybun',
                ),
                const _RowDivider(),
                _ProfileRow(
                  icon: AppIcons.mail,
                  label: l10n.settingsEmail,
                  value: email,
                ),
                const _RowDivider(),
                _ProfileRow(
                  icon: AppIcons.phone,
                  label: l10n.settingsPhone,
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  hint: l10n.settingsPhoneHint,
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          PrimaryButton(label: l10n.save, onPressed: _save),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final repo = ref.read(settingsRepositoryProvider);
    await repo.setDisplayName(
      _name.text.trim().isEmpty ? 'คุณบัน' : _name.text.trim(),
    );
    await repo.setUsername(
      _username.text.trim().isEmpty ? 'moneybun' : _username.text.trim(),
    );
    await repo.setPhone(_phone.text.trim());
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(l10n.settingsProfileSaved)));
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

/// Centered avatar (tap to change the photo) with the live display name and
/// @username shown beneath it — they update as the fields below are edited.
class _Header extends StatelessWidget {
  const _Header({
    required this.avatarPath,
    required this.name,
    required this.username,
    required this.onPickAvatar,
  });

  final String? avatarPath;
  final TextEditingController name;
  final TextEditingController username;
  final VoidCallback onPickAvatar;

  @override
  Widget build(BuildContext context) {
    final nameStyle = AppTypography.heading(size: 20, weight: FontWeight.w600);
    final handleStyle = AppTypography.body(
      size: 13,
      color: context.palette.ink3,
    );

    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: onPickAvatar,
            child: Stack(
              children: [
                ProfileAvatar(size: 100, avatarPath: avatarPath),
                Positioned(
                  right: 2,
                  bottom: 2,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.terra,
                      shape: BoxShape.circle,
                      border: Border.all(color: context.palette.bg, width: 2),
                    ),
                    child: const Icon(
                      AppIcons.camera,
                      size: 15,
                      color: AppColors.reverse,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          AnimatedBuilder(
            animation: Listenable.merge([name, username]),
            builder: (context, _) {
              final n = name.text.trim();
              final u = username.text.trim();
              final shownName = n.isEmpty ? 'คุณบัน' : n;
              final handle = u.isEmpty ? 'moneybun' : u;
              return Column(
                children: [
                  Text(shownName, style: nameStyle),
                  const SizedBox(height: 2),
                  Text('@$handle', style: handleStyle),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// One profile row: a tinted icon, a small label, and either an editable value
/// ([controller]) or a static read-only [value] (e.g. the account email).
class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.icon,
    required this.label,
    this.controller,
    this.value,
    this.prefix,
    this.hint,
    this.keyboardType,
  });

  final IconData icon;
  final String label;
  final TextEditingController? controller;
  final String? value;
  final String? prefix;
  final String? hint;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    final labelStyle = AppTypography.body(
      size: 12,
      color: context.palette.ink3,
    );
    final valueStyle = AppTypography.body(size: 15.5);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Icon(icon, size: 22, color: context.palette.terraFg),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: labelStyle),
                const SizedBox(height: 1),
                if (controller != null)
                  TextField(
                    controller: controller,
                    keyboardType: keyboardType,
                    style: valueStyle,
                    decoration: InputDecoration(
                      isCollapsed: true,
                      border: InputBorder.none,
                      filled: false,
                      prefixText: prefix,
                      hintText: hint,
                      contentPadding: EdgeInsets.zero,
                    ),
                  )
                else
                  Text(value ?? '—', style: valueStyle),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Hairline divider between rows, inset so it lines up under the label text.
class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 52),
      child: Divider(height: 1, thickness: 1, color: context.palette.line),
    );
  }
}
