import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:carjobfinance/core/l10n/currencies.dart';
import 'package:carjobfinance/core/l10n/currency_provider.dart' as currency_pkg;
import 'package:carjobfinance/core/l10n/language_provider.dart';
import 'package:carjobfinance/core/settings/app_settings_notifier.dart';
import 'package:carjobfinance/core/settings/country_data.dart';
import 'package:carjobfinance/data/datasources/local/app_database.dart'
    show CountryPlatformsDao;
import 'package:carjobfinance/data/datasources/local/daos.dart' show AppDao;
import 'package:carjobfinance/domain/entities/ride.dart';
import 'package:carjobfinance/domain/repositories/repositories.dart';
import 'package:carjobfinance/presentation/controllers/controllers.dart'
    show rideRepositoryProvider;
import 'package:carjobfinance/presentation/pages/rides/rides_page.dart';

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

class _FakeAppDao implements AppDao {
  @override
  noSuchMethod(Invocation invocation) => throw UnimplementedError('FakeAppDao');
}

class _FakeCountryPlatformsDao implements CountryPlatformsDao {
  @override
  noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('FakeCountryPlatformsDao');
}

class _MockAppSettingsNotifier extends AppSettingsNotifier {
  _MockAppSettingsNotifier(AppSettings initialState)
      : super.forTesting(
            _FakeAppDao(), _FakeCountryPlatformsDao(), initialState);
}

class _FakeRideRepository implements RideRepository {
  _FakeRideRepository(this.rides);

  final List<Ride> rides;

  @override
  Stream<List<Ride>> watchAll() => Stream.value(rides);

  @override
  noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('FakeRideRepository');
}

void main() {
  testWidgets('ride amounts use the user-selected currency, not the country',
      (tester) async {
    // Country is Brazil (R$) but the user picked EUR.
    final br = COUNTRIES.firstWhere((c) => c.code == 'BR');
    final euro = currencyForCode('EUR')!;
    final ride = Ride(
      id: 'ride-1',
      date: DateTime(2026, 1, 10),
      platform: 'Uber',
      earnings: 25.5,
      distanceKm: 10,
      durationMinutes: 20,
      rideType: 'Normal',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appSettingsProvider.overrideWith((ref) => _MockAppSettingsNotifier(
              AppSettings.fromCountry(br, br.platforms))),
          languageDaoProvider.overrideWithValue(_InMemoryAppDao()),
          rideRepositoryProvider.overrideWithValue(_FakeRideRepository([ride])),
          currency_pkg.appCurrencyProvider.overrideWithValue(euro),
        ],
        child: const MaterialApp(home: RidesPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('€'), findsOneWidget);
    expect(find.textContaining(r'R$'), findsNothing);
  });

  testWidgets('the add button uses the Home green in the light theme',
      (tester) async {
    final br = COUNTRIES.firstWhere((c) => c.code == 'BR');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appSettingsProvider.overrideWith((ref) => _MockAppSettingsNotifier(
              AppSettings.fromCountry(br, br.platforms))),
          languageDaoProvider.overrideWithValue(_InMemoryAppDao()),
          rideRepositoryProvider.overrideWithValue(_FakeRideRepository([])),
        ],
        child: MaterialApp(
          theme: ThemeData(colorSchemeSeed: Colors.green),
          home: const RidesPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final fab =
        tester.widget<FloatingActionButton>(find.byType(FloatingActionButton));
    expect(fab.backgroundColor,
        Theme.of(tester.element(find.byType(RidesPage))).colorScheme.primary);
    expect(fab.foregroundColor, Colors.white);
  });
}
