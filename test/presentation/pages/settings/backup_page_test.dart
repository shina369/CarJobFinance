import 'package:carjobfinance/core/l10n/languages.dart';
import 'package:carjobfinance/core/l10n/strings.dart';
import 'package:carjobfinance/presentation/controllers/cloud_backup_controller.dart';
import 'package:carjobfinance/presentation/controllers/session_controller.dart';
import 'package:carjobfinance/presentation/pages/settings/backup_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../../support/auth_test_support.dart';

class _RefusingBackup extends CloudBackupController {
  _RefusingBackup(super.ref);

  @override
  Future<DateTime> backupNow() async => throw const PremiumRequiredException();
}

void main() {
  final lang = languageForTag('pt_BR')!;
  late AuthHarness h;

  Future<void> pumpPage(
    WidgetTester tester, {
    bool refusing = false,
  }) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    h.auth.current = testAccount;
    final container = ProviderContainer(overrides: [
      ...h.overrides,
      if (refusing)
        cloudBackupControllerProvider
            .overrideWith((ref) => _RefusingBackup(ref)),
    ]);
    addTearDown(container.dispose);
    await tester.runAsync(container.read(sessionProvider.notifier).initialize);

    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, __) => const BackupPage()),
      GoRoute(
        path: '/paywall',
        builder: (_, __) =>
            const Scaffold(body: Text('paywall', key: Key('paywall'))),
      ),
    ]);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();
  }

  setUpAll(() => initializeDateFormatting('pt_BR'));

  setUp(() => h = AuthHarness());

  group('without the subscription', () {
    setUp(() => h.premium = false);

    testWidgets('offers the upgrade in place of the cloud backup',
        (tester) async {
      await pumpPage(tester);

      expect(find.byKey(const Key('cloud-upgrade')), findsOneWidget);
      expect(find.byKey(const Key('cloud-backup-now')), findsNothing);
      expect(find.byKey(const Key('cloud-restore')), findsOneWidget);
    });

    testWidgets('the upgrade tile opens the paywall', (tester) async {
      await pumpPage(tester);

      await tester.tap(find.byKey(const Key('cloud-upgrade')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('paywall')), findsOneWidget);
      expect(h.cloud.uploads, isEmpty);
    });
  });

  group('with the subscription', () {
    testWidgets('keeps the cloud backup and hides the upgrade', (tester) async {
      await pumpPage(tester);

      expect(find.byKey(const Key('cloud-backup-now')), findsOneWidget);
      expect(find.byKey(const Key('cloud-upgrade')), findsNothing);
      expect(find.byKey(const Key('cloud-restore')), findsOneWidget);
    });

    testWidgets('backs up on tap', (tester) async {
      h.dao.data = emptyBackup;
      await pumpPage(tester);

      await tester.tap(find.byKey(const Key('cloud-backup-now')));
      await tester.pumpAndSettle();

      expect(h.cloud.uploads, hasLength(1));
      expect(find.text(lang.tr('cloud.done')), findsOneWidget);
    });

    testWidgets('a failed upload shows the error and stays on the page',
        (tester) async {
      await pumpPage(tester);
      h.cloud.error = Exception('rls refused');

      await tester.tap(find.byKey(const Key('cloud-backup-now')));
      await tester.pumpAndSettle();

      expect(find.text(lang.tr('auth.err.unknown')), findsOneWidget);
      expect(find.byKey(const Key('paywall')), findsNothing);
    });

    testWidgets('a refusal for lack of premium opens the paywall, not an error',
        (tester) async {
      await pumpPage(tester, refusing: true);

      await tester.tap(find.byKey(const Key('cloud-backup-now')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('paywall')), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
    });
  });
}
