import 'package:carjobfinance/core/finance/commission.dart';
import 'package:carjobfinance/core/l10n/currencies.dart';
import 'package:carjobfinance/core/settings/locale_helper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final brl = SUPPORTED_CURRENCIES.firstWhere((c) => c.code == 'BRL');

  group('formatCommissionConfig', () {
    test('percent commission shows the percentage without trailing .0', () {
      expect(formatCommissionConfig(kCommissionPercent, 12, brl), '12%');
      expect(formatCommissionConfig(kCommissionPercent, 12.5, brl), '12.5%');
    });

    test('fixed commission shows the amount in the selected currency', () {
      expect(
        formatCommissionConfig(kCommissionFixed, 2, brl),
        LocalizedCurrency.formatFor(2, brl),
      );
    });
  });
}
