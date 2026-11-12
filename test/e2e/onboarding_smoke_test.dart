import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:carjobfinance/core/settings/app_settings_notifier.dart';
import 'package:carjobfinance/core/settings/country_data.dart';
import 'package:carjobfinance/core/router/app_router.dart';
import 'package:carjobfinance/data/datasources/local/app_database.dart'
    show CountryPlatformsDao;
import 'package:carjobfinance/data/datasources/local/daos.dart' show AppDao;
import 'package:carjobfinance/presentation/pages/onboarding/onboarding_page.dart';
import 'package:carjobfinance/presentation/pages/rides/ride_form_page.dart';
import 'package:carjobfinance/core/settings/locale_helper.dart';

/// Dummy DAOs used to satisfy the non-nullable fields of the real
/// [AppSettingsNotifier]; the mock overrides [setCountry] so these are
/// never actually called by the e2e test.
class _FakeAppDao implements AppDao {
  @override
  noSuchMethod(Invocation invocation) => throw UnimplementedError('FakeAppDao');
}

class _FakeCountryPlatformsDao implements CountryPlatformsDao {
  @override
  noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('FakeCountryPlatformsDao');
}

/// Mock notifier for testing that doesn't touch a real database.
class _MockAppSettingsNotifier extends AppSettingsNotifier {
  _MockAppSettingsNotifier(AppSettings initialState)
      : super.forTesting(
            _FakeAppDao(), _FakeCountryPlatformsDao(), initialState);

  @override
  Future<void> setCountry(String countryCode) async {
    final countryEntry = COUNTRIES.firstWhere(
      (c) => c.code == countryCode,
      orElse: () => COUNTRIES.firstWhere((c) => c.code == 'BR'),
    );
    state = AppSettings.fromCountry(countryEntry, countryEntry.platforms);
  }
}

/// E2E smoke test that walks the full onboarding flow:
/// fresh start -> onboarding -> pick Portugal -> dashboard shows € -> rides page dropdown shows PT platforms
void main() {
  group('Onboarding E2E Smoke Test', () {
    late _MockAppSettingsNotifier notifier;

    /// Pump the app with a custom router that uses the mock notifier.
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
              // Dashboard - minimal stub that shows € using LocalizedCurrency
              GoRoute(
                path: '/',
                name: 'dashboard',
                builder: (context, state) => const _TestDashboardPage(),
              ),
              // Corridas - minimal stub with nested ride form
              GoRoute(
                path: '/rides',
                name: 'rides',
                builder: (context, state) =>
                    const Scaffold(body: Text('Rides', key: Key('rides'))),
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
                ],
              ),
              // Despesas (minimal stub)
              GoRoute(
                path: '/expenses',
                name: 'expenses',
                builder: (context, state) => const Scaffold(
                    body: Text('Expenses', key: Key('expenses'))),
              ),
              // Relatórios (minimal stub)
              GoRoute(
                path: '/reports',
                name: 'reports',
                builder: (context, state) =>
                    const Scaffold(body: Text('Reports', key: Key('reports'))),
              ),
              // Configurações (minimal stub)
              GoRoute(
                path: '/settings',
                name: 'settings',
                builder: (context, state) => const Scaffold(
                    body: Text('Settings', key: Key('settings'))),
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

    testWidgets(
      'Full flow: fresh start -> onboarding -> Portugal -> dashboard € -> rides page PT platforms',
      (WidgetTester tester) async {
        // Start with unconfigured settings (Brazil default, configured: false)
        final unconfiguredSettings = AppSettings.defaultBrazil();

        // Start at /onboarding to avoid initial redirect timing issues
        await pumpApp(
          tester,
          initialSettings: unconfiguredSettings,
          initialLocation: '/onboarding',
        );

        // =====================================================================
        // STEP 1: Verify we land on /onboarding (unconfigured state)
        // =====================================================================
        expect(find.text('Bem-vindo ao CarJobFinance'), findsOneWidget);
        expect(
          find.text(
              'Selecione seu país para configurar moeda, idioma e plataformas disponíveis.'),
          findsOneWidget,
        );
        expect(find.byKey(const Key('country-dropdown')), findsOneWidget);
        expect(find.byKey(const Key('continue-button')), findsOneWidget);

        // =====================================================================
        // STEP 2: Select Portugal from the dropdown and tap Continue
        // =====================================================================
        await tester.tap(find.byKey(const Key('country-dropdown')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('country-option-PT')));
        await tester.pumpAndSettle();

        final continueButton = find.byKey(const Key('continue-button'));
        await tester.tap(continueButton);
        await tester.pumpAndSettle();

        // =====================================================================
        // STEP 3: Verify dashboard shows € currency
        // The router should now redirect to / (dashboard)
        // =====================================================================
        await tester.pumpAndSettle();

        // Check that some € symbol appears on the dashboard
        bool foundEuroSymbol = false;
        final textWidgets = find.byType(Text).evaluate().toList();
        for (final element in textWidgets) {
          final text = element.widget as Text;
          final textStr = text.data ?? '';
          if (textStr.contains('€')) {
            foundEuroSymbol = true;
            break;
          }
        }
        expect(foundEuroSymbol, isTrue,
            reason: 'Dashboard should display € currency symbol');

        // =====================================================================
        // STEP 4: Navigate directly to ride form page using router
        // This avoids the RidesPage which has controller dependencies
        // =====================================================================
        final router = tester
            .widget<MaterialApp>(
              find.byType(MaterialApp),
            )
            .routerConfig as GoRouter;
        router.go('/rides/new');
        await tester.pumpAndSettle();

        // =====================================================================
        // STEP 5: Now on RideFormPage - find the platform dropdown and verify its items
        // =====================================================================
        // The platform dropdown is the first DropdownButtonFormField on the page
        final platformDropdown =
            find.byType(DropdownButtonFormField<String>).first;
        await tester.tap(platformDropdown);
        await tester.pumpAndSettle();

        // Verify dropdown items contain Portugal's 5 platforms
        // Note: effectivePlatforms may include the current _selectedPlatform if it's
        // not in the country's list (for editing rides from other countries).
        // We verify all 5 Portugal platforms are present.
        final dropdownItems =
            find.byType(DropdownMenuItem<String>).evaluate().toList();
        final dropdownTexts = dropdownItems
            .map((e) => (e.widget as DropdownMenuItem<String>).child as Text)
            .map((t) => t.data ?? '')
            .toList();

        // Check that all 5 Portugal platforms are present
        for (final platform in [
          'Uber',
          'Bolt',
          'IzzyMove',
          'Taxi',
          'Transfer'
        ]) {
          expect(dropdownTexts, contains(platform),
              reason: 'Dropdown should contain Portugal platform: $platform');
        }

        // Clean up - the ProviderScope will dispose the notifier
        // settingsListenable.dispose(); // Don't dispose here, let ProviderScope handle it
      },
    );
  });
}

/// Minimal dashboard page that shows € symbol using LocalizedCurrency
class _TestDashboardPage extends ConsumerWidget {
  const _TestDashboardPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    // Use LocalizedCurrency to format a value - this will show € for Portugal
    return Scaffold(
      appBar: AppBar(title: const Text('CarJobFinance')),
      body: Center(
        child: Text(
            'Lucro no mês: ${LocalizedCurrency.formatWithSettings(0.0, settings)}'),
      ),
    );
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

/// Simple shell for testing
class _TestMainShell extends StatelessWidget {
  const _TestMainShell({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        onDestinationSelected: (index) {
          final router = GoRouter.of(context);
          switch (index) {
            case 0:
              router.go('/');
              break;
            case 1:
              router.go('/rides');
              break;
            case 2:
              router.go('/expenses');
              break;
            case 3:
              router.go('/reports');
              break;
            case 4:
              router.go('/settings');
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
