import 'package:carjobfinance/core/auth/supabase_auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase/supabase.dart' show User;

User _user(Map<String, dynamic>? metadata) => User(
      id: 'user-1',
      appMetadata: const {},
      userMetadata: metadata,
      aud: 'authenticated',
      createdAt: '2026-11-19T00:00:00Z',
      email: 'ana@example.com',
    );

void main() {
  test('reads the first name given at sign-up', () {
    final user =
        SupabaseAuthRepository.toAuthUser(_user({'first_name': ' Ana '}));
    expect(user.firstName, 'Ana');
    expect(user.email, 'ana@example.com');
  });

  test('no or blank first name maps to null', () {
    expect(SupabaseAuthRepository.toAuthUser(_user(null)).firstName, isNull);
    expect(
      SupabaseAuthRepository.toAuthUser(_user({'first_name': '  '})).firstName,
      isNull,
    );
  });

  test('reads the last name given at sign-up', () {
    final user =
        SupabaseAuthRepository.toAuthUser(_user({'last_name': ' Silva '}));
    expect(user.lastName, 'Silva');
    expect(user.firstName, isNull);
  });

  test('no or blank last name maps to null', () {
    expect(SupabaseAuthRepository.toAuthUser(_user(null)).lastName, isNull);
    expect(
      SupabaseAuthRepository.toAuthUser(_user({'last_name': '  '})).lastName,
      isNull,
    );
  });
}
