import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
import 'package:carjobfinance/presentation/pages/rides/ride_detail_page.dart';

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

final _ride = Ride(
  id: 'ride-1',
  date: DateTime(2026, 11, 10, 14, 5),
  platform: 'Uber',
  earnings: 50,
  distanceKm: 12.5,
  durationMinutes: 35,
  rideType: 'Comum',
  commissionAmount: 10,
  origin: 'Centro',
  destination: 'Aeroporto',
);

void main() {
  Future<void> pumpDetail(WidgetTester tester, {required String id}) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final br = COUNTRIES.firstWhere((c) => c.code == 'BR');
    final router = GoRouter(
      initialLocation: '/rides/$id',
      routes: [
        GoRoute(
          path: '/rides/:rideId',
          builder: (context, state) =>
              RideDetailPage(rideId: state.pathParameters['rideId']!),
        ),
        GoRoute(
          path: '/rides/edit/:rideId',
          builder: (context, state) => const Scaffold(body: Text('editing')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appSettingsProvider.overrideWith((ref) => _MockAppSettingsNotifier(
              AppSettings.fromCountry(br, br.platforms))),
          languageDaoProvider.overrideWithValue(_InMemoryAppDao()),
          rideRepositoryProvider
              .overrideWithValue(_FakeRideRepository([_ride])),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the ride values, commission and route', (tester) async {
    await pumpDetail(tester, id: 'ride-1');

    expect(find.text('Detalhes da Corrida'), findsOneWidget);
    expect(find.text('Uber'), findsOneWidget);
    expect(find.text('Centro'), findsOneWidget);
    expect(find.text('Aeroporto'), findsOneWidget);
    expect(find.text('Comissão'), findsOneWidget);
    expect(find.text('12.5 km'), findsOneWidget);
    expect(find.text('35min'), findsOneWidget);
    expect(find.textContaining('40'), findsWidgets);
    expect(find.textContaining('10'), findsWidgets);
  });

  testWidgets('the edit button opens the ride form', (tester) async {
    await pumpDetail(tester, id: 'ride-1');

    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();

    expect(find.text('editing'), findsOneWidget);
  });

  testWidgets('an unknown ride shows the empty message', (tester) async {
    await pumpDetail(tester, id: 'missing');

    expect(find.text('Nenhuma corrida registrada'), findsOneWidget);
    expect(find.byIcon(Icons.edit_outlined), findsNothing);
  });
}
