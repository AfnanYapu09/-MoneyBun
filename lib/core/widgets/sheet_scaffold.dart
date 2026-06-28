import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import 'app_icons.dart';

/// Standard bottom-sheet content: drag handle, title + close, scrollable body,
/// optional pinned footer. Wrap in `showModalBottomSheet`.
class SheetScaffold extends StatelessWidget {
  const SheetScaffold({
    super.key,
    required this.title,
    required this.child,
    this.footer,
    this.action,
    this.maxHeightFactor = 0.6,
  });

  final String title;
  final Widget child;
  final Widget? footer;

  /// Optional trailing action shown before the close (X) button.
  final Widget? action;
  final double maxHeightFactor;

  @override
  Widget build(BuildContext context) {
    // Fixed height so every popup sheet is the same size (not just capped).
    final height = MediaQuery.of(context).size.height * maxHeightFactor;
    return Container(
      height: height,
      decoration: const BoxDecoration(
        color: AppColors.cream,
        borderRadius: Tokens.sheetTop,
      ),
      child: Column(
        children: [
          const _DragHandle(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(title,
                      style: AppTypography.heading(
                          size: 17, weight: FontWeight.w600)),
                ),
                if (action != null) action!,
                IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(AppIcons.x, size: 22),
                  color: AppColors.ink3,
                ),
              ],
            ),
          ),
          Expanded(child: child),
          if (footer != null)
            Padding(
              padding: EdgeInsets.fromLTRB(
                  20, 4, 20, 16 + MediaQuery.of(context).padding.bottom),
              child: footer!,
            ),
        ],
      ),
    );
  }
}

/// Full-height sheet chrome (e.g. the Add transaction sheet): X close in the
/// header (with optional header widget such as a segmented control), scroll
/// body, pinned footer separated by a top border.
class FullSheetScaffold extends StatelessWidget {
  const FullSheetScaffold({
    super.key,
    required this.header,
    required this.child,
    this.footer,
  });

  /// Built next to the close (X) button — e.g. a segmented control.
  final Widget header;
  final Widget child;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(AppIcons.x, size: 26),
                  color: AppColors.ink,
                ),
                Expanded(child: header),
              ],
            ),
          ),
          Expanded(child: child),
          if (footer != null)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.line)),
              ),
              child: footer!,
            ),
        ],
      ),
    );
  }
}

class _DragHandle extends StatelessWidget {
  const _DragHandle();
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: 10, bottom: 4),
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.line,
          borderRadius: BorderRadius.circular(9),
        ),
      );
}
