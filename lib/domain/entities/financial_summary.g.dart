// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'financial_summary.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$FinancialSummaryImpl _$$FinancialSummaryImplFromJson(
        Map<String, dynamic> json) =>
    _$FinancialSummaryImpl(
      totalEarnings: (json['totalEarnings'] as num).toDouble(),
      totalExpenses: (json['totalExpenses'] as num).toDouble(),
      netProfit: (json['netProfit'] as num).toDouble(),
      totalKm: (json['totalKm'] as num).toDouble(),
      totalRides: (json['totalRides'] as num).toInt(),
      avgPerKm: (json['avgPerKm'] as num).toDouble(),
      avgPerHour: (json['avgPerHour'] as num).toDouble(),
      avgPerRide: (json['avgPerRide'] as num).toDouble(),
      periodStart: DateTime.parse(json['periodStart'] as String),
      periodEnd: DateTime.parse(json['periodEnd'] as String),
    );

Map<String, dynamic> _$$FinancialSummaryImplToJson(
        _$FinancialSummaryImpl instance) =>
    <String, dynamic>{
      'totalEarnings': instance.totalEarnings,
      'totalExpenses': instance.totalExpenses,
      'netProfit': instance.netProfit,
      'totalKm': instance.totalKm,
      'totalRides': instance.totalRides,
      'avgPerKm': instance.avgPerKm,
      'avgPerHour': instance.avgPerHour,
      'avgPerRide': instance.avgPerRide,
      'periodStart': instance.periodStart.toIso8601String(),
      'periodEnd': instance.periodEnd.toIso8601String(),
    };
