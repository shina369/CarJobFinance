import 'package:carjobfinance/core/auth/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isValidEmail', () {
    test('accepts a normal address', () {
      expect(isValidEmail('ana@example.com'), isTrue);
    });

    test('rejects text without an at sign or domain', () {
      expect(isValidEmail('ana.example.com'), isFalse);
      expect(isValidEmail('ana@'), isFalse);
      expect(isValidEmail(''), isFalse);
    });
  });

  group('isValidPassword', () {
    test('requires at least kMinPasswordLength characters', () {
      expect(isValidPassword('x' * (kMinPasswordLength - 1)), isFalse);
      expect(isValidPassword('x' * kMinPasswordLength), isTrue);
    });
  });

  group('isValidName', () {
    test('requires some text besides spaces', () {
      expect(isValidName('Ana'), isTrue);
      expect(isValidName('  Ana  '), isTrue);
      expect(isValidName(''), isFalse);
      expect(isValidName('   '), isFalse);
    });
  });

  group('isValidCode', () {
    test('accepts 6 to 10 digits', () {
      expect(isValidCode('123456'), isTrue);
      expect(isValidCode('1234567890'), isTrue);
    });

    test('rejects short, long or non-numeric codes', () {
      expect(isValidCode('12345'), isFalse);
      expect(isValidCode('12345678901'), isFalse);
      expect(isValidCode('12a456'), isFalse);
    });
  });
}
