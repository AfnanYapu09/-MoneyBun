import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/app_icons.dart';
import '../../../core/widgets/icon_chip.dart';
import '../../../core/widgets/sub_screen_scaffold.dart';
import '../../../l10n/generated/app_localizations.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  // Support contacts.
  static const _lineId = 'afnan9632';
  static const _email = 'afnanyapu09@gmail.com';

  /// Open [uri]; if no app can handle it, copy [copyText] to the clipboard so
  /// the user can still reach us.
  static Future<void> _open(
      BuildContext context, Uri uri, String copyText) async {
    var opened = false;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }
    if (!opened && context.mounted) {
      await Clipboard.setData(ClipboardData(text: copyText));
      if (context.mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.settingsCopied(copyText))),
        );
      }
    }
  }

  static List<(IconData, String, String)> _faqs(AppLocalizations l10n) => [
        (
          AppIcons.scanLine,
          l10n.settingsFaqScanQuestion,
          l10n.settingsFaqScanAnswer,
        ),
        (
          AppIcons.layoutGrid,
          l10n.settingsFaqCategoriesQuestion,
          l10n.settingsFaqCategoriesAnswer,
        ),
        (
          AppIcons.wallet,
          l10n.settingsFaqBudgetQuestion,
          l10n.settingsFaqBudgetAnswer,
        ),
        (
          AppIcons.shieldCheck,
          l10n.settingsFaqSecurityQuestion,
          l10n.settingsFaqSecurityAnswer,
        ),
        (
          AppIcons.refreshCw,
          l10n.settingsFaqSyncQuestion,
          l10n.settingsFaqSyncAnswer,
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final faqs = _faqs(l10n);
    return SubScreenScaffold(
      title: l10n.settingsHelp,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: context.palette.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: context.palette.line),
            ),
            child: Row(
              children: [
                Icon(AppIcons.search, size: 18, color: context.palette.ink3),
                const SizedBox(width: 10),
                Text(l10n.settingsSearchFaq,
                    style: AppTypography.body(
                        size: 14.5, color: context.palette.ink3)),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(l10n.settingsFaqTitle,
              style: AppTypography.heading(size: 14, weight: FontWeight.w500)),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: context.palette.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: context.palette.line),
            ),
            child: Column(
              children: [
                for (var i = 0; i < faqs.length; i++) ...[
                  if (i > 0)
                    const Divider(height: 1, indent: 16, endIndent: 16),
                  _FaqTile(
                    icon: faqs[i].$1,
                    question: faqs[i].$2,
                    answer: faqs[i].$3,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _ContactCard(
                  icon: AppIcons.messageCircle,
                  label: l10n.settingsChatWithUs,
                  sub: 'LINE: $_lineId',
                  background: AppColors.terra,
                  foreground: AppColors.reverse,
                  onTap: () => _open(
                    context,
                    Uri.parse('https://line.me/ti/p/~$_lineId'),
                    'LINE ID: $_lineId',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ContactCard(
                  icon: AppIcons.mail,
                  label: l10n.settingsEmailSupport,
                  sub: _email,
                  background: context.palette.surface,
                  foreground: context.palette.ink,
                  bordered: true,
                  onTap: () => _open(
                    context,
                    Uri(
                      scheme: 'mailto',
                      path: _email,
                      queryParameters: {
                        'subject': l10n.settingsEmailSubject,
                      },
                    ),
                    _email,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  const _FaqTile(
      {required this.icon, required this.question, required this.answer});
  final IconData icon;
  final String question;
  final String answer;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        shape: const Border(),
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        leading: IconChip(icon: icon, size: 34, radius: 11, iconSize: 17),
        title: Text(question, style: AppTypography.body(size: 14.5)),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(answer,
                style: AppTypography.body(
                    size: 13.5, color: context.palette.ink2, height: 1.5)),
          ),
        ],
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
    this.sub,
    this.onTap,
    this.bordered = false,
  });
  final IconData icon;
  final String label;
  final String? sub;
  final VoidCallback? onTap;
  final Color background;
  final Color foreground;
  final bool bordered;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(18),
          border: bordered ? Border.all(color: context.palette.line) : null,
        ),
        child: Column(
          children: [
            Icon(icon, color: foreground, size: 24),
            const SizedBox(height: 8),
            Text(label,
                style: AppTypography.heading(
                    size: 14, weight: FontWeight.w500, color: foreground)),
            if (sub != null) ...[
              const SizedBox(height: 3),
              Text(sub!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body(
                      size: 11.5, color: foreground.withValues(alpha: 0.85))),
            ],
          ],
        ),
      ),
    );
  }
}
