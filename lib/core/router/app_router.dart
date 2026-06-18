import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/signup_screen.dart';
import '../../features/categories/presentation/manage_categories_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/settings/presentation/currency_screen.dart';
import '../../features/settings/presentation/help_screen.dart';
import '../../features/settings/presentation/profile_screen.dart';
import '../../features/settings/presentation/savings_goal_screen.dart';
import '../../features/settings/presentation/security_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/settings/presentation/theme_screen.dart';
import '../../features/splash/presentation/splash_screen.dart';
import '../../features/stats/presentation/budget_screen.dart';
import '../../features/stats/presentation/comparison_screen.dart';
import '../../features/stats/presentation/stats_screen.dart';
import '../../features/tags/presentation/manage_tags_screen.dart';
import '../../features/transactions/presentation/all_transactions_screen.dart';
import '../../features/transactions/presentation/search_screen.dart';
import '../../features/transactions/presentation/transaction_detail_screen.dart';
import 'main_shell.dart';
import 'transitions.dart';

GoRouter buildRouter(Ref ref) {
  return GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(path: '/splash', builder: (c, s) => const SplashScreen()),
      GoRoute(
        path: '/onboarding',
        pageBuilder: (c, s) => fadePage(const OnboardingScreen()),
      ),
      GoRoute(
        path: '/login',
        pageBuilder: (c, s) => fadePage(const LoginScreen()),
      ),
      GoRoute(
        path: '/signup',
        pageBuilder: (c, s) => slidePage(const SignUpScreen()),
      ),
      GoRoute(
        path: '/forgot-password',
        pageBuilder: (c, s) => slidePage(const ForgotPasswordScreen()),
      ),

      // Main tab shell.
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => MainShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/home', builder: (c, s) => const HomeScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/stats', builder: (c, s) => const StatsScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/settings', builder: (c, s) => const SettingsScreen()),
          ]),
        ],
      ),

      // Transactions
      GoRoute(
        path: '/transactions',
        pageBuilder: (c, s) => slidePage(const AllTransactionsScreen()),
      ),
      GoRoute(
        path: '/transactions/:id',
        pageBuilder: (c, s) =>
            slidePage(TransactionDetailScreen(id: s.pathParameters['id']!)),
      ),
      GoRoute(
        path: '/search',
        pageBuilder: (c, s) => slidePage(const SearchScreen()),
      ),

      // Stats sub-screens
      GoRoute(
        path: '/budget',
        pageBuilder: (c, s) => slidePage(const BudgetScreen()),
      ),
      GoRoute(
        path: '/comparison',
        pageBuilder: (c, s) => slidePage(const ComparisonScreen()),
      ),

      // Settings sub-screens
      GoRoute(
        path: '/settings/categories',
        pageBuilder: (c, s) => slidePage(const ManageCategoriesScreen()),
      ),
      GoRoute(
        path: '/settings/tags',
        pageBuilder: (c, s) => slidePage(const ManageTagsScreen()),
      ),
      GoRoute(
        path: '/settings/profile',
        pageBuilder: (c, s) => slidePage(const ProfileScreen()),
      ),
      GoRoute(
        path: '/settings/currency',
        pageBuilder: (c, s) => slidePage(const CurrencyScreen()),
      ),
      GoRoute(
        path: '/settings/savings',
        pageBuilder: (c, s) => slidePage(const SavingsGoalScreen()),
      ),
      GoRoute(
        path: '/settings/theme',
        pageBuilder: (c, s) => slidePage(const ThemeScreen()),
      ),
      GoRoute(
        path: '/settings/security',
        pageBuilder: (c, s) => slidePage(const SecurityScreen()),
      ),
      GoRoute(
        path: '/settings/help',
        pageBuilder: (c, s) => slidePage(const HelpScreen()),
      ),
    ],
  );
}
