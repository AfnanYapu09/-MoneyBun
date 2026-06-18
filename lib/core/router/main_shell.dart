import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/generated/app_localizations.dart';
import '../theme/app_theme.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../widgets/app_icons.dart';
import 'sheets.dart';

/// App frame: an indexed-stack body (Home / Stats / Settings), a flat 72px
/// bottom nav, and a free-floating terracotta FAB that opens the Add sheet.
class MainShell extends ConsumerWidget {
  const MainShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: shell,
      floatingActionButton: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          color: AppColors.terra,
          borderRadius: BorderRadius.circular(Tokens.rFab),
          boxShadow: Tokens.fabShadow,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(Tokens.rFab),
            onTap: () {
              // FAB always adds on the Home tab.
              if (shell.currentIndex != 0) shell.goBranch(0);
              showAddTransactionSheet(context);
            },
            child:
                const Icon(AppIcons.plus, color: AppColors.reverse, size: 28),
          ),
        ),
      ),
      bottomNavigationBar: Container(
        height: 72 + MediaQuery.of(context).padding.bottom,
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: const Border(top: BorderSide(color: AppColors.line)),
        ),
        child: Row(
          children: [
            _NavItem(
              icon: AppIcons.house,
              label: l10n.navHome,
              selected: shell.currentIndex == 0,
              onTap: () => _go(0),
            ),
            _NavItem(
              icon: AppIcons.chartPie,
              label: l10n.navStats,
              selected: shell.currentIndex == 1,
              onTap: () => _go(1),
            ),
            _NavItem(
              icon: AppIcons.settings,
              label: l10n.navSettings,
              selected: shell.currentIndex == 2,
              onTap: () => _go(2),
            ),
          ],
        ),
      ),
    );
  }

  void _go(int index) =>
      shell.goBranch(index, initialLocation: index == shell.currentIndex);
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.terra : AppColors.ink3;
    return Expanded(
      child: InkResponse(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 23),
            const SizedBox(height: 3),
            Text(label,
                style: AppTypography.heading(
                    size: 11,
                    weight: selected ? FontWeight.w500 : FontWeight.w400,
                    color: color)),
          ],
        ),
      ),
    );
  }
}
