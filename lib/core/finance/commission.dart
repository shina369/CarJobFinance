// Cálculo de comissão de plataforma.
// A comissão é configurada por plataforma (Plataformas page) como
// percentual sobre o bruto ou valor fixo por corrida, e gravada como
// snapshot em cada corrida no momento do salvamento.

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
