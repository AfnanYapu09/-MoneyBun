import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap/providers.dart';
import '../../../core/theme/colors.dart';
import '../../../core/widgets/bun_avatar.dart';
import '../../../core/widgets/pixel_border.dart';
import '../../../l10n/generated/app_localizations.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final firebaseReady = ref.watch(firebaseReadyProvider);
    final user = ref.watch(authStateProvider).value;
    final locale = ref.watch(localeProvider);
    final slipApi = ref.watch(slipApiEnabledProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // ---- Account / sync ----
          PixelBorder(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.cloud_sync, color: AppColors.bunOrange),
                    const SizedBox(width: 8),
                    Text(l10n.syncStatus,
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                  ],
                ),
                const SizedBox(height: 12),
                if (!firebaseReady)
                  const Text(
                    'Firebase ยังไม่ได้ตั้งค่า — แอปทำงานออฟไลน์\n(รัน `flutterfire configure` เพื่อเปิดการซิงค์)',
                    style: TextStyle(color: AppColors.gray500, fontSize: 13),
                  )
                else if (user == null)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.login),
                    title: Text(l10n.signInGoogle),
                    onTap: () => _signIn(context, ref),
                  )
                else
                  Column(
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const CircleAvatar(child: Icon(Icons.person)),
                        title: Text(user.displayName ?? user.email ?? 'User'),
                        subtitle: Text(user.email ?? ''),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () =>
                                  ref.read(syncEngineProvider)?.sync(),
                              icon: const Icon(Icons.sync),
                              label: Text(l10n.syncNow),
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () =>
                                ref.read(authServiceProvider)?.signOut(),
                            child: Text(l10n.signOut),
                          ),
                        ],
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ---- Language ----
          _SectionLabel(l10n.language),
          PixelBorder(
            padding: const EdgeInsets.all(4),
            child: Row(
              children: [
                _LangButton(
                  label: l10n.langThai,
                  selected: locale.languageCode == 'th',
                  onTap: () =>
                      ref.read(localeProvider.notifier).set(const Locale('th')),
                ),
                _LangButton(
                  label: l10n.langEnglish,
                  selected: locale.languageCode == 'en',
                  onTap: () =>
                      ref.read(localeProvider.notifier).set(const Locale('en')),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ---- Slip verify API ----
          PixelBorder(
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeThumbColor: AppColors.bunOrange,
              value: slipApi,
              onChanged: (v) =>
                  ref.read(slipApiEnabledProvider.notifier).set(v),
              title: Text(l10n.slipApiToggle,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(l10n.slipApiDesc,
                  style:
                      const TextStyle(fontSize: 12, color: AppColors.gray500)),
            ),
          ),
          const SizedBox(height: 24),

          // ---- About ----
          Center(
            child: Column(
              children: [
                const BunAvatar(size: 72, mood: BunMood.idle),
                const SizedBox(height: 8),
                const Text('MoneyBun',
                    style:
                        TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                Text(l10n.aboutBun,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: AppColors.gray500, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _signIn(BuildContext context, WidgetRef ref) async {
    final auth = ref.read(authServiceProvider);
    if (auth == null) return;
    try {
      await auth.signInWithGoogle();
      await ref.read(syncEngineProvider)?.sync();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(text,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
      );
}

class _LangButton extends StatelessWidget {
  const _LangButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.bunOrange : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: selected ? AppColors.white : AppColors.gray600,
            ),
          ),
        ),
      ),
    );
  }
}
