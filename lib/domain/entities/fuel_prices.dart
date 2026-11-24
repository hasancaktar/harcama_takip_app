import 'package:flutter/foundation.dart';

import 'fuel.dart';

/// Bir ilin güncel pompa fiyatları (ilçe fiyatlarının ortalaması, kuruş/litre).
@immutable
class CityFuelPrices {
  /// Plaka kodu ("34").
  final String code;
  final String name;
  final Map<String, int> pricesCents;

  const CityFuelPrices({
    required this.code,
    required this.name,
    required this.pricesCents,
  });

  int? priceOf(String fuelType) => pricesCents[fuelType];
}

/// Tüm illerin güncel pompa fiyatları.
@immutable
class FuelPriceTable {
  final Map<String, CityFuelPrices> cities;
  final DateTime fetchedAt;

  const FuelPriceTable({required this.cities, required this.fetchedAt});

  CityFuelPrices? city(String? code) => code == null ? null : cities[code];

  int? priceOf(String? cityCode, String fuelType) =>
      city(cityCode)?.priceOf(fuelType);

  /// Shell pompa fiyatı servisinin yanıtını çözer. Tanınmayan ürünler ve bozuk
  /// kayıtlar atlanır; hiç il çıkmazsa [FormatException] fırlatır.
  ///
  /// Yanıt: `products` (fepProductCode, fepProductName) ve `groups` (il:
  /// cityCode, cityName, counties[].prices{ürün kodu: TL}).
  static FuelPriceTable parseShell(Object? json, {required DateTime now}) {
    if (json is! Map) throw const FormatException('fuel prices');
    final productTypes = <String, String>{};
    for (final p in (json['products'] as List?) ?? const []) {
      if (p is! Map) continue;
      final code = p['fepProductCode'];
      final type = _typeOf('${p['fepProductName']} ${p['genProductName']}');
      if (code is String && type != null) productTypes[code.trim()] = type;
    }

    final cities = <String, CityFuelPrices>{};
    for (final g in (json['groups'] as List?) ?? const []) {
      if (g is! Map) continue;
      final rawCode = g['cityCode'];
      final number = rawCode is String ? int.tryParse(rawCode.trim()) : null;
      if (number == null || number <= 0) continue;
      final code = '$number';
      final sums = <String, double>{};
      final counts = <String, int>{};
      for (final county in (g['counties'] as List?) ?? const []) {
        if (county is! Map || county['prices'] is! Map) continue;
        (county['prices'] as Map).forEach((key, value) {
          final type = productTypes['$key'.trim()];
          if (type == null || value is! num || value <= 0) return;
          sums[type] = (sums[type] ?? 0) + value;
          counts[type] = (counts[type] ?? 0) + 1;
        });
      }
      if (sums.isEmpty) continue;
      cities[code] = CityFuelPrices(
        code: code,
        name: TurkishProvinces.nameOf(code) ?? '${g['cityName'] ?? code}',
        pricesCents: {
          for (final t in sums.keys) t: (sums[t]! / counts[t]! * 100).round(),
        },
      );
    }
    if (cities.isEmpty) throw const FormatException('fuel prices: no cities');
    return FuelPriceTable(cities: cities, fetchedAt: now);
  }

  static String? _typeOf(String productName) {
    final n = productName.toUpperCase();
    if (n.contains('LPG') || n.contains('OTOGAZ')) return FuelTypes.lpg;
    if (n.contains('DIESEL') || n.contains('MOTORIN')) return FuelTypes.diesel;
    if (n.contains('KURSUN') || n.contains('BENZIN') || n.contains('POWER')) {
      return FuelTypes.gasoline;
    }
    return null;
  }
}

/// Plaka koduna göre il adları (servis adları Türkçe karaktersiz gelir).
abstract class TurkishProvinces {
  static const List<String> names = [
    'Adana', 'Adıyaman', 'Afyonkarahisar', 'Ağrı', 'Amasya', 'Ankara', //
    'Antalya', 'Artvin', 'Aydın', 'Balıkesir', 'Bilecik', 'Bingöl', //
    'Bitlis', 'Bolu', 'Burdur', 'Bursa', 'Çanakkale', 'Çankırı', 'Çorum', //
    'Denizli', 'Diyarbakır', 'Edirne', 'Elazığ', 'Erzincan', 'Erzurum', //
    'Eskişehir', 'Gaziantep', 'Giresun', 'Gümüşhane', 'Hakkâri', 'Hatay', //
    'Isparta', 'Mersin', 'İstanbul', 'İzmir', 'Kars', 'Kastamonu', //
    'Kayseri', 'Kırklareli', 'Kırşehir', 'Kocaeli', 'Konya', 'Kütahya', //
    'Malatya', 'Manisa', 'Kahramanmaraş', 'Mardin', 'Muğla', 'Muş', //
    'Nevşehir', 'Niğde', 'Ordu', 'Rize', 'Sakarya', 'Samsun', 'Siirt', //
    'Sinop', 'Sivas', 'Tekirdağ', 'Tokat', 'Trabzon', 'Tunceli', //
    'Şanlıurfa', 'Uşak', 'Van', 'Yozgat', 'Zonguldak', 'Aksaray', //
    'Bayburt', 'Karaman', 'Kırıkkale', 'Batman', 'Şırnak', 'Bartın', //
    'Ardahan', 'Iğdır', 'Yalova', 'Karabük', 'Kilis', 'Osmaniye', 'Düzce',
  ];

  /// "34" → "İstanbul"
  static String? nameOf(String code) {
    final n = int.tryParse(code);
    return n == null || n < 1 || n > names.length ? null : names[n - 1];
  }
}
