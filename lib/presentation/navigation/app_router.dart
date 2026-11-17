import 'package:harcama_takip/core/l10n/app_locale.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/providers/admin_providers.dart';
import '../../application/providers/auth_providers.dart';
import '../screens/admin/admin_categories_screen.dart';
import '../screens/admin/admin_home_screen.dart';
import '../screens/admin/admin_notifications_screens.dart';
import '../screens/auth/forgot_password_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/auth/verify_email_screen.dart';
import '../screens/budgets/budgets_screen.dart';
import '../screens/cards_installments/add_edit_card_screen.dart';
import '../screens/cards_installments/add_installment_plan_screen.dart';
import '../screens/cards_installments/card_statement_detail_screen.dart';
import '../screens/cards_installments/cards_installments_screen.dart';
import '../screens/cards_installments/installment_plan_detail_screen.dart';
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
import 'auth_redirect.dart';
import 'home_back_stack.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

/// Uygulama yönlendiricisi. Oturum değiştiğinde yeniden oluşturulmaz;
/// `refreshListenable` ile yalnızca yönlendirme kuralları yeniden değerlendirilir
/// (önceki sürüm her oturum değişiminde yeni GoRouter üretip gezinme durumunu kaybediyordu).
final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(authStateProvider, (_, __) => refresh.value++);

  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoutes.splash,
    refreshListenable: refresh,
    debugLogDiagnostics: false,
    redirect: (context, state) => resolveAuthRedirect(
      status: authStatusOf(ref.read(authStateProvider)),
      location: state.uri.path,
      fullLocation: state.uri.toString(),
      from: state.uri.queryParameters['from'],
      isAdmin: ref.read(isAdminProvider),
    ),
    errorBuilder: (context, state) => const _NotFoundScreen(),
    routes: [
      GoRoute(path: '/', redirect: (_, __) => AppRoutes.dashboard),
      GoRoute(path: AppRoutes.splash, builder: (_, __) => const SplashScreen()),
      GoRoute(path: AppRoutes.login, builder: (_, __) => const LoginScreen()),
      GoRoute(
        path: AppRoutes.register,
        builder: (_, __) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (_, state) {
          return ForgotPasswordScreen(
            initialEmail: state.uri.queryParameters['email'],
          );
        },
      ),
      GoRoute(
        path: AppRoutes.verifyEmail,
        builder: (_, __) => const VerifyEmailScreen(),
      ),

      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) =>
            AppShellScreen(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.dashboard,
                builder: (_, __) => const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/expenses',
                builder: (_, __) => const ExpenseListScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/cards',
                builder: (_, state) {
                  final tab = state.uri.queryParameters['tab'] == 'installments'
                      ? 1
                      : 0;
                  return CardsInstallmentsScreen(initialTab: tab);
                },
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/reports',
                builder: (_, __) => const ReportsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (_, __) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),

      // Eski bağlantılar ve bildirim yükleri için geriye dönük uyumluluk
      GoRoute(path: '/expenses/add', redirect: (_, __) => '/expenses/new'),
      GoRoute(path: '/cards-installments', redirect: (_, __) => '/cards'),
      GoRoute(path: '/cards/add', redirect: (_, __) => '/cards/new'),
      GoRoute(
        path: '/installments/add',
        redirect: (_, __) => '/installments/new',
      ),

      GoRoute(
        path: '/expenses/new',
        builder: (_, __) => HomeBackStack(child: const AddEditExpenseScreen()),
      ),
      GoRoute(
        path: '/expenses/:id',
        builder: (_, state) => HomeBackStack(
          child: ExpenseDetailScreen(expenseId: state.pathParameters['id']!),
        ),
        routes: [
          GoRoute(
            path: 'edit',
            builder: (_, state) => HomeBackStack(
              child: AddEditExpenseScreen(
                expenseId: state.pathParameters['id'],
              ),
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/cards/new',
        builder: (_, __) => HomeBackStack(child: const AddEditCardScreen()),
      ),
      GoRoute(
        path: '/cards/:id',
        builder: (_, state) => HomeBackStack(
          child: CardStatementDetailScreen(cardId: state.pathParameters['id']!),
        ),
        routes: [
          GoRoute(
            path: 'edit',
            builder: (_, state) => HomeBackStack(
              child: AddEditCardScreen(cardId: state.pathParameters['id']),
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/installments/new',
        builder: (_, __) =>
            HomeBackStack(child: const AddInstallmentPlanScreen()),
      ),
      GoRoute(
        path: '/installments/:id',
        builder: (_, state) => HomeBackStack(
          child: InstallmentPlanDetailScreen(
            planId: state.pathParameters['id']!,
          ),
        ),
      ),
      GoRoute(
        path: '/budgets',
        builder: (_, __) => const HomeBackStack(child: BudgetsScreen()),
      ),
      GoRoute(
        path: '/teams',
        builder: (_, __) => const HomeBackStack(child: TeamsScreen()),
      ),
      GoRoute(
        path: '/teams/new',
        builder: (_, __) => const HomeBackStack(child: CreateTeamScreen()),
      ),
      GoRoute(
        path: '/teams/join',
        builder: (_, state) {
          return HomeBackStack(
            child: AcceptInviteScreen(
              initialCode: state.uri.queryParameters['code'],
            ),
          );
        },
      ),
      GoRoute(
        path: '/teams/:id',
        builder: (_, state) => HomeBackStack(
          child: TeamDetailScreen(teamId: state.pathParameters['id']!),
        ),
      ),
      // Yönetim paneli (yalnızca yönetici; bkz. resolveAuthRedirect ve firestore.rules)
      GoRoute(
        path: '/admin',
        builder: (_, _) => const HomeBackStack(child: AdminHomeScreen()),
      ),
      GoRoute(
        path: '/admin/send',
        builder: (_, _) =>
            HomeBackStack(child: const AdminSendNotificationScreen()),
      ),
      GoRoute(
        path: '/admin/daily-reminder',
        builder: (_, _) =>
            HomeBackStack(child: const AdminDailyReminderScreen()),
      ),
      GoRoute(
        path: '/admin/history',
        builder: (_, _) =>
            HomeBackStack(child: const AdminNotificationHistoryScreen()),
      ),
      GoRoute(
        path: '/admin/categories',
        builder: (_, _) => HomeBackStack(child: const AdminCategoriesScreen()),
      ),
      GoRoute(
        path: '/admin/users',
        builder: (_, _) => HomeBackStack(child: const AdminUsersScreen()),
      ),
      GoRoute(
        path: '/admin/logs',
        builder: (_, _) => const HomeBackStack(child: AdminLogsScreen()),
      ),
      GoRoute(
        path: '/settings/profile',
        builder: (_, __) => HomeBackStack(child: const ProfileScreen()),
      ),
      GoRoute(
        path: '/settings/notifications',
        builder: (_, __) =>
            HomeBackStack(child: const NotificationSettingsScreen()),
      ),
      GoRoute(
        path: '/settings/appearance',
        builder: (_, __) => HomeBackStack(child: const ThemeLanguageScreen()),
      ),
      GoRoute(
        path: '/settings/categories',
        builder: (_, __) => HomeBackStack(child: const CategoriesScreen()),
      ),
    ],
  );

  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});

class _NotFoundScreen extends StatelessWidget {
  const _NotFoundScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.explore_off_rounded, size: 48),
              const SizedBox(height: 16),
              Text(
                'Sayfa bulunamadı'.tr,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Aradığınız sayfa taşınmış veya silinmiş olabilir.'.tr,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => context.go(AppRoutes.dashboard),
                child: Text('Ana sayfaya dön'.tr),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
