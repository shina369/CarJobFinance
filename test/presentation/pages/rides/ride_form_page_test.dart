import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:carjobfinance/presentation/pages/rides/ride_form_page.dart';
import 'package:carjobfinance/core/l10n/language_provider.dart';
import 'package:carjobfinance/core/l10n/platforms_provider.dart';
import 'package:carjobfinance/core/settings/app_settings_notifier.dart';
import 'package:carjobfinance/core/settings/country_data.dart';
import 'package:carjobfinance/core/router/app_router.dart';
import 'package:carjobfinance/data/datasources/local/app_database.dart'
    show CountryPlatformsDao;
import 'package:carjobfinance/data/datasources/local/daos.dart' show AppDao;

/// In-memory AppDao so [languageProvider] can build a [LanguageNotifier]
/// without a real database.
class _InMemoryAppDao implements AppDao {
  final Map<String, String> _storage = {};

  @override
  Future<String?> getSetting(String key) async => _storage[key];

  @override
  Future<void> setSetting(String key, String value) async {
    _storage[key] = value;
  }

  @override
  Future<void> deleteSetting(String key) async {
    _storage.remove(key);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('InMemoryAppDao');
}

/// Dummy DAOs used to satisfy the non-nullable fields of the real
/// [AppSettingsNotifier].
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
/// Platforms notifier with a fixed in-memory state (no database).
class _TestPlatformsNotifier extends PlatformsNotifier {
  _TestPlatformsNotifier(AppPlatformsPref initialState)
      : super(_FakeAppDao(), initialState);

  @override
  Future<void> initialize() async {}
}

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

void main() {
  group('RideFormPage Platform Dropdown', () {
    late _MockAppSettingsNotifier notifier;

    /// Pump the ride form page with custom settings.
    Future<void> pumpRideFormPage(
      WidgetTester tester, {
      required AppSettings initialSettings,
      String? rideId,
      List<Override> extraOverrides = const [],
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
            languageDaoProvider.overrideWithValue(_InMemoryAppDao()),
            routerProvider.overrideWithValue(router),
            ...extraOverrides,
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
        final dropdownFinder =
            find.byType(DropdownButtonFormField<String>).first;
        await tester.tap(dropdownFinder);
        await tester.pumpAndSettle();

        // PT platforms: ['Uber', 'Bolt', 'IzzyMove', 'Taxi', 'Transfer']
        expect(find.text('Uber'),
            findsWidgets); // At least one (button + menu item)
        expect(find.text('Bolt'), findsOneWidget); // Only in menu
        expect(find.text('IzzyMove'), findsOneWidget); // Only in menu
        expect(find.text('Taxi'), findsOneWidget); // Only in menu
        expect(find.text('Transfer'), findsOneWidget); // Only in menu

        // Verify Brazil-specific platforms are NOT present
        expect(find.text('99'), findsNothing);
        expect(find.text('Maxim'), findsNothing);
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
        final dropdownFinder =
            find.byType(DropdownButtonFormField<String>).first;
        await tester.tap(dropdownFinder);
        await tester.pumpAndSettle();

        // BR platforms: ['Uber', '99', 'inDrive', 'Maxim', 'POP Move',
        //               'Garupa', 'Urbano Norte', 'Mubis', 'Taxi', 'Transfer']
        expect(find.text('Uber'),
            findsWidgets); // At least one (button + menu item)
        expect(find.text('99'), findsOneWidget); // Only in menu
        expect(find.text('inDrive'), findsOneWidget); // Only in menu
        expect(find.text('Maxim'), findsOneWidget); // Only in menu
        expect(find.text('Taxi'), findsOneWidget); // Only in menu
        expect(find.text('Transfer'), findsOneWidget); // Only in menu

        // Verify Portugal-specific platforms are NOT present
        expect(find.text('Bolt'), findsNothing);
        expect(find.text('IzzyMove'), findsNothing);
      },
    );

    testWidgets(
      'platform dropdown hides deactivated platforms and shows active customs',
      (WidgetTester tester) async {
        final pt = COUNTRIES.firstWhere((c) => c.code == 'PT');
        final configuredSettings = AppSettings.fromCountry(pt, pt.platforms);

        // Uber deactivated by the user; MinhaApp is an active custom.
        const platformsState = AppPlatformsPref(
          countryCode: 'PT',
          platforms: [
            AppPlatformInfo(name: 'Uber', isActive: false, isCustom: false),
            AppPlatformInfo(name: 'Bolt', isActive: true, isCustom: false),
            AppPlatformInfo(name: 'IzzyMove', isActive: true, isCustom: false),
            AppPlatformInfo(name: 'Taxi', isActive: true, isCustom: false),
            AppPlatformInfo(name: 'Transfer', isActive: true, isCustom: false),
            AppPlatformInfo(name: 'MinhaApp', isActive: true, isCustom: true),
          ],
        );

        await pumpRideFormPage(
          tester,
          initialSettings: configuredSettings,
          extraOverrides: [
            platformsProvider
                .overrideWith((ref) => _TestPlatformsNotifier(platformsState)),
          ],
        );

        final dropdownFinder =
            find.byType(DropdownButtonFormField<String>).first;
        await tester.tap(dropdownFinder);
        await tester.pumpAndSettle();

        expect(find.text('Uber'), findsNothing);
        expect(find.text('Bolt'), findsWidgets);
        expect(find.text('MinhaApp'), findsOneWidget);
      },
    );
  });
}
