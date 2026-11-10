import 'package:flutter_test/flutter_test.dart';
import 'package:carjobfinance/core/settings/country_data.dart';

void main() {
  group('COUNTRIES', () {
    test('contains exactly 8 entries', () {
      expect(COUNTRIES.length, 8);
    });

    test('Brazil entry has correct fields', () {
      final br = COUNTRIES.firstWhere((c) => c.code == 'BR');
      expect(br.namePt, 'Brasil');
      expect(br.currencyCode, 'BRL');
      expect(br.currencySymbol, 'R\$');
      expect(br.localeTag, 'pt_BR');
      expect(br.platforms, contains('Uber'));
      expect(br.platforms, contains('99'));
      expect(br.platforms, contains('InDrive'));
    });

    test('Portugal entry uses EUR', () {
      final pt = COUNTRIES.firstWhere((c) => c.code == 'PT');
      expect(pt.currencySymbol, '€');
      expect(pt.localeTag, 'pt_PT');
    });

    test('all codes are unique', () {
      final codes = COUNTRIES.map((c) => c.code).toList();
      expect(codes.toSet().length, codes.length);
    });
  });
}
