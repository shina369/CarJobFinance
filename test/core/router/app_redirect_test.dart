import 'package:carjobfinance/core/auth/auth_repository.dart';
import 'package:carjobfinance/core/router/app_router.dart';
import 'package:carjobfinance/presentation/controllers/session_controller.dart';
import 'package:flutter_test/flutter_test.dart';

const _user = AuthUser(id: 'user-1', email: 'ana@example.com');
const _signedOut = SessionState();
const _signedIn = SessionState(user: _user);

String? _redirect({
  required SessionState session,
  bool configured = true,
  required String location,
}) =>
    appRedirect(
      session: session,
      configured: configured,
      location: location,
    );

void main() {
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
