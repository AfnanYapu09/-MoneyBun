import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/generated/app_localizations.dart';
import '../theme/colors.dart';
import '../theme/pixel_theme.dart';

/// The persistent app frame: an indexed-stack body with a pixel bottom bar
/// (Home / Stats / [+ FAB] / Accounts / Settings).
class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: shell,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: PixelTokens.borderRadius,
          border: PixelTokens.inkBorder(),
          boxShadow: PixelTokens.hardShadow(),
        ),
        child: FloatingActionButton(
          onPressed: () => context.push('/add'),
          backgroundColor: AppColors.bunOrange,
          foregroundColor: AppColors.white,
          elevation: 0,
          shape: const RoundedRectangleBorder(
              borderRadius: PixelTokens.borderRadius),
          child: const Icon(Icons.add, size: 30),
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        color: AppColors.white,
        elevation: 0,
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        height: 64,
        padding: EdgeInsets.zero,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavItem(
              icon: Icons.home_rounded,
              label: l10n.navHome,
              selected: shell.currentIndex == 0,
              onTap: () => _go(0),
            ),
            _NavItem(
              icon: Icons.bar_chart_rounded,
              label: l10n.navStats,
              selected: shell.currentIndex == 1,
              onTap: () => _go(1),
            ),
            const SizedBox(width: 48),
            _NavItem(
              icon: Icons.account_balance_wallet_rounded,
              label: l10n.navAccounts,
              selected: shell.currentIndex == 2,
              onTap: () => _go(2),
            ),
            _NavItem(
              icon: Icons.settings_rounded,
              label: l10n.navSettings,
              selected: shell.currentIndex == 3,
              onTap: () => _go(3),
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
    final color = selected ? AppColors.bunOrange : AppColors.gray400;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
