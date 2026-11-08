// Entidades de domínio - FinancialSummary (Resumo Financeiro)
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:intl/intl.dart';

part 'financial_summary.freezed.dart';
part 'financial_summary.g.dart';

@freezed
class FinancialSummary with _$FinancialSummary {
  const factory FinancialSummary({
    required double totalEarnings,
    required double totalExpenses,
    required double netProfit,
    required double totalKm,
    required int totalRides,
    required double avgPerKm,
    required double avgPerHour,
    required double avgPerRide,
    required DateTime periodStart,
    required DateTime periodEnd,
  }) = _FinancialSummary;

  factory FinancialSummary.fromJson(Map<String, dynamic> json) =>
      _$FinancialSummaryFromJson(json);

  const FinancialSummary._();

  // Helpers
  String get formattedNetProfit => 'R\$ ${NumberFormat('#,##0.00', 'pt_BR').format(netProfit)}';
  String get formattedTotalEarnings => 'R\$ ${NumberFormat('#,##0.00', 'pt_BR').format(totalEarnings)}';
  String get formattedTotalExpenses => 'R\$ ${NumberFormat('#,##0.00', 'pt_BR').format(totalExpenses)}';
  bool get isProfitable => netProfit >= 0;
}
