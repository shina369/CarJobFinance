// Configuração de navegação com GoRouter
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../presentation/pages/dashboard/dashboard_page.dart';
import '../../presentation/pages/rides/rides_page.dart';
import '../../presentation/pages/rides/ride_form_page.dart';
import '../../presentation/pages/expenses/expenses_page.dart';
import '../../presentation/pages/expenses/expense_form_page.dart';
import '../../presentation/pages/reports/reports_page.dart';
import '../../presentation/pages/settings/settings_page.dart';

/// Provider do router
final routerProvider = Provider<GoRouter>((ref) {
  return _router;
});

/// Configuração principal do router
final _router = GoRouter(
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

  // Observers para analytics/logging
  observers: [
    // AnalyticsObserver(),
  ],

  // Error handling
  errorBuilder: (context, state) => _ErrorPage(error: state.error),
);

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
      bottomNavigationBar: NavigationBar(
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
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.directions_car_outlined),
            selectedIcon: Icon(Icons.directions_car),
            label: 'Corridas',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Despesas',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Relatórios',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Config',
          ),
        ],
      ),
    );
  }
}

/// Página de erro genérica
class _ErrorPage extends StatelessWidget {
  const _ErrorPage({required this.error});

  final Exception? error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Erro')),
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
                'Ops! Algo deu errado',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                error?.toString() ?? 'Erro desconhecido',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => context.go('/'),
                icon: const Icon(Icons.home),
                label: const Text('Voltar ao Início'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Página placeholder para Onboarding (a ser implementada)
class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Onboarding - Em desenvolvimento'),
      ),
    );
  }
}

/// Página placeholder para RideDetail (a ser implementada)
class RideDetailPage extends StatelessWidget {
  const RideDetailPage({super.key, required this.rideId});

  final String rideId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detalhes da Corrida')),
      body: Center(
        child: Text('Detalhes da corrida $rideId - Em desenvolvimento'),
      ),
    );
  }
}
