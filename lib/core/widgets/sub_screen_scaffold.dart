import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/typography.dart';
import 'app_icons.dart';

/// Full-screen sub-page chrome: back arrow + title + optional trailing action,
/// over the cream background. Used by all-transactions, detail, search, budget,
/// comparison, manage screens and settings sub-screens.
class SubScreenScaffold extends StatelessWidget {
  const SubScreenScaffold({
    super.key,
    required this.title,
    required this.body,
    this.action,
    this.onBack,
    this.footer,
  });

  final String title;
  final Widget body;
  final Widget? action;
  final VoidCallback? onBack;

  /// Optional pinned footer (e.g. a save button).
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 12, 6),
              child: Row(
                children: [
                  IconButton(
                    onPressed: onBack ?? () => Navigator.of(context).maybePop(),
                    icon: const Icon(AppIcons.arrowLeft, size: 24),
                    color: AppColors.ink,
                  ),
                  Expanded(
                    child: Text(title,
                        style: AppTypography.heading(
                            size: 18, weight: FontWeight.w600)),
                  ),
                  if (action != null) action!,
                ],
              ),
            ),
            Expanded(child: body),
            if (footer != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: footer!,
              ),
          ],
        ),
      ),
    );
  }
}
