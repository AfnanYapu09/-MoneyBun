import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/colors.dart';
import '../theme/pixel_theme.dart';

/// The app frame: indexed-stack body (Home / Stats / Settings) with a pixel
/// bottom bar and a center FAB that opens the slip scanner.
class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
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
          onPressed: () => context.push('/scan'),
          backgroundColor: AppColors.bunOrange,
          foregroundColor: AppColors.white,
          elevation: 0,
          shape: const RoundedRectangleBorder(
              borderRadius: PixelTokens.borderRadius),
          child: const Icon(Icons.document_scanner, size: 28),
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
          children: [
            _NavItem(
              icon: Icons.home_rounded,
              label: 'หน้าหลัก',
              selected: shell.currentIndex == 0,
              onTap: () => _go(0),
            ),
            _NavItem(
              icon: Icons.bar_chart_rounded,
              label: 'สถิติ',
              selected: shell.currentIndex == 1,
              onTap: () => _go(1),
            ),
            const SizedBox(width: 64),
            _NavItem(
              icon: Icons.settings_rounded,
              label: 'ตั้งค่า',
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
    final color = selected ? AppColors.bunOrange : AppColors.gray400;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    color: color,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
