import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../bootstrap/providers.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/signup_screen.dart';
import '../../features/categories/presentation/manage_categories_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/recurring/presentation/manage_recurring_screen.dart';
import '../../features/settings/presentation/currency_screen.dart';
import '../../features/settings/presentation/help_screen.dart';
import '../../features/settings/presentation/profile_screen.dart';
import '../../features/settings/presentation/export_screen.dart';
import '../../features/settings/presentation/savings_goal_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/settings/presentation/theme_screen.dart';
import '../../features/splash/presentation/splash_screen.dart';
import '../../features/stats/presentation/budget_screen.dart';
import '../../features/stats/presentation/comparison_screen.dart';
import '../../features/stats/presentation/stats_screen.dart';
import '../../features/tags/presentation/manage_tags_screen.dart';
import '../../features/transactions/presentation/all_transactions_screen.dart';
import '../../features/transactions/presentation/search_screen.dart';
import 'main_shell.dart';
import 'transitions.dart';

/// Public routes reachable before signing in. Everything else is behind auth.
const _authFunnel = {'/login', '/signup', '/forgot-password', '/onboarding'};

GoRouter buildRouter(Ref ref) {
  // Re-run the redirect whenever the Firebase auth state changes (sign-in,
  // sign-out, token expiry) so protected screens are left the instant the user
  // is no longer signed in.
  final refresh = GoRouterRefreshStream(
    ref.read(authServiceProvider)?.authStateChanges(),
  );
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    // Cloud-only: the app is usable only while signed in. The splash plays its
    // brand beat and routes onward itself; every other route is gated here.
    redirect: (context, state) {
      final loc = state.matchedLocation;
      if (loc == '/splash') return null;
      final signedIn = ref.read(authServiceProvider)?.currentUser != null;
      final inFunnel = _authFunnel.contains(loc);
      if (!signedIn) return inFunnel ? null : '/login';
      // Signed in — don't linger on the sign-in funnel.
      if (inFunnel) return '/home';
      return null;
    },
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
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/home', builder: (c, s) => const HomeScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/stats', builder: (c, s) => const StatsScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (c, s) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),

      // Transactions
      GoRoute(
        path: '/transactions',
        pageBuilder: (c, s) => slidePage(
          AllTransactionsScreen(
            categoryId: s.uri.queryParameters['categoryId'],
            tagId: s.uri.queryParameters['tagId'],
          ),
        ),
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
        path: '/settings/recurring',
        pageBuilder: (c, s) => slidePage(const ManageRecurringScreen()),
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
        path: '/settings/export',
        pageBuilder: (c, s) => slidePage(const ExportScreen()),
      ),
      GoRoute(
        path: '/settings/help',
        pageBuilder: (c, s) => slidePage(const HelpScreen()),
      ),
    ],
  );
}

/// Adapts a [Stream] (here, Firebase auth-state changes) into a [Listenable] so
/// GoRouter re-evaluates its redirect whenever the stream emits.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic>? stream) {
    if (stream != null) {
      _sub = stream.asBroadcastStream().listen((_) => notifyListeners());
    }
  }

  StreamSubscription<dynamic>? _sub;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
