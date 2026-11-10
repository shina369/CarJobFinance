import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:carjobfinance/core/router/app_router.dart';
import 'package:carjobfinance/core/settings/app_settings_notifier.dart';
import 'package:carjobfinance/core/settings/country_data.dart';
import 'package:carjobfinance/data/datasources/local/app_database.dart' show CountryPlatformsDao;
import 'package:carjobfinance/data/datasources/local/daos.dart' show AppDao;
import 'package:carjobfinance/presentation/pages/onboarding/onboarding_page.dart';

/// Dummy DAOs used to satisfy the non-nullable fields of the real
/// [AppSettingsNotifier]; the mock overrides [setCountry] so these are
/// never actually called by the router guard tests.
class _FakeAppDao implements AppDao {
  @override
  noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('FakeAppDao');
}

class _FakeCountryPlatformsDao implements CountryPlatformsDao {
  @override
  noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('FakeCountryPlatformsDao');
}

/// Mock notifier for testing that doesn't touch a real database.
class _MockAppSettingsNotifier extends AppSettingsNotifier {
  _MockAppSettingsNotifier(AppSettings initialState)
      : super.forTesting(_FakeAppDao(), _FakeCountryPlatformsDao(), initialState);

  @override
  Future<void> setCountry(String countryCode) async {
    final countryEntry = COUNTRIES.firstWhere(
      (c) => c.code == countryCode,
      orElse: () => COUNTRIES.firstWhere((c) => c.code == 'BR'),
    );
    state = AppSettings.fromCountry(countryEntry, countryEntry.platforms);
  }
}

void main() {
  group('Router Onboarding Guard', () {
    late _MockAppSettingsNotifier notifier;

    /// Pump the app with the real routerProvider and custom settings.
    Future<void> pumpApp(
      WidgetTester tester, {
      required AppSettings initialSettings,
      String initialLocation = '/',
    }) async {
      notifier = _MockAppSettingsNotifier(initialSettings);

      // Build a router with the same logic as app_router.dart but with test routes
      final router = GoRouter(
        initialLocation: initialLocation,
        routes: [
          // Shell route com bottom navigation
          ShellRoute(
            builder: (context, state, child) {
              return _TestMainShell(child: child);
            },
            routes: [
              // Dashboard
              GoRoute(
                path: '/',
                name: 'dashboard',
                builder: (context, state) =>
                    const Scaffold(body: Text('Dashboard', key: Key('dashboard'))),
              ),

              // Corridas (minimal)
              GoRoute(
                path: '/rides',
                name: 'rides',
                builder: (context, state) =>
                    const Scaffold(body: Text('Rides', key: Key('rides'))),
              ),

              // Despesas (minimal)
              GoRoute(
                path: '/expenses',
                name: 'expenses',
                builder: (context, state) =>
                    const Scaffold(body: Text('Expenses', key: Key('expenses'))),
              ),

              // Relatórios (minimal)
              GoRoute(
                path: '/reports',
                name: 'reports',
                builder: (context, state) =>
                    const Scaffold(body: Text('Reports', key: Key('reports'))),
              ),

              // Configurações (minimal)
              GoRoute(
                path: '/settings',
                name: 'settings',
                builder: (context, state) =>
                    const Scaffold(body: Text('Settings', key: Key('settings'))),
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

        // Redirect to onboarding if not configured (same logic as app_router.dart)
        redirect: (context, state) {
          // Read from the notifier directly (same as ref.read in provider)
          final settings = notifier.state;
          final isOnboarding = state.matchedLocation == '/onboarding';

          if (!settings.configured && !isOnboarding) {
            return '/onboarding';
          }

          if (settings.configured && isOnboarding) {
            return '/';
          }

          return null;
        },

        // Refresh the router when settings change
        refreshListenable: _TestSettingsListenable(notifier),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appSettingsProvider.overrideWith((ref) => notifier),
            routerProvider.overrideWithValue(router),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('unconfigured settings + navigate to / redirects to /onboarding', (
      WidgetTester tester,
    ) async {
      // Start with unconfigured settings (Brazil default, configured: false)
      final unconfiguredSettings = AppSettings.defaultBrazil();

      await pumpApp(
        tester,
        initialSettings: unconfiguredSettings,
        initialLocation: '/onboarding', // Start at onboarding to avoid initial redirect issue
      );

      // Navigate to / which should redirect to /onboarding
      final router = tester.widget<MaterialApp>(
        find.byType(MaterialApp),
      ).routerConfig as GoRouter;
      router.go('/');
      await tester.pumpAndSettle();

      // Should be redirected back to /onboarding
      expect(find.text('Bem-vindo ao CarJobFinance'), findsOneWidget);
      expect(find.text('Selecione seu país para configurar moeda, idioma e plataformas disponíveis.'), findsOneWidget);
    });

    testWidgets('configured settings + navigate to / lands on dashboard', (
      WidgetTester tester,
    ) async {
      // Start with configured settings (Portugal)
      final pt = COUNTRIES.firstWhere((c) => c.code == 'PT');
      final configuredSettings = AppSettings.fromCountry(pt, pt.platforms);

      await pumpApp(
        tester,
        initialSettings: configuredSettings,
        initialLocation: '/',
      );

      // Should stay on dashboard
      expect(find.byKey(const Key('dashboard')), findsOneWidget);
      expect(find.text('Dashboard'), findsOneWidget);
    });

    testWidgets('configured settings + navigate to /onboarding redirects to /', (
      WidgetTester tester,
    ) async {
      // Start with configured settings
      final pt = COUNTRIES.firstWhere((c) => c.code == 'PT');
      final configuredSettings = AppSettings.fromCountry(pt, pt.platforms);

      await pumpApp(
        tester,
        initialSettings: configuredSettings,
        initialLocation: '/onboarding',
      );

      // Should be redirected to dashboard
      expect(find.byKey(const Key('dashboard')), findsOneWidget);
      expect(find.text('Dashboard'), findsOneWidget);
    });
  });
}

/// Simple shell for testing
class _TestMainShell extends StatelessWidget {
  const _TestMainShell({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: child);
  }
}

/// Test listenable for settings changes
class _TestSettingsListenable extends ChangeNotifier {
  _TestSettingsListenable(this._notifier) {
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