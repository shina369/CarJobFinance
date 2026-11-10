import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:carjobfinance/presentation/pages/rides/ride_form_page.dart';
import 'package:carjobfinance/core/settings/app_settings_notifier.dart';
import 'package:carjobfinance/core/settings/country_data.dart';
import 'package:carjobfinance/core/router/app_router.dart';
import 'package:carjobfinance/data/datasources/local/app_database.dart' show CountryPlatformsDao;
import 'package:carjobfinance/data/datasources/local/daos.dart' show AppDao;

/// Dummy DAOs used to satisfy the non-nullable fields of the real
/// [AppSettingsNotifier].
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
  group('RideFormPage Platform Dropdown', () {
    late _MockAppSettingsNotifier notifier;

    /// Pump the ride form page with custom settings.
    Future<void> pumpRideFormPage(
      WidgetTester tester, {
      required AppSettings initialSettings,
      String? rideId,
    }) async {
      notifier = _MockAppSettingsNotifier(initialSettings);

      final router = GoRouter(
        initialLocation: rideId != null ? '/rides/edit/$rideId' : '/rides/new',
        routes: [
          GoRoute(
            path: '/rides/new',
            builder: (context, state) => const RideFormPage(),
          ),
          GoRoute(
            path: '/rides/edit/:rideId',
            builder: (context, state) =>
                RideFormPage(rideId: state.pathParameters['rideId']),
          ),
          GoRoute(
            path: '/',
            builder: (context, state) => const Scaffold(body: Text('Home')),
          ),
        ],
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
      'platform dropdown shows Portugal platforms when country is PT',
      (WidgetTester tester) async {
        // Configure for Portugal
        final pt = COUNTRIES.firstWhere((c) => c.code == 'PT');
        final configuredSettings = AppSettings.fromCountry(pt, pt.platforms);

        await pumpRideFormPage(tester, initialSettings: configuredSettings);

        // Find the platform dropdown
        final dropdownFinder = find.byType(DropdownButtonFormField<String>).first;
        await tester.tap(dropdownFinder);
        await tester.pumpAndSettle();

        // Verify Portugal platforms are in the dropdown menu (overlay)
        // PT platforms: ['Uber', 'Bolt', 'inDrive', 'BlaBlaCar', 'Outro']
        // After opening dropdown, the menu items appear in an overlay
        expect(find.text('Uber'), findsWidgets); // At least one (button + menu item)
        expect(find.text('Bolt'), findsOneWidget); // Only in menu
        expect(find.text('inDrive'), findsOneWidget); // Only in menu
        expect(find.text('BlaBlaCar'), findsOneWidget); // Only in menu
        expect(find.text('Outro'), findsOneWidget); // Only in menu

        // Verify Brazil-specific platforms are NOT present
        expect(find.text('99'), findsNothing);
        expect(find.text('InDrive'), findsNothing); // Note: BR uses 'InDrive', PT uses 'inDrive'
      },
    );

    testWidgets(
      'platform dropdown shows Brazil platforms when country is BR',
      (WidgetTester tester) async {
        // Configure for Brazil
        final br = COUNTRIES.firstWhere((c) => c.code == 'BR');
        final configuredSettings = AppSettings.fromCountry(br, br.platforms);

        await pumpRideFormPage(tester, initialSettings: configuredSettings);

        // Find the platform dropdown
        final dropdownFinder = find.byType(DropdownButtonFormField<String>).first;
        await tester.tap(dropdownFinder);
        await tester.pumpAndSettle();

        // Verify Brazil platforms are in the dropdown menu
        // BR platforms: ['Uber', '99', 'InDrive', 'BlaBlaCar', 'Outro']
        expect(find.text('Uber'), findsWidgets); // At least one (button + menu item)
        expect(find.text('99'), findsOneWidget); // Only in menu
        expect(find.text('InDrive'), findsOneWidget); // Only in menu
        expect(find.text('BlaBlaCar'), findsOneWidget); // Only in menu
        expect(find.text('Outro'), findsOneWidget); // Only in menu

        // Verify Portugal-specific platforms are NOT present
        expect(find.text('Bolt'), findsNothing);
        expect(find.text('inDrive'), findsNothing); // Note: BR uses 'InDrive', PT uses 'inDrive'
      },
    );
  });
}