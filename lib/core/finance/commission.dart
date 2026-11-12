// Cálculo de comissão de plataforma.
// A comissão é configurada por plataforma (Plataformas page) como
// percentual sobre o bruto ou valor fixo por corrida, e gravada como
// snapshot em cada corrida no momento do salvamento.
import 'package:carjobfinance/core/l10n/currencies.dart';
import 'package:carjobfinance/core/settings/locale_helper.dart';

/// Commission charged as a percentage of the gross earnings.
const String kCommissionPercent = 'percent';

/// Commission charged as a fixed amount per ride.
const String kCommissionFixed = 'fixed';

/// Computes the commission amount for a ride's gross [earnings].
/// Returns 0 when no commission is configured ([type]/[value] null or
/// non-positive).
double commissionAmountFor(double earnings, String? type, double? value) {
  if (type == null || value == null || value <= 0) return 0;
  switch (type) {
    case kCommissionPercent:
      return earnings * value / 100;
    case kCommissionFixed:
      return value;
    default:
      return 0;
  }
}

/// Formats a number without a trailing ".0" (12.0 → "12", 12.5 → "12.5").
String trimCommissionNumber(double v) =>
    v % 1 == 0 ? v.toStringAsFixed(0) : v.toString();

/// Display text for a configured commission: "12%" for percent, or the
/// amount in [currency] for a fixed commission.
String formatCommissionConfig(
    String? type, double value, AppCurrency currency) {
  if (type == kCommissionPercent) return '${trimCommissionNumber(value)}%';
  return LocalizedCurrency.formatFor(value, currency);
}
