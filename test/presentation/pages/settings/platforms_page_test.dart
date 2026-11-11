import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:carjobfinance/core/l10n/language_provider.dart';
import 'package:carjobfinance/core/l10n/platforms_provider.dart';
import 'package:carjobfinance/core/settings/app_settings_notifier.dart';
import 'package:carjobfinance/core/settings/country_data.dart';
import 'package:carjobfinance/data/datasources/local/app_database.dart'
    show CountryPlatformsDao;
import 'package:carjobfinance/data/datasources/local/daos.dart' show AppDao;
import 'package:carjobfinance/presentation/pages/settings/platforms_page.dart';

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

/// In-memory platforms notifier: same state transitions as the real one,
/// without touching the database.
class _TestPlatformsNotifier extends PlatformsNotifier {
  _TestPlatformsNotifier(AppPlatformsPref initialState)
      : super(_FakeAppDao(), initialState);

  @override
  Future<void> initialize() async {}

  @override
  Future<void> togglePlatform(String name, bool active) async {
    state = AppPlatformsPref(
      countryCode: state.countryCode,
      platforms: state.platforms
          .map((p) => p.name == name
              ? AppPlatformInfo(
                  name: p.name, isActive: active, isCustom: p.isCustom)
              : p)
          .toList(),
    );
  }

  @override
  Future<void> addCustomPlatform(String name) async {
    state = AppPlatformsPref(
      countryCode: state.countryCode,
      platforms: [
        ...state.platforms,
        AppPlatformInfo(name: name, isActive: true, isCustom: true),
      ],
    );
  }
}

void main() {
  group('PlatformsPage add dialog', () {
    late _TestPlatformsNotifier platformsNotifier;

    Future<void> pumpPage(WidgetTester tester) async {
      final br = COUNTRIES.firstWhere((c) => c.code == 'BR');
      platformsNotifier = _TestPlatformsNotifier(
        AppPlatformsPref(
          countryCode: 'BR',
          platforms: br.platforms
              .map((n) =>
                  AppPlatformInfo(name: n, isActive: true, isCustom: false))
              .toList(),
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appSettingsProvider.overrideWith((ref) => _MockAppSettingsNotifier(
                AppSettings.fromCountry(br, br.platforms))),
            languageDaoProvider.overrideWithValue(_InMemoryAppDao()),
            platformsProvider.overrideWith((ref) => platformsNotifier),
          ],
          child: const MaterialApp(home: PlatformsPage()),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('create button enables when a new name is typed and adds it',
        (tester) async {
      await pumpPage(tester);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      FilledButton createButton() =>
          tester.widget<FilledButton>(find.byType(FilledButton));
      expect(createButton().onPressed, isNull);

      await tester.enterText(find.byType(TextField), 'MinhaApp');
      await tester.pump();
      expect(createButton().onPressed, isNotNull);

      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('MinhaApp'), findsOneWidget);
      expect(platformsNotifier.state.activeNames, contains('MinhaApp'));
    });

    testWidgets('create button stays disabled for duplicate names',
        (tester) async {
      await pumpPage(tester);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'uber');
      await tester.pump();

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
    });
  });
}
