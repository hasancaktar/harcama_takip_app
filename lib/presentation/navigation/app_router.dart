import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../application/providers/auth_providers.dart';
import '../screens/auth/forgot_password_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/budgets/budgets_screen.dart';
import '../screens/cards_installments/add_edit_card_screen.dart';
import '../screens/cards_installments/add_installment_plan_screen.dart';
import '../screens/cards_installments/card_statement_detail_screen.dart';
import '../screens/cards_installments/cards_installments_screen.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/expenses/add_edit_expense_screen.dart';
import '../screens/expenses/expense_detail_screen.dart';
import '../screens/expenses/expense_list_screen.dart';
import '../screens/reports/reports_screen.dart';
import '../screens/settings/categories_screen.dart';
import '../screens/settings/notification_settings_screen.dart';
import '../screens/settings/profile_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/settings/theme_language_screen.dart';
import '../screens/shell/app_shell_screen.dart';
import '../screens/splash/splash_screen.dart';
import '../screens/teams/accept_invite_screen.dart';
import '../screens/teams/create_team_screen.dart';
import '../screens/teams/team_detail_screen.dart';
import '../screens/teams/teams_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final isLoggedIn = authState.value != null;
      final isAuthRoute = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register' ||
          state.matchedLocation == '/forgot-password' ||
          state.matchedLocation == '/';

      if (!isLoggedIn && !isAuthRoute) {
        return '/login';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),

      // Ana Shell (5 Sekmeli Alt Navigasyon)
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShellScreen(navigationShell: navigationShell);
        },
        branches: [
          // 0. Özet
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/dashboard',
                builder: (context, state) => const DashboardScreen(),
              ),
            ],
          ),

          // 1. Harcamalar
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/expenses',
                builder: (context, state) => const ExpenseListScreen(),
              ),
            ],
          ),

          // 2. Kartlar & Taksitler
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/cards-installments',
                builder: (context, state) => const CardsInstallmentsScreen(),
              ),
            ],
          ),

          // 3. Raporlar
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/reports',
                builder: (context, state) => const ReportsScreen(),
              ),
            ],
          ),

          // 4. Ayarlar
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),

      // Bağımsız Sayfalar
      GoRoute(
        path: '/expenses/add',
        builder: (context, state) => const AddEditExpenseScreen(),
      ),
      GoRoute(
        path: '/expenses/detail/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return ExpenseDetailScreen(expenseId: id);
        },
      ),
      GoRoute(
        path: '/cards/add',
        builder: (context, state) => const AddEditCardScreen(),
      ),
      GoRoute(
        path: '/cards/statement/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return CardStatementDetailScreen(cardId: id);
        },
      ),
      GoRoute(
        path: '/installments/add',
        builder: (context, state) => const AddInstallmentPlanScreen(),
      ),
      GoRoute(
        path: '/budgets',
        builder: (context, state) => const BudgetsScreen(),
      ),
      GoRoute(
        path: '/teams',
        builder: (context, state) => const TeamsScreen(),
      ),
      GoRoute(
        path: '/teams/create',
        builder: (context, state) => const CreateTeamScreen(),
      ),
      GoRoute(
        path: '/teams/detail/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return TeamDetailScreen(teamId: id);
        },
      ),
      GoRoute(
        path: '/teams/join',
        builder: (context, state) => const AcceptInviteScreen(),
      ),
      GoRoute(
        path: '/settings/notifications',
        builder: (context, state) => const NotificationSettingsScreen(),
      ),
      GoRoute(
        path: '/settings/categories',
        builder: (context, state) => const CategoriesScreen(),
      ),
      GoRoute(
        path: '/settings/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/settings/theme-language',
        builder: (context, state) => const ThemeLanguageScreen(),
      ),
    ],
  );
});
