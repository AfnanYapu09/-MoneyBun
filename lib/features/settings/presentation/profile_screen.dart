import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../bootstrap/providers.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/app_icons.dart';
import '../../../core/widgets/profile_avatar.dart';
import '../../../core/widgets/setting_row.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/presentation/auth_errors.dart';

/// ตั้งค่า → โปรไฟล์ของฉัน. A read-first profile: a terracotta banner with the
/// avatar (tap to change the photo), then clean setting rows — tap a row to
/// edit just that field, which saves immediately. No always-on form.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _linking = false;

  @override
  Widget build(BuildContext context) {
    final settings =
        ref.watch(appSettingsProvider).value ?? const AppSettings();
    final email = ref.watch(authStateProvider).value?.email ?? '—';
    final l10n = AppLocalizations.of(context);
    final repo = ref.read(settingsRepositoryProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: Icon(
                    AppIcons.arrowLeft,
                    size: 22,
                    color: context.palette.ink,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  l10n.settingsMyProfile,
                  style: AppTypography.heading(
                    size: 20,
                    weight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _Banner(
              avatarPath: settings.avatarPath,
              name: settings.displayName,
              username: settings.username,
              email: email,
              onPickAvatar: _pickAvatar,
            ),
            const SizedBox(height: 20),
            SettingSectionLabel(l10n.profileInfoSection),
            SettingGroup(
              children: [
                SettingRow(
                  icon: AppIcons.userRound,
                  label: l10n.settingsDisplayName,
                  value: settings.displayName,
                  onTap: () => _editField(
                    title: l10n.settingsDisplayName,
                    initial: settings.displayName,
                    hint: l10n.settingsDisplayNameHint,
                    onSave: (v) =>
                        repo.setDisplayName(v.isEmpty ? 'คุณบัน' : v),
                  ),
                ),
                SettingRow(
                  icon: AppIcons.hash,
                  label: l10n.settingsUsername,
                  value: '@${settings.username}',
                  onTap: () => _editField(
                    title: l10n.settingsUsername,
                    initial: settings.username,
                    prefix: '@',
                    onSave: (v) => repo.setUsername(v.isEmpty ? 'moneybun' : v),
                  ),
                ),
                SettingRow(
                  icon: AppIcons.phone,
                  label: l10n.settingsPhone,
                  value: settings.phone.isEmpty
                      ? l10n.settingsPhoneHint
                      : settings.phone,
                  onTap: () => _editField(
                    title: l10n.settingsPhone,
                    initial: settings.phone,
                    keyboardType: TextInputType.phone,
                    onSave: repo.setPhone,
                  ),
                ),
                SettingRow(
                  icon: AppIcons.mail,
                  label: l10n.settingsEmail,
                  value: email,
                  showChevron: false,
                ),
              ],
            ),
            const SizedBox(height: 18),
            SettingSectionLabel(l10n.profileConnectedSection),
            SettingGroup(
              children: [
                SettingRow(
                  icon: AppIcons.google,
                  label: 'Google',
                  showChevron: false,
                  trailing: _googleLinked
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              AppIcons.check,
                              size: 16,
                              color: context.palette.greenFg,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              l10n.profileGoogleConnected,
                              style: AppTypography.body(
                                size: 13.5,
                                color: context.palette.greenFg,
                              ),
                            ),
                          ],
                        )
                      : SizedBox(
                          height: 34,
                          child: FilledButton(
                            onPressed: _linking ? null : _linkGoogle,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.terra,
                              foregroundColor: AppColors.reverse,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(11),
                              ),
                            ),
                            child: _linking
                                ? const SizedBox(
                                    width: 15,
                                    height: 15,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.reverse,
                                    ),
                                  )
                                : Text(
                                    l10n.profileGoogleConnect,
                                    style: AppTypography.heading(
                                      size: 13,
                                      weight: FontWeight.w500,
                                      color: AppColors.reverse,
                                    ),
                                  ),
                          ),
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  bool get _googleLinked =>
      ref.read(authServiceProvider)?.googleLinked ?? false;

  /// One-field editor: a small dialog with a single text box; saving writes
  /// straight to settings (and syncs), so there is no page-level Save button.
  Future<void> _editField({
    required String title,
    required String initial,
    String? hint,
    String? prefix,
    TextInputType? keyboardType,
    required Future<void> Function(String value) onSave,
  }) async {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController(text: initial);
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: keyboardType,
          decoration: InputDecoration(hintText: hint, prefixText: prefix),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(l10n.save),
          ),
        ],
      ),
    );
    if (value == null) return;
    await onSave(value);
    if (mounted) _snack(l10n.settingsProfileSaved);
  }

  Future<void> _linkGoogle() async {
    final auth = ref.read(authServiceProvider);
    if (auth == null) return;
    setState(() => _linking = true);
    try {
      final linked = await auth.linkWithGoogle();
      if (!mounted) return;
      if (linked) {
        _snack(AppLocalizations.of(context).profileGoogleLinkSuccess);
      }
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      _snack(authErrorMessage(e, l10n, fallback: l10n.authErrGoogleFailed));
    } finally {
      if (mounted) setState(() => _linking = false);
    }
  }

  /// Guards against a second tap opening a second system picker on top of the
  /// first (`PlatformException(already_active)`).
  bool _picking = false;

  /// Pick a photo from the gallery and hand it to the repository, which
  /// stores it locally (uid-named, survives sign-out) and uploads it to the
  /// cloud via the synced `avatarImage` setting (survives reinstall / appears
  /// on other devices).
  Future<void> _pickAvatar() async {
    if (_picking) return;
    _picking = true;
    final l10n = AppLocalizations.of(context);
    // Captured before the awaits: the picker is a separate activity, so the
    // user can easily back out of this screen while it's open — after which
    // ref.read throws and the chosen photo would be lost.
    final repo = ref.read(settingsRepositoryProvider);
    final uid = ref.read(authServiceProvider)?.currentUser?.uid;
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        imageQuality: 85,
      );
      if (picked == null) return;
      await repo.saveAvatarPhoto(uid: uid ?? 'local', sourcePath: picked.path);
      if (mounted) _snack(l10n.profileAvatarUpdated);
    } catch (_) {
      // Picker unavailable / already open / copy failed — tell the user
      // instead of silently doing nothing.
      if (mounted) _snack(l10n.profileAvatarFailed);
    } finally {
      _picking = false;
    }
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(m)));
  }
}

/// Terracotta banner: ringed avatar with a camera badge, the display name,
/// @handle, and the account email in a soft pill.
class _Banner extends StatelessWidget {
  const _Banner({
    required this.avatarPath,
    required this.name,
    required this.username,
    required this.email,
    required this.onPickAvatar,
  });

  final String? avatarPath;
  final String name;
  final String username;
  final String email;
  final VoidCallback onPickAvatar;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.terra, AppColors.terra700],
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: onPickAvatar,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.cream,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: ProfileAvatar(
                    size: 96,
                    radius: 26,
                    avatarPath: avatarPath,
                  ),
                ),
                Positioned(
                  right: -4,
                  bottom: -4,
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppColors.cream,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.terra, width: 2),
                    ),
                    child: const Icon(
                      AppIcons.camera,
                      size: 16,
                      color: AppColors.terra,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            name,
            style: AppTypography.heading(
              size: 20,
              weight: FontWeight.w600,
              color: AppColors.reverse,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '@$username',
            style: AppTypography.body(
              size: 13,
              color: AppColors.reverse.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.reverse.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(AppIcons.mail, size: 14, color: AppColors.reverse),
                const SizedBox(width: 7),
                Text(
                  email,
                  style: AppTypography.body(
                    size: 12.5,
                    color: AppColors.reverse,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
