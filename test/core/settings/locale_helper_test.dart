import 'package:flutter_test/flutter_test.dart';
import 'package:carjobfinance/core/settings/locale_helper.dart';

void main() {
  test('formats with correct decimal/thousands separator per locale', () {
    expect(LocalizedCurrency.format(1234.56, localeTag: 'pt_BR'),
        equals('R\$ 1.234,56'));
    expect(LocalizedCurrency.format(1234.56, localeTag: 'en_US'),
        equals('\$ 1,234.56'));
    // pt_PT uses non-breaking space (U+00A0) as thousands separator
    expect(LocalizedCurrency.format(1234.56, localeTag: 'pt_PT'),
        equals('€ 1 234,56'));
  });

  test('falls back to USD when locale unknown', () {
    expect(LocalizedCurrency.format(100), startsWith('\$'));
  });
}