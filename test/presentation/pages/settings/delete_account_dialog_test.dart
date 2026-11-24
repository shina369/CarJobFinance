import 'dart:async';

import 'package:carjobfinance/core/l10n/strings.dart';
import 'package:carjobfinance/core/l10n/languages.dart';
import 'package:carjobfinance/presentation/controllers/session_controller.dart';
import 'package:carjobfinance/presentation/pages/settings/delete_account_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/auth_test_support.dart';

void main() {
  Future<void> pumpDialog(
    WidgetTester tester, {
    required bool premium,
    bool unresolved = false,
  }) async {
    final h = AuthHarness()
      ..premium = premium
      ..auth.current = testAccount;
    if (unresolved) h.purchases.stallCurrentInfo = Completer<void>();
    final container = ProviderContainer(overrides: [
      ...h.overrides,
      sessionProvider.overrideWith((ref) =>
          SessionController(ref, const SessionState(user: testAccount))),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Scaffold(body: DeleteAccountDialog())),
    ));
    await tester.pumpAndSettle();
  }

  final warning = languageForTag('pt_BR')!.tr('premium.deleteAccount.warning');

  final warningFinder = find.byKey(
    const Key('settings-delete-account-premium-warning'),
  );

  testWidgets('a premium driver is warned the subscription is not cancelled',
      (tester) async {
    await pumpDialog(tester, premium: true);

    expect(find.text(warning), findsOneWidget);
    expect(warningFinder, findsOneWidget);
  });

  testWidgets('a free driver is warned too', (tester) async {
    await pumpDialog(tester, premium: false);

    expect(find.text(warning), findsOneWidget);
    expect(warningFinder, findsOneWidget);
    expect(find.byKey(const Key('settings-delete-account-password')),
        findsOneWidget);
  });

  testWidgets('the warning shows while the entitlement is unresolved',
      (tester) async {
    await pumpDialog(tester, premium: false, unresolved: true);

    expect(find.text(warning), findsOneWidget);
    expect(warningFinder, findsOneWidget);
  });
}
