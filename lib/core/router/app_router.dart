// Configuração de navegação com GoRouter
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/language_provider.dart';
import '../../core/l10n/strings.dart';
import '../../core/settings/app_settings_notifier.dart';
import '../../presentation/controllers/session_controller.dart';
import '../../presentation/pages/auth/account_gate_page.dart';
import '../../presentation/pages/auth/forgot_password_page.dart';
import '../../presentation/pages/auth/login_page.dart';
import '../../presentation/pages/auth/register_page.dart';
import '../../presentation/pages/dashboard/dashboard_page.dart';
import '../../presentation/pages/rides/rides_page.dart';
import '../../presentation/pages/rides/ride_form_page.dart';
import '../../presentation/pages/expenses/expenses_page.dart';
import '../../presentation/pages/expenses/expense_form_page.dart';
import '../../presentation/pages/reports/reports_page.dart';
import '../../presentation/pages/settings/settings_page.dart';
import '../../presentation/pages/settings/platforms_page.dart';
import '../../presentation/pages/settings/option_picker_page.dart';
import '../../presentation/pages/onboarding/onboarding_page.dart';
import '../../presentation/pages/settings/backup_page.dart';
import '../../presentation/pages/settings/legal_page.dart';

/// Adapts a [Stream] to the [Listenable] GoRouter refreshes on.
class _StreamListenable extends ChangeNotifier {
  _StreamListenable(Stream<Object?> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<Object?> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

const Set<String> _signedOutRoutes = {
  '/login',
  '/register',
  '/forgot-password',
};

/// Where the app must go instead of [location], or null to stay.
///
/// Order of the gates: login, then any decision pending after login, then the
/// first-run onboarding (country selection), which a configured device never
/// sees again.
String? appRedirect({
  required SessionState session,
  required bool configured,
  required String location,
}) {
  if (!session.isAuthenticated) {
    return _signedOutRoutes.contains(location) ? null : '/login';
  }
  if (session.gate != LoginGate.none) {
    return location == '/account-gate' ? null : '/account-gate';
  }
  final home = configured ? '/' : '/onboarding';
  if (_signedOutRoutes.contains(location) || location == '/account-gate') {
    return home;
  }
  if (!configured && location != '/onboarding') return '/onboarding';
  if (configured && location == '/onboarding') return '/';
  return null;
}

/// Provider do router
final routerProvider = Provider<GoRouter>((ref) {
  final settingsListenable =
      _StreamListenable(ref.read(appSettingsProvider.notifier).stream);
  final sessionListenable =
      _StreamListenable(ref.read(sessionProvider.notifier).stream);
  ref.onDispose(settingsListenable.dispose);
  ref.onDispose(sessionListenable.dispose);

  return GoRouter(
    initialLocation: '/',
    routes: [
      // Shell route com bottom navigation
      ShellRoute(
        builder: (context, state, child) {
          return _MainShell(child: child);
        },
        routes: [
          // Dashboard
          GoRoute(
            path: '/',
            name: 'dashboard',
            builder: (context, state) => const DashboardPage(),
          ),

          // Corridas
          GoRoute(
            path: '/rides',
            name: 'rides',
            builder: (context, state) => const RidesPage(),
            routes: [
              GoRoute(
                path: 'new',
                name: 'ride-new',
                builder: (context, state) => const RideFormPage(),
              ),
              GoRoute(
                path: 'edit/:rideId',
                name: 'ride-edit',
                builder: (context, state) {
                  final rideId = state.pathParameters['rideId']!;
                  return RideFormPage(rideId: rideId);
                },
              ),
              GoRoute(
                path: ':rideId',
                name: 'ride-detail',
                builder: (context, state) {
                  final rideId = state.pathParameters['rideId']!;
                  return RideDetailPage(rideId: rideId);
                },
              ),
            ],
          ),

          // Despesas
          GoRoute(
            path: '/expenses',
            name: 'expenses',
            builder: (context, state) => const ExpensesPage(),
            routes: [
              GoRoute(
                path: 'new',
                name: 'expense-new',
                builder: (context, state) => const ExpenseFormPage(),
              ),
              GoRoute(
                path: 'edit/:expenseId',
                name: 'expense-edit',
                builder: (context, state) {
                  final expenseId = state.pathParameters['expenseId']!;
                  return ExpenseFormPage(expenseId: expenseId);
                },
              ),
            ],
          ),

          // Relatórios
          GoRoute(
            path: '/reports',
            name: 'reports',
            builder: (context, state) => const ReportsPage(),
          ),

          // Configurações
          GoRoute(
            path: '/settings',
            name: 'settings',
            builder: (context, state) => const SettingsPage(),
            routes: [
              GoRoute(
                path: 'platforms',
                name: 'settings-platforms',
                builder: (context, state) => const PlatformsPage(),
              ),
              GoRoute(
                path: 'language',
                name: 'settings-language',
                builder: (context, state) => const LanguagePickerPage(),
              ),
              GoRoute(
                path: 'currency',
                name: 'settings-currency',
                builder: (context, state) => const CurrencyPickerPage(),
              ),
              GoRoute(
                path: 'backup',
                name: 'settings-backup',
                builder: (context, state) => const BackupPage(),
              ),
              GoRoute(
                path: 'terms',
                name: 'settings-terms',
                builder: (context, state) => const LegalPage.terms(),
              ),
              GoRoute(
                path: 'privacy',
                name: 'settings-privacy',
                builder: (context, state) => const LegalPage.privacy(),
              ),
            ],
          ),
        ],
      ),

      // Rotas fora do shell (full screen)
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        builder: (context, state) => const OnboardingPage(),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (context, state) =>
            RegisterPage(pendingEmail: state.extra as String?),
      ),
      GoRoute(
        path: '/forgot-password',
        name: 'forgot-password',
        builder: (context, state) => const ForgotPasswordPage(),
      ),
      GoRoute(
        path: '/account-gate',
        name: 'account-gate',
        builder: (context, state) => const AccountGatePage(),
      ),
    ],

    redirect: (context, state) => appRedirect(
      session: ref.read(sessionProvider),
      configured: ref.read(appSettingsProvider).configured,
      location: state.matchedLocation,
    ),

    refreshListenable:
        Listenable.merge([settingsListenable, sessionListenable]),

    // Observers para analytics/logging
    observers: [
      // AnalyticsObserver(),
    ],

    // Error handling
    errorBuilder: (context, state) => _ErrorPage(error: state.error),
  );
});

/// Shell com Bottom Navigation Bar
class _MainShell extends ConsumerWidget {
  const _MainShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).uri.toString();
    int currentIndex = 0;

    if (location.startsWith('/rides')) {
      currentIndex = 1;
    } else if (location.startsWith('/expenses')) {
      currentIndex = 2;
    } else if (location.startsWith('/reports')) {
      currentIndex = 3;
    } else if (location.startsWith('/settings')) {
      currentIndex = 4;
    }

    return Scaffold(
      body: child,
      bottomNavigationBar: Consumer(
        builder: (context, ref, _) {
          final lang = ref.watch(appLanguageProvider);
          return NavigationBar(
            selectedIndex: currentIndex,
            onDestinationSelected: (index) {
              switch (index) {
                case 0:
                  context.go('/');
                  break;
                case 1:
                  context.go('/rides');
                  break;
                case 2:
                  context.go('/expenses');
                  break;
                case 3:
                  context.go('/reports');
                  break;
                case 4:
                  context.go('/settings');
                  break;
              }
            },
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.dashboard_outlined),
                selectedIcon: const Icon(Icons.dashboard),
                label: lang.tr('nav.home'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.directions_car_outlined),
                selectedIcon: const Icon(Icons.directions_car),
                label: lang.tr('nav.rides'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.receipt_long_outlined),
                selectedIcon: const Icon(Icons.receipt_long),
                label: lang.tr('nav.expenses'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.bar_chart_outlined),
                selectedIcon: const Icon(Icons.bar_chart),
                label: lang.tr('nav.reports'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.settings_outlined),
                selectedIcon: const Icon(Icons.settings),
                label: lang.tr('nav.settings'),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Página de erro genérica
class _ErrorPage extends ConsumerWidget {
  const _ErrorPage({required this.error});

  final Exception? error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(appLanguageProvider);
    return Scaffold(
      appBar: AppBar(title: Text(lang.tr('error.title'))),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                lang.tr('error.body'),
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                error?.toString() ?? lang.tr('error.unknown'),
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => context.go('/'),
                icon: const Icon(Icons.home),
                label: Text(lang.tr('error.backHome')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Placeholder for RideDetailPage (to be implemented)
class RideDetailPage extends ConsumerWidget {
  const RideDetailPage({super.key, required this.rideId});

  final String rideId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(appLanguageProvider);
    return Scaffold(
      appBar: AppBar(title: Text(lang.tr('rides.details'))),
      body: Center(
        child: Text(
          lang.tr('rides.detailsWip', args: {'id': rideId}),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
