import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../../core/l10n/app_locale.dart';
import '../../core/utils/json_parsers.dart';
import 'expense.dart';

/// Yakıt türleri. Firestore'da anahtar saklanır.
abstract class FuelTypes {
  static const String gasoline = 'gasoline';
  static const String diesel = 'diesel';
  static const String lpg = 'lpg';
  static const List<String> all = [gasoline, diesel, lpg];

  static String normalize(String? type) =>
      all.contains(type) ? type! : gasoline;

  static String label(String type) => switch (type) {
    diesel => 'Motorin'.tr,
    lpg => 'LPG'.tr,
    _ => 'Benzin'.tr,
  };
}

/// Akaryakıt harcamasına eklenen yakıt bilgileri.
///
/// Litre, kuruş gibi yüzde bir hassasiyetle tamsayı tutulur ([litersX100]);
/// Firestore'a okunabilir olsun diye ondalıklı litre olarak yazılır.
@immutable
class FuelDetails {
  /// Güvenlik kurallarıyla aynı sınırlar.
  static const int maxLitersX100 = 500000; // 5.000 L
  static const int maxPricePerLiterCents = 100000; // 1.000 ₺
  static const int maxOdometerKm = 9999999;
  static const int maxVehicleNameLength = 40;

  final String fuelType;
  final int litersX100;
  final int pricePerLiterCents;
  final String? vehicleId;

  /// Araç silinse de geçmiş kayıt okunabilsin diye adın kopyası.
  final String? vehicleName;
  final int? odometerKm;

  /// Depo tamamen dolduruldu mu? Tüketim iki full dolum arasında hesaplanır.
  final bool fullTank;

  const FuelDetails({
    required this.fuelType,
    required this.litersX100,
    required this.pricePerLiterCents,
    this.vehicleId,
    this.vehicleName,
    this.odometerKm,
    this.fullTank = true,
  });

  bool get hasVolume => litersX100 > 0 && pricePerLiterCents > 0;

  Map<String, dynamic> toMap() => {
    'type': fuelType,
    'liters': litersX100 / 100,
    'pricePerLiterCents': pricePerLiterCents,
    'vehicleId': vehicleId,
    'vehicleName': vehicleName,
    'odometerKm': odometerKm,
    'fullTank': fullTank,
  };

  static FuelDetails? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    final liters = map['liters'];
    final odometer = map['odometerKm'];
    return FuelDetails(
      fuelType: FuelTypes.normalize(JsonParsers.stringOrNull(map['type'])),
      litersX100: liters is num ? (liters * 100).round() : 0,
      pricePerLiterCents: JsonParsers.intValue(map['pricePerLiterCents']),
      vehicleId: JsonParsers.stringOrNull(map['vehicleId']),
      vehicleName: JsonParsers.stringOrNull(map['vehicleName']),
      odometerKm: odometer is num ? odometer.round() : null,
      fullTank: JsonParsers.boolValue(map['fullTank'], fallback: true),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is FuelDetails &&
      other.fuelType == fuelType &&
      other.litersX100 == litersX100 &&
      other.pricePerLiterCents == pricePerLiterCents &&
      other.vehicleId == vehicleId &&
      other.vehicleName == vehicleName &&
      other.odometerKm == odometerKm &&
      other.fullTank == fullTank;

  @override
  int get hashCode => Object.hash(
    fuelType,
    litersX100,
    pricePerLiterCents,
    vehicleId,
    vehicleName,
    odometerKm,
    fullTank,
  );
}

/// Tutar, litre ve litre fiyatı arasındaki dönüşümler (tamsayı kuruş / litre×100).
abstract class FuelMath {
  static final NumberFormat _liters = NumberFormat.decimalPatternDigits(
    locale: 'tr_TR',
    decimalDigits: 2,
  );
  static final NumberFormat _integer = NumberFormat.decimalPattern('tr_TR');

  /// Litre × litre fiyatı → tutar (kuruş).
  static int amountCents(int litersX100, int pricePerLiterCents) =>
      (litersX100 * pricePerLiterCents / 100).round();

  /// Tutar ÷ litre fiyatı → litre×100.
  static int litersX100(int amountCents, int pricePerLiterCents) =>
      pricePerLiterCents <= 0
      ? 0
      : (amountCents * 100 / pricePerLiterCents).round();

  /// Tutar ÷ litre → litre fiyatı (kuruş).
  static int pricePerLiterCents(int amountCents, int litersX100) =>
      litersX100 <= 0 ? 0 : (amountCents * 100 / litersX100).round();

  /// "36,58 L"
  static String formatLiters(int litersX100) =>
      '${_liters.format(litersX100 / 100)} L';

  /// "85.150 km"
  static String formatKm(int km) => '${_integer.format(km)} km';

  /// "6,74 L/100 km"
  static String formatConsumption(double litersPer100Km) =>
      '${_liters.format(litersPer100Km)} L/100 km';
}

/// Kullanıcının geçmiş yakıt kayıtlarından form için varsayılanlar.
abstract class FuelHistory {
  static List<Expense> _newestFirst(Iterable<Expense> entries) =>
      entries.where((e) => e.fuel != null).toList()
        ..sort((a, b) => b.date.compareTo(a.date));

  /// Bu yakıt türünde en son ödenen litre fiyatı.
  static int? lastPrice(Iterable<Expense> entries, String fuelType) {
    for (final e in _newestFirst(entries)) {
      final f = e.fuel!;
      if (f.fuelType == fuelType && f.pricePerLiterCents > 0) {
        return f.pricePerLiterCents;
      }
    }
    return null;
  }

  static FuelDetails? last(Iterable<Expense> entries) {
    final list = _newestFirst(entries);
    return list.isEmpty ? null : list.first.fuel;
  }

  /// Araç için girilen en yüksek kilometre.
  static int? lastOdometer(Iterable<Expense> entries, String? vehicleId) {
    int? best;
    for (final e in entries) {
      final f = e.fuel;
      if (f == null || f.vehicleId != vehicleId || f.odometerKm == null) {
        continue;
      }
      if (best == null || f.odometerKm! > best) best = f.odometerKm;
    }
    return best;
  }
}
