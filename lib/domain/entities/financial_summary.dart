// Entidades de domínio - FinancialSummary (Resumo Financeiro)
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:carjobfinance/core/settings/locale_helper.dart';

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

  // Helpers - use locale from AppSettings via formatCurrency
  // Default to pt_BR for backward compatibility; presentation layer should override
  String get formattedNetProfit => formatCurrency(netProfit, localeTag: 'pt_BR');
  String get formattedTotalEarnings => formatCurrency(totalEarnings, localeTag: 'pt_BR');
  String get formattedTotalExpenses => formatCurrency(totalExpenses, localeTag: 'pt_BR');
  bool get isProfitable => netProfit >= 0;
}
