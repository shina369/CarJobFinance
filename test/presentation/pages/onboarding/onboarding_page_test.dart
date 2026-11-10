import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:carjobfinance/core/settings/app_settings_notifier.dart';
import 'package:carjobfinance/core/settings/country_data.dart';
import 'package:carjobfinance/data/datasources/local/app_database.dart' show CountryPlatformsDao;
import 'package:carjobfinance/data/datasources/local/daos.dart' show AppDao;
import 'package:carjobfinance/presentation/pages/onboarding/onboarding_page.dart';

/// Dummy DAOs used to satisfy the non-nullable fields of the real
/// [AppSettingsNotifier]; the mock overrides [setCountry] so these are
/// never actually called by the onboarding tests.
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
/// Only [setCountry] is overridden — the page's Continue button is the
/// sole DAO-backed method the onboarding tests exercise.
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
  group('OnboardingPage', () {
    late _MockAppSettingsNotifier notifier;

    /// Pump the onboarding page with optional custom settings and router.
    /// Uses MaterialApp(home:) for non-navigation tests and MaterialApp.router for navigation tests.
    Future<void> pumpOnboardingPage(
      WidgetTester tester, {
      AppSettings? initialSettings,
      GoRouter? router,
    }) async {
      notifier = _MockAppSettingsNotifier(initialSettings ?? AppSettings.defaultBrazil());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appSettingsProvider.overrideWith((ref) => notifier),
          ],
          child: router != null
              ? MaterialApp.router(routerConfig: router)
              : const MaterialApp(home: OnboardingPage()),
        ),
      );
      await tester.pump(); // Use pump only, not pumpAndSettle, to avoid animation timeouts
    }

    testWidgets('renders country dropdown', (WidgetTester tester) async {
      await pumpOnboardingPage(tester);

      final dropdown = find.byKey(const Key('country-dropdown'));
      expect(dropdown, findsOneWidget);
    }, timeout: const Timeout(Duration(seconds: 10)));

    testWidgets('selecting a country from the dropdown enables Continue',
        (WidgetTester tester) async {
      await pumpOnboardingPage(tester);

      // Open the dropdown menu
      await tester.tap(find.byKey(const Key('country-dropdown')));
      await tester.pump();

      // Select Portugal
      await tester.tap(find.byKey(const Key('country-option-PT')));
      await tester.pumpAndSettle();

      // Continue button should now be enabled
      final continueButton = find.byKey(const Key('continue-button'));
      final buttonWidget = tester.widget<FilledButton>(continueButton);
      expect(buttonWidget.onPressed, isNotNull);
    });

    testWidgets('Continue button disabled until a country is picked', (WidgetTester tester) async {
      await pumpOnboardingPage(tester);

      // Continue button should be disabled initially
      final continueButton = find.byKey(const Key('continue-button'));
      expect(continueButton, findsOneWidget);

      final buttonWidget = tester.widget<FilledButton>(continueButton);
      expect(buttonWidget.onPressed, isNull);
    });

    testWidgets('After select + continue, navigates to /', (WidgetTester tester) async {
      final router = GoRouter(
        initialLocation: '/onboarding',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const Scaffold(
              body: Text('Home', key: Key('home-page')),
            ),
          ),
          GoRoute(
            path: '/onboarding',
            builder: (context, state) => const OnboardingPage(),
          ),
        ],
      );

      await pumpOnboardingPage(tester, router: router);

      // Open the dropdown and select Portugal
      await tester.tap(find.byKey(const Key('country-dropdown')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('country-option-PT')));
      await tester.pumpAndSettle();

      // Continue button should now be enabled
      final continueButton = find.byKey(const Key('continue-button'));
      final buttonWidget = tester.widget<FilledButton>(continueButton);
      expect(buttonWidget.onPressed, isNotNull);

      // Tap continue
      await tester.tap(continueButton);
      await tester.pumpAndSettle();

      // Should navigate to home page
      expect(find.byKey(const Key('home-page')), findsOneWidget);
    });

    testWidgets('Auto-skip when already configured', (WidgetTester tester) async {
      // Create pre-configured settings (Portugal)
      final pt = COUNTRIES.firstWhere((c) => c.code == 'PT');
      final configuredSettings = AppSettings.fromCountry(pt, pt.platforms);

      final router = GoRouter(
        initialLocation: '/onboarding',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const Scaffold(
              body: Text('Home', key: Key('home-page')),
            ),
          ),
          GoRoute(
            path: '/onboarding',
            builder: (context, state) => const OnboardingPage(),
          ),
        ],
      );

      await pumpOnboardingPage(
        tester,
        initialSettings: configuredSettings,
        router: router,
      );

      // Should show "Você já está configurado" message
      expect(find.text('Você já está configurado'), findsOneWidget);

      // Should auto-navigate to home after 800ms
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pump();

      expect(find.byKey(const Key('home-page')), findsOneWidget);
    });
  });
}