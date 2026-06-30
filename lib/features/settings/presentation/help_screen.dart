import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/app_icons.dart';
import '../../../core/widgets/icon_chip.dart';
import '../../../core/widgets/sub_screen_scaffold.dart';
import '../../../l10n/generated/app_localizations.dart';

/// A single FAQ entry: an icon plus a question/answer pair.
class _Faq {
  const _Faq(this.icon, this.question, this.answer, {this.primary = false});
  final IconData icon;
  final String question;
  final String answer;

  /// Shown on the help screen by default (the main questions). Non-primary
  /// entries only appear once the user searches.
  final bool primary;

  /// True when [query] (already lower-cased) appears in the question or answer.
  bool matches(String query) =>
      question.toLowerCase().contains(query) ||
      answer.toLowerCase().contains(query);
}

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  // Support contacts.
  static const _lineId = 'afnan9632';
  static const _email = 'afnanyapu09@gmail.com';

  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// The full FAQ list, in a logical order (getting started → entries →
  /// organising → settings → privacy → troubleshooting). All copy is localised.
  static List<_Faq> _faqs(AppLocalizations l10n) => [
        _Faq(AppIcons.scanLine, l10n.settingsFaqScanQuestion,
            l10n.settingsFaqScanAnswer, primary: true),
        _Faq(AppIcons.circleHelp, l10n.settingsFaqSlipFailedQuestion,
            l10n.settingsFaqSlipFailedAnswer, primary: true),
        _Faq(AppIcons.plus, l10n.settingsFaqAddManualQuestion,
            l10n.settingsFaqAddManualAnswer, primary: true),
        _Faq(AppIcons.arrowLeftRight, l10n.settingsFaqTransferQuestion,
            l10n.settingsFaqTransferAnswer),
        _Faq(AppIcons.pencil, l10n.settingsFaqEditDeleteQuestion,
            l10n.settingsFaqEditDeleteAnswer),
        _Faq(AppIcons.layoutGrid, l10n.settingsFaqCategoriesQuestion,
            l10n.settingsFaqCategoriesAnswer, primary: true),
        _Faq(AppIcons.hash, l10n.settingsFaqTagsQuestion,
            l10n.settingsFaqTagsAnswer),
        _Faq(AppIcons.wallet, l10n.settingsFaqBudgetQuestion,
            l10n.settingsFaqBudgetAnswer, primary: true),
        _Faq(AppIcons.target, l10n.settingsFaqSavingsQuestion,
            l10n.settingsFaqSavingsAnswer),
        _Faq(AppIcons.banknote, l10n.settingsFaqAccountsQuestion,
            l10n.settingsFaqAccountsAnswer),
        _Faq(AppIcons.banknote, l10n.settingsFaqCurrencyQuestion,
            l10n.settingsFaqCurrencyAnswer),
        _Faq(AppIcons.globe, l10n.settingsFaqLanguageQuestion,
            l10n.settingsFaqLanguageAnswer),
        _Faq(AppIcons.palette, l10n.settingsFaqThemeQuestion,
            l10n.settingsFaqThemeAnswer),
        _Faq(AppIcons.download, l10n.settingsFaqExportQuestion,
            l10n.settingsFaqExportAnswer),
        _Faq(AppIcons.shieldCheck, l10n.settingsFaqSecurityQuestion,
            l10n.settingsFaqSecurityAnswer),
        _Faq(AppIcons.refreshCw, l10n.settingsFaqSyncQuestion,
            l10n.settingsFaqSyncAnswer, primary: true),
      ];

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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final query = _query.trim().toLowerCase();
    final searching = query.isNotEmpty;
    final faqs = _faqs(l10n);
    // Default to the main questions; searching reveals the full set.
    final results = searching
        ? faqs.where((f) => f.matches(query)).toList()
        : faqs.where((f) => f.primary).toList();

    return SubScreenScaffold(
      title: l10n.settingsHelp,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          // Real, working FAQ search box.
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
                Expanded(
                  child: TextField(
                    controller: _controller,
                    onChanged: (v) => setState(() => _query = v),
                    textInputAction: TextInputAction.search,
                    style: AppTypography.body(size: 14.5),
                    decoration: InputDecoration(
                      isCollapsed: true,
                      border: InputBorder.none,
                      hintText: l10n.settingsSearchFaq,
                      hintStyle: AppTypography.body(
                          size: 14.5, color: context.palette.ink3),
                    ),
                  ),
                ),
                if (searching)
                  GestureDetector(
                    onTap: () {
                      _controller.clear();
                      setState(() => _query = '');
                      FocusScope.of(context).unfocus();
                    },
                    child: Icon(AppIcons.x,
                        size: 18, color: context.palette.ink3),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (results.isEmpty)
            _NoResults(query: _query.trim())
          else ...[
            Text(l10n.settingsFaqTitle,
                style:
                    AppTypography.heading(size: 14, weight: FontWeight.w500)),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: context.palette.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: context.palette.line),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < results.length; i++) ...[
                    if (i > 0)
                      const Divider(height: 1, indent: 16, endIndent: 16),
                    _FaqTile(
                      // Re-key on the search state so a match opens its answer
                      // straight away while searching.
                      key: ValueKey('${results[i].question}|$searching'),
                      icon: results[i].icon,
                      question: results[i].question,
                      answer: results[i].answer,
                      initiallyExpanded: searching,
                    ),
                  ],
                ],
              ),
            ),
            if (!searching) ...[
              const SizedBox(height: 12),
              Center(
                child: Text(l10n.settingsFaqSearchMoreHint,
                    style: AppTypography.body(
                        size: 12.5, color: context.palette.ink3)),
              ),
            ],
          ],
          const SizedBox(height: 22),
          Text(l10n.settingsHelpContactPrompt,
              style: AppTypography.heading(size: 14, weight: FontWeight.w500)),
          const SizedBox(height: 10),
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

/// Shown when a search matches no FAQ.
class _NoResults extends StatelessWidget {
  const _NoResults({required this.query});
  final String query;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 18),
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.palette.line),
      ),
      child: Column(
        children: [
          Icon(AppIcons.search, size: 26, color: context.palette.ink3),
          const SizedBox(height: 10),
          Text(
            l10n.settingsFaqNoResults(query),
            textAlign: TextAlign.center,
            style: AppTypography.body(size: 14, color: context.palette.ink2),
          ),
        ],
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  const _FaqTile({
    super.key,
    required this.icon,
    required this.question,
    required this.answer,
    this.initiallyExpanded = false,
  });
  final IconData icon;
  final String question;
  final String answer;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
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
