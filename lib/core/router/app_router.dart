// Configuração de navegação com GoRouter
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/language_provider.dart';
import '../../core/l10n/strings.dart';
import '../../core/settings/app_settings_notifier.dart';
import '../../presentation/pages/dashboard/dashboard_page.dart';
import '../../presentation/pages/rides/rides_page.dart';
import '../../presentation/pages/rides/ride_form_page.dart';
import '../../presentation/pages/expenses/expenses_page.dart';
import '../../presentation/pages/expenses/expense_form_page.dart';
import '../../presentation/pages/reports/reports_page.dart';
import '../../presentation/pages/settings/settings_page.dart';
import '../../presentation/pages/settings/platforms_page.dart';
import '../../presentation/pages/onboarding/onboarding_page.dart';

/// A [ChangeNotifier] that wraps a [StateNotifier] to provide [Listenable]
/// compatibility for GoRouter's [refreshListenable].
class _SettingsListenable extends ChangeNotifier {
  _SettingsListenable(this._notifier) {
    _subscription = _notifier.stream.listen((_) {
      notifyListeners();
    });
  }

  final StateNotifier<AppSettings> _notifier;
  late final StreamSubscription<AppSettings> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

/// Provider do router
final routerProvider = Provider<GoRouter>((ref) {
  // Build the router inside the provider so we can access ref for the redirect
  final settingsListenable =
      _SettingsListenable(ref.read(appSettingsProvider.notifier));
  // Ensure the listenable is disposed when the provider is disposed
  ref.onDispose(settingsListenable.dispose);

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
    ],

    // Redirect to onboarding if not configured
    redirect: (context, state) {
      // Read settings synchronously from the provider container
      final settings = ref.read(appSettingsProvider);
      final isOnboarding = state.matchedLocation == '/onboarding';

      if (!settings.configured && !isOnboarding) {
        // Not configured and not on onboarding -> redirect to onboarding
        return '/onboarding';
      }

      if (settings.configured && isOnboarding) {
        // Already configured but on onboarding -> redirect to home
        return '/';
      }

      // No redirect needed
      return null;
    },

    // Refresh the router when settings change
    refreshListenable: settingsListenable,

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
