import 'package:carjobfinance/core/auth/auth_repository.dart';
import 'package:carjobfinance/core/router/app_router.dart';
import 'package:carjobfinance/core/settings/app_settings_notifier.dart';
import 'package:carjobfinance/data/datasources/local/app_database.dart'
    show CountryPlatformsDao;
import 'package:carjobfinance/presentation/controllers/entitlement_controller.dart';
import 'package:carjobfinance/presentation/controllers/session_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/auth_test_support.dart';
import '../../support/fake_purchases_gateway.dart';

const _user = AuthUser(id: 'user-1', email: 'ana@example.com');
const _signedOut = SessionState();
const _signedIn = SessionState(user: _user);

String? _redirect({
  required SessionState session,
  bool configured = true,
  required String location,
  bool isPremium = true,
}) =>
    appRedirect(
      session: session,
      configured: configured,
      location: location,
      isPremium: isPremium,
    );

class _NoCountryPlatformsDao extends Fake implements CountryPlatformsDao {}

void main() {
  group('premium routes', () {
    test('goals without the subscription open the paywall', () {
      expect(
        _redirect(session: _signedIn, location: '/goals', isPremium: false),
        '/paywall',
      );
    });

    test('goals with the subscription open normally', () {
      expect(_redirect(session: _signedIn, location: '/goals'), isNull);
    });

    test('reports and the dashboard stay open without the subscription', () {
      for (final route in ['/reports', '/']) {
        expect(
          _redirect(session: _signedIn, location: route, isPremium: false),
          isNull,
        );
      }
    });

    test('the paywall needs a session and is not a login route', () {
      expect(_redirect(session: _signedOut, location: '/paywall'), '/login');
      expect(
        _redirect(session: _signedIn, location: '/paywall', isPremium: false),
        isNull,
      );
      expect(_redirect(session: _signedIn, location: '/paywall'), isNull);
    });

    test('the login gates still come before the subscription', () {
      expect(
        _redirect(session: _signedOut, location: '/goals', isPremium: false),
        '/login',
      );
      expect(
        _redirect(
          session: _signedIn,
          configured: false,
          location: '/goals',
          isPremium: false,
        ),
        '/onboarding',
      );
    });
  });

  group('routerProvider', () {
    testWidgets('refreshes the same router when premium changes',
        (tester) async {
      final h = AuthHarness()..premium = false;
      h.auth.current = testAccount;
      final container = ProviderContainer(overrides: [
        ...h.overrides,
        appSettingsProvider.overrideWith(
          (ref) => AppSettingsNotifier.forTesting(
            h.dao,
            _NoCountryPlatformsDao(),
            AppSettings.defaultBrazil(),
          ),
        ),
      ]);
      addTearDown(container.dispose);
      await tester
          .runAsync(container.read(sessionProvider.notifier).initialize);

      final router = container.read(routerProvider);
      await tester.pump();
      expect(container.read(entitlementProvider).resolved, isTrue);
      var refreshes = 0;
      router.routeInformationProvider.addListener(() => refreshes++);

      h.purchases.push.add(activePremium);
      await tester.pump();

      expect(container.read(isPremiumProvider), isTrue);
      expect(refreshes, greaterThan(0));
      expect(container.read(routerProvider), same(router));
      // Lets Riverpod's scheduled provider refresh run before teardown.
      await tester.pump(const Duration(seconds: 1));
    });
  });

  group('without a session', () {
    test('every app page goes to login', () {
      expect(_redirect(session: _signedOut, location: '/'), '/login');
      expect(_redirect(session: _signedOut, location: '/rides'), '/login');
      expect(
        _redirect(
            session: _signedOut, configured: false, location: '/onboarding'),
        '/login',
      );
    });

    test('login, sign-up and password recovery stay reachable', () {
      for (final route in ['/login', '/register', '/forgot-password']) {
        expect(_redirect(session: _signedOut, location: route), isNull);
      }
    });
  });

  group('with a session that needs a decision', () {
    const foreign = SessionState(user: _user, gate: LoginGate.foreignData);

    test('the rest of the app waits on the account gate', () {
      expect(_redirect(session: foreign, location: '/'), '/account-gate');
      expect(_redirect(session: foreign, location: '/rides'), '/account-gate');
    });

    test('the gate itself is not redirected', () {
      expect(_redirect(session: foreign, location: '/account-gate'), isNull);
    });
  });

  group('country step after login', () {
    test('a device without a country goes to the country page', () {
      expect(
        _redirect(session: _signedIn, configured: false, location: '/login'),
        '/onboarding',
      );
      expect(
        _redirect(session: _signedIn, configured: false, location: '/'),
        '/onboarding',
      );
    });

    test('a configured device never sees the country page again', () {
      expect(_redirect(session: _signedIn, location: '/login'), '/');
      expect(_redirect(session: _signedIn, location: '/onboarding'), '/');
    });
  });

  group('with a signed-in account', () {
    test('a configured app opens the dashboard instead of auth pages', () {
      expect(_redirect(session: _signedIn, location: '/login'), '/');
      expect(_redirect(session: _signedIn, location: '/register'), '/');
      expect(_redirect(session: _signedIn, location: '/onboarding'), '/');
    });

    test('an unconfigured app goes to onboarding first', () {
      expect(
        _redirect(session: _signedIn, configured: false, location: '/'),
        '/onboarding',
      );
      expect(
        _redirect(session: _signedIn, configured: false, location: '/login'),
        '/onboarding',
      );
    });

    test('regular pages open without redirect', () {
      expect(_redirect(session: _signedIn, location: '/rides'), isNull);
      expect(
        _redirect(
            session: _signedIn, configured: false, location: '/onboarding'),
        isNull,
      );
    });
  });
}
