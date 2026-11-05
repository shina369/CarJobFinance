// Entidades de domínio - FinancialSummary (Resumo Financeiro)
import 'package:freezed_annotation/freezed_annotation.dart';

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
  String get formattedNetProfit =>
      'R\$ ${netProfit.toStringAsFixed(2).replaceAll('.', ',')}';
  String get formattedTotalEarnings =>
      'R\$ ${totalEarnings.toStringAsFixed(2).replaceAll('.', ',')}';
  String get formattedTotalExpenses =>
      'R\$ ${totalExpenses.toStringAsFixed(2).replaceAll('.', ',')}';
  bool get isProfitable => netProfit >= 0;
}
