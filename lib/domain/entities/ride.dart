// Entidades de domínio - Ride (Corrida)
import 'package:freezed_annotation/freezed_annotation.dart';

part 'ride.freezed.dart';
part 'ride.g.dart';

@freezed
class Ride with _$Ride {
  const factory Ride({
    required String id,
    required DateTime date,
    required String platform,
    required double earnings,
    required double distanceKm,
    required int durationMinutes,
    String? origin,
    String? destination,
    required String rideType,
    String? commissionType,
    double? commissionValue,
    @Default(0.0) double commissionAmount,
    @Default(false) bool isSynced,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _Ride;

  factory Ride.fromJson(Map<String, dynamic> json) => _$RideFromJson(json);

  const Ride._();

  // Helpers
  /// Gross earnings minus the platform commission snapshot.
  double get netEarnings => earnings - commissionAmount;
  bool get hasCommission => commissionAmount > 0;
  double get earningsPerKm => distanceKm > 0 ? earnings / distanceKm : 0;
  double get earningsPerHour =>
      durationMinutes > 0 ? (earnings / durationMinutes) * 60 : 0;
  String get formattedDate =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  String get formattedTime =>
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  String get formattedDuration {
    final hours = durationMinutes ~/ 60;
    final minutes = durationMinutes % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}min';
    }
    return '${minutes}min';
  }
}
