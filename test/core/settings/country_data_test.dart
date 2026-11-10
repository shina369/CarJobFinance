import 'package:flutter_test/flutter_test.dart';
import 'package:carjobfinance/core/settings/country_data.dart';

void main() {
  group('COUNTRIES', () {
    test('contains exactly 10 entries', () {
      expect(COUNTRIES.length, 10);
    });

    test('Brazil entry has correct fields', () {
      final br = COUNTRIES.firstWhere((c) => c.code == 'BR');
      expect(br.namePt, 'Brasil');
      expect(br.currencyCode, 'BRL');
      expect(br.currencySymbol, 'R\$');
      expect(br.localeTag, 'pt_BR');
      expect(br.platforms, contains('Uber'));
      expect(br.platforms, contains('99'));
      expect(br.platforms, contains('inDrive'));
      expect(br.platforms, contains('Taxi'));
      expect(br.platforms, contains('Transfer'));
    });

    test('Portugal entry uses EUR', () {
      final pt = COUNTRIES.firstWhere((c) => c.code == 'PT');
      expect(pt.currencySymbol, '€');
      expect(pt.localeTag, 'pt_PT');
    });

    test('Indonesia entry uses IDR', () {
      final id = COUNTRIES.firstWhere((c) => c.code == 'ID');
      expect(id.namePt, 'Indonésia');
      expect(id.currencyCode, 'IDR');
      expect(id.currencySymbol, 'Rp');
      expect(id.localeTag, 'id_ID');
      expect(id.platforms, contains('Gojek'));
    });

    test('India entry uses INR', () {
      final inEntry = COUNTRIES.firstWhere((c) => c.code == 'IN');
      expect(inEntry.namePt, 'Índia');
      expect(inEntry.currencyCode, 'INR');
      expect(inEntry.currencySymbol, '₹');
      expect(inEntry.localeTag, 'hi_IN');
      expect(inEntry.platforms, contains('Ola'));
    });

    test('all codes are unique', () {
      final codes = COUNTRIES.map((c) => c.code).toList();
      expect(codes.toSet().length, codes.length);
    });

    test('every country includes Taxi and Transfer', () {
      for (final c in COUNTRIES) {
        expect(c.platforms, contains('Taxi'), reason: '${c.code} missing Taxi');
        expect(c.platforms, contains('Transfer'), reason: '${c.code} missing Transfer');
      }
    });
  });
}
