import 'package:carjobfinance/core/l10n/languages.dart';
import 'package:carjobfinance/core/l10n/strings.dart';
import 'package:carjobfinance/core/purchases/purchases_gateway.dart';
import 'package:carjobfinance/presentation/controllers/entitlement_controller.dart';
import 'package:carjobfinance/presentation/controllers/session_controller.dart';
import 'package:carjobfinance/presentation/pages/premium/paywall_page.dart';
import 'package:carjobfinance/presentation/pages/settings/legal_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../../support/auth_test_support.dart';
import '../../../support/fake_purchases_gateway.dart';

const _purchaseTimeout = Duration(seconds: 5);
const _restoreTimeout = Duration(seconds: 3);

PlatformException _storeError(PurchasesErrorCode code) =>
    PlatformException(code: '${code.index}');

void main() {
  final lang = languageForTag('pt_BR')!;
  late AuthHarness h;

  /// Whether the paywall was closed, and with what; null while it is open.
  late List<bool?>? closedWith;

  final cta = find.byKey(const Key('paywall-cta'));
  final restore = find.byKey(const Key('paywall-restore'));
  final error = find.byKey(const Key('paywall-error'));
  final paywall = find.byType(PaywallPage);

  Future<void> pumpPaywall(
    WidgetTester tester, {
    List<Override> overrides = const [],
    bool settle = true,
  }) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    closedWith = null;
    h.auth.current = testAccount;
    final container =
        ProviderContainer(overrides: [...h.overrides, ...overrides]);
    addTearDown(container.dispose);
    await tester.runAsync(container.read(sessionProvider.notifier).initialize);

    final router = GoRouter(routes: [
      GoRoute(
        path: '/',
        builder: (context, _) => Scaffold(
          body: TextButton(
            key: const Key('open'),
            onPressed: () async {
              final result = await context.push<bool>('/paywall');
              closedWith = [result];
            },
            child: const Text('open'),
          ),
        ),
      ),
      GoRoute(
        path: '/paywall',
        builder: (_, __) => const PaywallPage(
          purchaseTimeout: _purchaseTimeout,
          restoreTimeout: _restoreTimeout,
        ),
      ),
    ]);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open')));
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }
  }

  bool enabled(WidgetTester tester, Finder button) =>
      tester.widget<ButtonStyleButton>(button).onPressed != null;

  setUp(() => h = AuthHarness()..premium = false);

  group('content', () {
    testWidgets('lists the benefits, the yearly price and the trial',
        (tester) async {
      await pumpPaywall(tester);

      for (final key in [
        'premium.benefit.reports',
        'premium.benefit.goals',
        'premium.benefit.export',
        'premium.benefit.backup',
        'premium.benefit.reminders',
      ]) {
        expect(find.text(lang.tr(key)), findsOneWidget, reason: key);
      }
      expect(
        tester.widget<Text>(find.byKey(const Key('paywall-price'))).data,
        lang.tr('premium.price.year', args: {'price': 'R\$ 59,90'}),
      );
      expect(
        find.text(
            lang.tr('premium.price.perMonth', args: {'price': 'R\$ 4,99'})),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('paywall-trial')),
          matching: find.text(lang.tr('premium.trial', args: {'days': '7'})),
        ),
        findsOneWidget,
      );
      expect(enabled(tester, cta), isTrue);
      expect(error, findsNothing);
    });

    testWidgets('shows no trial to a driver who is not eligible',
        (tester) async {
      h.purchases.offer = const PremiumOffer(
        packageId: '\$rc_annual',
        priceText: 'R\$ 59,90',
        monthlyText: 'R\$ 4,99',
      );
      await pumpPaywall(tester);

      expect(find.byKey(const Key('paywall-price')), findsOneWidget);
      expect(find.byKey(const Key('paywall-trial')), findsNothing);
    });

    testWidgets('discloses the automatic renewal under the price',
        (tester) async {
      await pumpPaywall(tester);

      expect(
        tester.widget<Text>(find.byKey(const Key('paywall-disclosure'))).data,
        lang.tr('premium.disclosure'),
      );
    });

    testWidgets('discloses the automatic renewal when there is no trial',
        (tester) async {
      h.purchases.offer = const PremiumOffer(
        packageId: '\$rc_annual',
        priceText: 'R\$ 59,90',
        monthlyText: 'R\$ 4,99',
      );
      await pumpPaywall(tester);

      expect(find.byKey(const Key('paywall-trial')), findsNothing);
      expect(find.byKey(const Key('paywall-disclosure')), findsOneWidget);
    });

    testWidgets('without an offer explains it and disables the button',
        (tester) async {
      h.purchases.offer = null;
      await pumpPaywall(tester);

      expect(find.text(lang.tr('premium.error.unavailable')), findsOneWidget);
      expect(find.byKey(const Key('paywall-price')), findsNothing);
      expect(enabled(tester, cta), isFalse);
      expect(enabled(tester, restore), isTrue);
    });

    testWidgets('terms and privacy open the legal pages', (tester) async {
      await pumpPaywall(tester);

      await tester.tap(find.byKey(const Key('paywall-terms')));
      await tester.pumpAndSettle();
      expect(find.text(lang.tr('legal.termsBody')), findsOneWidget);
      expect(find.byType(LegalPage), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('paywall-privacy')));
      await tester.pumpAndSettle();
      expect(find.text(lang.tr('legal.privacyBody')), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(paywall, findsOneWidget);
    });

    testWidgets('closing without buying reports false', (tester) async {
      await pumpPaywall(tester);

      await tester.tap(find.byKey(const Key('paywall-close')));
      await tester.pumpAndSettle();

      expect(paywall, findsNothing);
      expect(closedWith, [false]);
    });
  });

  group('purchase', () {
    testWidgets('buys the offer and closes with true', (tester) async {
      await pumpPaywall(tester);

      await tester.tap(cta);
      await tester.pumpAndSettle();

      expect(h.purchases.calls, contains('purchase:\$rc_annual'));
      expect(paywall, findsNothing);
      expect(closedWith, [true]);
    });

    testWidgets('a cancelled purchase stays without an error', (tester) async {
      await pumpPaywall(tester);
      h.purchases.purchaseError = const PurchaseCancelled();

      await tester.tap(cta);
      await tester.pumpAndSettle();

      expect(paywall, findsOneWidget);
      expect(error, findsNothing);
      expect(enabled(tester, cta), isTrue);
      expect(closedWith, isNull);
    });

    testWidgets('a failed purchase shows the translated error', (tester) async {
      await pumpPaywall(tester);
      h.purchases.purchaseError =
          _storeError(PurchasesErrorCode.storeProblemError);

      await tester.tap(cta);
      await tester.pumpAndSettle();

      expect(
        tester.widget<Text>(error).data,
        lang.tr('premium.error.purchase'),
      );
      expect(paywall, findsOneWidget);
      expect(enabled(tester, cta), isTrue);
    });

    testWidgets('a pending payment says it is pending, not failed',
        (tester) async {
      await pumpPaywall(tester);
      h.purchases.purchaseError =
          _storeError(PurchasesErrorCode.paymentPendingError);

      await tester.tap(cta);
      await tester.pumpAndSettle();

      expect(error, findsNothing);
      expect(
        tester.widget<Text>(find.byKey(const Key('paywall-pending'))).data,
        lang.tr('premium.error.pending'),
      );
      expect(paywall, findsOneWidget);
    });

    testWidgets('a pending payment that clears later closes the paywall',
        (tester) async {
      await pumpPaywall(tester);
      h.purchases.purchaseError =
          _storeError(PurchasesErrorCode.paymentPendingError);
      await tester.tap(cta);
      await tester.pumpAndSettle();

      h.purchases.push.add(activePremium);
      await tester.pumpAndSettle();

      expect(paywall, findsNothing);
      expect(closedWith, [true]);
    });

    testWidgets('an already owned subscription is restored instead',
        (tester) async {
      await pumpPaywall(tester);
      h.purchases.purchaseError =
          _storeError(PurchasesErrorCode.productAlreadyPurchasedError);
      h.purchases.info = activePremium;

      await tester.tap(cta);
      await tester.pumpAndSettle();

      expect(h.purchases.calls, contains('restore'));
      expect(error, findsNothing);
      expect(closedWith, [true]);
    });

    testWidgets('disables both buttons while the store works', (tester) async {
      await pumpPaywall(tester);
      h.purchases.delay = const Duration(seconds: 1);

      await tester.tap(cta);
      await tester.pump();

      expect(enabled(tester, cta), isFalse);
      expect(enabled(tester, restore), isFalse);

      await tester.pumpAndSettle();
      expect(closedWith, [true]);
    });

    testWidgets('a store that never answers times out with an error',
        (tester) async {
      await pumpPaywall(tester);
      h.purchases.delay = const Duration(minutes: 10);

      await tester.tap(cta);
      await tester.pump(_purchaseTimeout + const Duration(seconds: 1));

      expect(
        tester.widget<Text>(error).data,
        lang.tr('premium.error.purchase'),
      );
      expect(enabled(tester, cta), isTrue);
      expect(paywall, findsOneWidget);

      await tester.pump(const Duration(minutes: 10));
      await tester.pumpAndSettle();
      expect(closedWith, [true], reason: 'the late purchase still counts');
    });
  });

  group('restore', () {
    testWidgets('restores and closes with true when premium comes back',
        (tester) async {
      await pumpPaywall(tester);
      h.purchases.info = activePremium;

      await tester.tap(restore);
      await tester.pumpAndSettle();

      expect(h.purchases.calls, contains('restore'));
      expect(closedWith, [true]);
    });

    testWidgets('says so when there is nothing to restore', (tester) async {
      await pumpPaywall(tester);

      await tester.tap(restore);
      await tester.pumpAndSettle();

      expect(h.purchases.calls, contains('restore'));
      expect(
        tester.widget<Text>(error).data,
        lang.tr('premium.restore.none'),
      );
      expect(paywall, findsOneWidget);
    });

    testWidgets('a failed restore shows an error', (tester) async {
      await pumpPaywall(tester);
      h.purchases.error = Exception('offline');

      await tester.tap(restore);
      await tester.pumpAndSettle();

      expect(
        tester.widget<Text>(error).data,
        lang.tr('premium.error.unavailable'),
      );
      expect(enabled(tester, restore), isTrue);
    });

    testWidgets('a restore that never answers times out', (tester) async {
      await pumpPaywall(tester);
      h.purchases.delay = const Duration(minutes: 10);

      await tester.tap(restore);
      await tester.pump(_restoreTimeout + const Duration(seconds: 1));

      expect(error, findsOneWidget);
      expect(enabled(tester, restore), isTrue);

      await tester.pump(const Duration(minutes: 10));
      await tester.pumpAndSettle();
    });
  });

  group('entitlement', () {
    testWidgets('closes with true when the driver turns out premium',
        (tester) async {
      h.premium = true;
      h.purchases.delay = const Duration(seconds: 2);
      await pumpPaywall(tester, settle: false);

      expect(paywall, findsOneWidget, reason: 'the store has not answered');
      expect(closedWith, isNull);

      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();

      expect(closedWith, [true]);
      expect(paywall, findsNothing);
      expect(h.purchases.calls, isNot(contains(startsWith('purchase'))));
    });

    testWidgets('closes at once for a driver already premium', (tester) async {
      h.premium = true;
      await pumpPaywall(tester);

      expect(closedWith, [true]);
      expect(paywall, findsNothing);
    });

    testWidgets('a forced debug answer makes the buttons quiet no-ops',
        (tester) async {
      await pumpPaywall(
        tester,
        overrides: [premiumOverrideProvider.overrideWithValue(false)],
      );

      await tester.tap(cta);
      await tester.pumpAndSettle();

      expect(h.purchases.calls, isNot(contains(startsWith('purchase'))));
      expect(error, findsNothing);
      expect(paywall, findsOneWidget);
      expect(closedWith, isNull);
    });
  });
}
