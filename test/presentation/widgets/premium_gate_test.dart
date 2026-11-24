import 'package:carjobfinance/presentation/controllers/session_controller.dart';
import 'package:carjobfinance/presentation/widgets/premium_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/auth_test_support.dart';

void main() {
  late AuthHarness h;
  late List<bool> results;
  late int paywallOpens;

  Future<void> pumpGate(WidgetTester tester) async {
    results = [];
    paywallOpens = 0;
    h.auth.current = testAccount;
    final container = h.container();
    addTearDown(container.dispose);
    await tester.runAsync(container.read(sessionProvider.notifier).initialize);

    final router = GoRouter(routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => Scaffold(
          body: Consumer(
            builder: (context, ref, _) => TextButton(
              key: const Key('gated'),
              onPressed: () async =>
                  results.add(await ensurePremium(context, ref)),
              child: const Text('gated'),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/paywall',
        builder: (context, _) {
          paywallOpens++;
          return Scaffold(
            body: Column(children: [
              TextButton(
                key: const Key('bought'),
                onPressed: () => context.pop(true),
                child: const Text('bought'),
              ),
              TextButton(
                key: const Key('gave-up'),
                onPressed: () => context.pop(),
                child: const Text('gave up'),
              ),
            ]),
          );
        },
      ),
    ]);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();
  }

  setUp(() => h = AuthHarness());

  testWidgets('a premium driver passes without seeing the paywall',
      (tester) async {
    await pumpGate(tester);

    await tester.tap(find.byKey(const Key('gated')));
    await tester.pumpAndSettle();

    expect(results, [true]);
    expect(paywallOpens, 0);
  });

  testWidgets('a premium driver still loading is not sent to the paywall',
      (tester) async {
    h.purchases.delay = const Duration(seconds: 1);
    await pumpGate(tester);

    await tester.tap(find.byKey(const Key('gated')));
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(results, [true]);
    expect(paywallOpens, 0);
  });

  group('without the subscription', () {
    setUp(() => h.premium = false);

    testWidgets('opens the paywall and passes after buying', (tester) async {
      await pumpGate(tester);

      await tester.tap(find.byKey(const Key('gated')));
      await tester.pumpAndSettle();
      expect(paywallOpens, greaterThan(0));
      await tester.tap(find.byKey(const Key('bought')));
      await tester.pumpAndSettle();

      expect(results, [true]);
    });

    testWidgets('stays blocked when the paywall closes without buying',
        (tester) async {
      await pumpGate(tester);

      await tester.tap(find.byKey(const Key('gated')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('gave-up')));
      await tester.pumpAndSettle();

      expect(results, [false]);
    });
  });
}
