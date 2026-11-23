import 'package:carjobfinance/core/auth/auth_repository.dart';
import 'package:carjobfinance/core/purchases/purchases_gateway.dart';
import 'package:carjobfinance/presentation/controllers/entitlement_controller.dart';
import 'package:carjobfinance/presentation/controllers/session_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/auth_test_support.dart';
import '../../support/fake_purchases_gateway.dart';

const AuthUser _ana = AuthUser(id: 'user-a', email: 'ana@example.com');
const AuthUser _bia = AuthUser(id: 'user-b', email: 'bia@example.com');

class _Session extends SessionController {
  _Session(Ref ref, AuthUser? user) : super(ref, SessionState(user: user));

  void switchTo(AuthUser? user) => state = SessionState(user: user);
}

void main() {
  late FakePurchasesGateway gateway;

  setUp(() {
    gateway = FakePurchasesGateway();
  });

  ProviderContainer containerFor(AuthUser? user, {bool? forced}) {
    final container = ProviderContainer(overrides: [
      purchasesGatewayProvider.overrideWithValue(gateway),
      sessionProvider.overrideWith((ref) => _Session(ref, user)),
      premiumOverrideProvider.overrideWithValue(forced),
    ]);
    addTearDown(container.dispose);
    return container;
  }

  _Session sessionOf(ProviderContainer container) =>
      container.read(sessionProvider.notifier) as _Session;

  EntitlementController controllerOf(ProviderContainer container) =>
      container.read(entitlementProvider.notifier);

  test('a signed-out user is not premium and is never logged in', () async {
    gateway.info = activePremium;
    final container = containerFor(null);

    expect(await controllerOf(container).resolveIsPremium(), isFalse);
    expect(container.read(entitlementProvider).resolved, isTrue);
    expect(container.read(isPremiumProvider), isFalse);
    expect(gateway.loggedIn, isEmpty);
  });

  test('logs in with the user id and resolves a premium account', () async {
    gateway.info = activePremium;
    final container = containerFor(_ana);

    expect(await controllerOf(container).resolveIsPremium(), isTrue);
    expect(gateway.loggedIn, ['user-a']);
    expect(container.read(entitlementProvider).resolved, isTrue);
    expect(container.read(isPremiumProvider), isTrue);
  });

  test('an entitlement that expired in the past is not premium', () async {
    gateway.info = PremiumInfo(
      isPremium: true,
      expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
    );
    final container = containerFor(_ana);

    expect(await controllerOf(container).resolveIsPremium(), isFalse);
  });

  test('a cancelled subscription stays premium until it expires', () async {
    gateway.info = PremiumInfo(
      isPremium: true,
      expiresAt: DateTime.now().add(const Duration(days: 30)),
    );
    final container = containerFor(_ana);

    expect(await controllerOf(container).resolveIsPremium(), isTrue);
  });

  test('an update pushed by the store changes the state', () async {
    final container = containerFor(_ana);
    expect(await controllerOf(container).resolveIsPremium(), isFalse);

    gateway.push.add(activePremium);
    await pumpEventQueue();

    expect(container.read(isPremiumProvider), isTrue);
  });

  test('resolveIsPremium waits for a slow login', () async {
    gateway
      ..info = activePremium
      ..delay = const Duration(milliseconds: 30);
    final container = containerFor(_ana);

    expect(container.read(entitlementProvider).resolved, isFalse);
    expect(await controllerOf(container).resolveIsPremium(), isTrue);
  });

  test('resolveIsPremium gives up after resolveTimeout without throwing',
      () async {
    gateway
      ..info = activePremium
      ..delay = const Duration(milliseconds: 200);
    final controller = EntitlementController(
      gateway,
      'user-a',
      resolveTimeout: const Duration(milliseconds: 20),
    );
    addTearDown(controller.dispose);

    expect(await controller.resolveIsPremium(), isFalse);
    expect(controller.state.resolved, isFalse);
  });

  test('a failing store (offline, no cache) resolves as not premium', () async {
    gateway.error = Exception('offline');
    final container = containerFor(_ana);

    expect(await controllerOf(container).resolveIsPremium(), isFalse);
    expect(container.read(entitlementProvider).resolved, isTrue);
  });

  group('when logIn fails at start', () {
    late ProviderContainer container;
    late EntitlementController controller;

    setUp(() async {
      gateway
        ..info = activePremium
        ..logInError = Exception('offline');
      container = containerFor(_ana);
      controller = controllerOf(container);
      await controller.resolveIsPremium();
    });

    test('resolves as not premium without asking the store', () {
      expect(container.read(entitlementProvider),
          const EntitlementState(resolved: true));
      expect(gateway.calls, ['logIn:user-a']);
      expect(gateway.push.hasListener, isFalse);
    });

    test('purchase retries logIn and throws without buying if it fails again',
        () async {
      await expectLater(
          controller.purchase(annualTestOffer), throwsA(isA<Exception>()));
      expect(gateway.calls, ['logIn:user-a', 'logIn:user-a']);
      expect(container.read(isPremiumProvider), isFalse);
    });

    test('purchase buys for the user once the retried logIn succeeds',
        () async {
      gateway.logInError = null;

      await controller.purchase(annualTestOffer);

      expect(gateway.loggedIn, ['user-a', 'user-a']);
      expect(gateway.calls.last, 'purchase:${annualTestOffer.packageId}');
      expect(gateway.push.hasListener, isTrue);
      expect(container.read(isPremiumProvider), isTrue);
    });

    test('restore retries logIn and throws without restoring if it fails again',
        () async {
      await expectLater(controller.restore(), throwsA(isA<Exception>()));
      expect(gateway.calls, ['logIn:user-a', 'logIn:user-a']);
      expect(container.read(isPremiumProvider), isFalse);
    });

    test('restore runs for the user once the retried logIn succeeds', () async {
      gateway.logInError = null;

      await controller.restore();

      expect(gateway.loggedIn, ['user-a', 'user-a']);
      expect(gateway.calls.last, 'restore');
      expect(gateway.push.hasListener, isTrue);
      expect(container.read(isPremiumProvider), isTrue);
    });
  });

  test('switching accounts resets to none and logs the old one out', () async {
    gateway.info = activePremium;
    final container = containerFor(_ana);
    expect(await controllerOf(container).resolveIsPremium(), isTrue);
    final states = <EntitlementState>[];
    container.listen(entitlementProvider, (_, next) => states.add(next));

    gateway
      ..info = PremiumInfo.none
      ..delay = const Duration(milliseconds: 10);
    sessionOf(container).switchTo(_bia);

    expect(container.read(entitlementProvider), const EntitlementState());
    expect(await controllerOf(container).resolveIsPremium(), isFalse);
    expect(states.first, const EntitlementState());
    expect(container.read(entitlementProvider).resolved, isTrue);
    expect(gateway.loggedIn, ['user-a', 'user-b']);
    expect(gateway.logOutCalls, 1);
  });

  test('the next account logs in only after the old one logged out', () async {
    final container = containerFor(_ana);
    await controllerOf(container).resolveIsPremium();

    gateway.delay = const Duration(milliseconds: 150);
    sessionOf(container).switchTo(_bia);
    container.read(entitlementProvider);
    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect(gateway.calls.last, 'logOut');
    await controllerOf(container).resolveIsPremium();
    expect(gateway.calls, containsAllInOrder(['logOut', 'logIn:user-b']));
  });

  test('signing out logs out once and drops the premium state', () async {
    gateway.info = activePremium;
    final container = containerFor(_ana);
    expect(await controllerOf(container).resolveIsPremium(), isTrue);

    sessionOf(container).switchTo(null);

    expect(container.read(isPremiumProvider), isFalse);
    expect(container.read(entitlementProvider).resolved, isTrue);
    await pumpEventQueue();
    expect(gateway.logOutCalls, 1);
  });

  test('a late result for the previous account is never applied', () async {
    gateway
      ..info = activePremium
      ..delay = const Duration(milliseconds: 20);
    final container = containerFor(_ana);
    container.read(entitlementProvider);

    sessionOf(container).switchTo(null);
    container.read(entitlementProvider);
    await Future<void>.delayed(const Duration(milliseconds: 80));

    expect(container.read(isPremiumProvider), isFalse);
    expect(gateway.calls, isNot(contains('currentInfo')));
  });

  test('a purchase makes the account premium', () async {
    final container = containerFor(_ana);
    final controller = controllerOf(container);
    await controller.resolveIsPremium();

    await controller.purchase(annualTestOffer);

    expect(container.read(isPremiumProvider), isTrue);
  });

  test('a cancelled purchase propagates and leaves the state alone', () async {
    final container = containerFor(_ana);
    final controller = controllerOf(container);
    await controller.resolveIsPremium();
    final before = container.read(entitlementProvider);

    gateway.error = const PurchaseCancelled();

    await expectLater(
      controller.purchase(annualTestOffer),
      throwsA(isA<PurchaseCancelled>()),
    );
    expect(container.read(entitlementProvider), before);
  });

  test('restore applies what the store returns', () async {
    final container = containerFor(_ana);
    final controller = controllerOf(container);
    await controller.resolveIsPremium();

    gateway.info = activePremium;
    await controller.restore();

    expect(container.read(isPremiumProvider), isTrue);
  });

  test('forced on ignores the gateway', () async {
    final container = containerFor(_ana, forced: true);
    final controller = controllerOf(container);

    expect(await controller.resolveIsPremium(), isTrue);
    await controller.purchase(annualTestOffer);
    await controller.restore();
    expect(container.read(isPremiumProvider), isTrue);
    expect(gateway.calls, isEmpty);
  });

  test('forced off ignores a premium gateway', () async {
    gateway.info = activePremium;
    final container = containerFor(_ana, forced: false);
    final controller = controllerOf(container);

    expect(await controller.resolveIsPremium(), isFalse);
    gateway.push.add(activePremium);
    await pumpEventQueue();
    expect(container.read(isPremiumProvider), isFalse);
    expect(container.read(entitlementProvider).resolved, isTrue);
    expect(gateway.calls, isEmpty);
  });

  for (final premium in [true, false]) {
    test('AuthHarness with premium: $premium', () async {
      final h = AuthHarness()..premium = premium;
      h.auth.current = testAccount;
      final container = h.container();
      addTearDown(container.dispose);
      await container.read(sessionProvider.notifier).initialize();

      expect(await controllerOf(container).resolveIsPremium(), premium);
    });
  }

  test('NoPurchasesGateway is never premium and has no offer', () async {
    const none = NoPurchasesGateway();

    await none.logIn('user-a');
    expect(await none.currentInfo(), PremiumInfo.none);
    expect(await none.annualOffer(), isNull);
    expect(await none.restore(), PremiumInfo.none);
    expect(await none.updates.isEmpty, isTrue);
  });
}
