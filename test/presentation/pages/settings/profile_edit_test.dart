import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carjobfinance/core/auth/auth_repository.dart';
import 'package:carjobfinance/core/l10n/language_provider.dart';
import 'package:carjobfinance/core/l10n/languages.dart';
import 'package:carjobfinance/core/settings/app_settings_notifier.dart';
import 'package:carjobfinance/core/settings/country_data.dart';
import 'package:carjobfinance/data/datasources/local/app_database.dart'
    show CountryPlatformsDao, PlatformState;
import 'package:carjobfinance/data/datasources/local/daos.dart' show AppDao;
import 'package:carjobfinance/presentation/controllers/session_controller.dart';
import 'package:carjobfinance/presentation/pages/settings/settings_page.dart';

import '../../../support/auth_test_support.dart';

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

class _StubCountryPlatformsDao implements CountryPlatformsDao {
  @override
  Future<void> upsertCountryPlatforms(
      String countryCode, List<String> platforms,
      {Map<String, PlatformState> existingStates = const {}}) async {}

  @override
  Future<void> deleteObsoletePlatforms(Set<String> names) async {}

  @override
  Future<List<PlatformState>> getPlatformsFor(String countryCode) async => [];

  @override
  Future<List<String>> getPlatformNames(String countryCode) async => [];

  @override
  Future<Map<String, PlatformState>> getExistingStates(
          String countryCode) async =>
      {};

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('StubCountryPlatformsDao');
}

const _namedAccount = AuthUser(
  id: 'user-1',
  email: 'ana@example.com',
  firstName: 'Ana',
  lastName: 'Souza',
);

void main() {
  late AuthHarness h;
  late ProviderContainer container;

  Future<void> pumpSettings(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 5000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    h = AuthHarness();
    h.auth.current = _namedAccount;
    h.auth.account = _namedAccount;
    container = ProviderContainer(overrides: [
      ...h.overrides,
      appLanguageProvider.overrideWithValue(languageForTag('pt_BR')!),
      languageDaoProvider.overrideWithValue(_InMemoryAppDao()),
      appSettingsProvider.overrideWith((ref) => AppSettingsNotifier.forTesting(
            _InMemoryAppDao(),
            _StubCountryPlatformsDao(),
            AppSettings.defaultBrazil(),
          )),
      sessionProvider.overrideWith((ref) =>
          SessionController(ref, const SessionState(user: _namedAccount))),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: SettingsPage()),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> openEditor(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('settings-profile-edit')));
    await tester.pumpAndSettle();
  }

  testWidgets('the Perfil block shows the name, email and country',
      (tester) async {
    await pumpSettings(tester);

    final br = COUNTRIES.firstWhere((c) => c.code == 'BR');
    expect(find.text('Perfil'), findsOneWidget);
    expect(find.text('Ana'), findsOneWidget);
    expect(find.text('Souza'), findsOneWidget);
    expect(find.text('ana@example.com'), findsOneWidget);
    expect(find.text(br.namePt), findsWidgets);
  });

  testWidgets('editing the last name saves it to the account', (tester) async {
    await pumpSettings(tester);
    await openEditor(tester);

    await tester.enterText(
        find.byKey(const Key('settings-profile-last-name')), 'Lima');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings-profile-save')));
    await tester.pumpAndSettle();

    expect(h.auth.calls, ['profile:Ana Lima']);
    expect(find.byKey(const Key('settings-profile-save')), findsNothing);
    expect(find.text('Lima'), findsOneWidget);
    expect(find.text('Perfil atualizado'), findsOneWidget);
  });

  testWidgets('a blank name keeps Save disabled and nothing is sent',
      (tester) async {
    await pumpSettings(tester);
    await openEditor(tester);

    await tester.enterText(
        find.byKey(const Key('settings-profile-last-name')), '   ');
    await tester.pumpAndSettle();

    final save = tester
        .widget<FilledButton>(find.byKey(const Key('settings-profile-save')));
    expect(save.onPressed, isNull);
    expect(h.auth.calls, isEmpty);
  });

  testWidgets('changing the country updates this device', (tester) async {
    await pumpSettings(tester);
    await openEditor(tester);

    final pt = COUNTRIES.firstWhere((c) => c.code == 'PT');
    await tester.tap(find.byKey(const Key('settings-profile-country')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(pt.namePt).last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings-profile-save')));
    await tester.pumpAndSettle();

    expect(container.read(appSettingsProvider).countryCode, 'PT');
    expect(h.auth.calls, isEmpty);
    expect(find.text(pt.namePt), findsWidgets);
  });
}
