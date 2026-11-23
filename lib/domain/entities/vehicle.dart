import 'package:flutter/foundation.dart';

import '../../core/utils/json_parsers.dart';
import 'fuel.dart';

/// Kullanıcının yakıt takibi yaptığı araç. Yalnızca sahibine görünür.
@immutable
class Vehicle {
  static const int maxNameLength = 40;
  static const int maxBrandLength = 40;

  final String id;
  final String ownerUid;
  final String name;
  final String? brand;
  final String fuelType;

  /// Araç eklenirken girilen kilometre (isteğe bağlı). Güncel kilometre,
  /// yakıt kayıtlarındaki en yüksek değerle birlikte hesaplanır.
  final int? odometerKm;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Vehicle({
    required this.id,
    required this.ownerUid,
    required this.name,
    this.brand,
    required this.fuelType,
    this.odometerKm,
    required this.createdAt,
    required this.updatedAt,
  });

  Vehicle copyWith({
    String? name,
    String? brand,
    String? fuelType,
    int? odometerKm,
    bool clearBrand = false,
    bool clearOdometer = false,
    DateTime? updatedAt,
  }) {
    return Vehicle(
      id: id,
      ownerUid: ownerUid,
      name: name ?? this.name,
      brand: clearBrand ? null : (brand ?? this.brand),
      fuelType: fuelType ?? this.fuelType,
      odometerKm: clearOdometer ? null : (odometerKm ?? this.odometerKm),
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'ownerUid': ownerUid,
    'name': name,
    'brand': brand,
    'fuelType': fuelType,
    'odometerKm': odometerKm,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory Vehicle.fromMap(Map<String, dynamic> map) {
    final createdAt = JsonParsers.date(
      map['createdAt'],
      fallback: DateTime.now(),
    );
    final odometer = map['odometerKm'];
    return Vehicle(
      id: JsonParsers.string(map['id']),
      ownerUid: JsonParsers.string(map['ownerUid']),
      name: JsonParsers.string(map['name']),
      brand: JsonParsers.stringOrNull(map['brand']),
      fuelType: FuelTypes.normalize(JsonParsers.stringOrNull(map['fuelType'])),
      odometerKm: odometer is num ? odometer.round() : null,
      createdAt: createdAt,
      updatedAt: JsonParsers.date(map['updatedAt'], fallback: createdAt),
    );
  }
}
