// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ride.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$RideImpl _$$RideImplFromJson(Map<String, dynamic> json) => _$RideImpl(
      id: json['id'] as String,
      date: DateTime.parse(json['date'] as String),
      platform: json['platform'] as String,
      earnings: (json['earnings'] as num).toDouble(),
      distanceKm: (json['distanceKm'] as num).toDouble(),
      durationMinutes: (json['durationMinutes'] as num).toInt(),
      origin: json['origin'] as String?,
      destination: json['destination'] as String?,
      rideType: json['rideType'] as String,
      isSynced: json['isSynced'] as bool? ?? false,
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$$RideImplToJson(_$RideImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'date': instance.date.toIso8601String(),
      'platform': instance.platform,
      'earnings': instance.earnings,
      'distanceKm': instance.distanceKm,
      'durationMinutes': instance.durationMinutes,
      'origin': instance.origin,
      'destination': instance.destination,
      'rideType': instance.rideType,
      'isSynced': instance.isSynced,
      'createdAt': instance.createdAt?.toIso8601String(),
      'updatedAt': instance.updatedAt?.toIso8601String(),
    };
