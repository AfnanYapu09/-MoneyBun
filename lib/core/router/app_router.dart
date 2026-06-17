import 'package:go_router/go_router.dart';

import '../../domain/entities/parsed_slip.dart';
import '../../domain/enums/enums.dart';
import '../../features/accounts/presentation/accounts_screen.dart';
import '../../features/add_transaction/presentation/add_transaction_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/slip/presentation/slip_scan_screen.dart';
import '../../features/stats/presentation/stats_screen.dart';
import 'main_shell.dart';

GoRouter buildRouter() {
  return GoRouter(
    initialLocation: '/home',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => MainShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/home', builder: (c, s) => const HomeScreen())
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/stats', builder: (c, s) => const StatsScreen())
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                  path: '/accounts', builder: (c, s) => const AccountsScreen())
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                  path: '/settings', builder: (c, s) => const SettingsScreen())
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/add',
        builder: (c, s) {
          final type = switch (s.uri.queryParameters['type']) {
            'transfer' => TxnType.transfer,
            'income' => TxnType.income,
            'expense' => TxnType.expense,
            _ => null,
          };
          return AddTransactionScreen(
            id: s.uri.queryParameters['id'],
            prefill: s.extra is ParsedSlip ? s.extra! as ParsedSlip : null,
            initialType: type,
          );
        },
      ),
      GoRoute(path: '/slip', builder: (c, s) => const SlipScanScreen()),
    ],
  );
}
