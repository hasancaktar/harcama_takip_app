import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../core/l10n/app_locale.dart';
import '../../domain/entities/expense.dart';
import '../../domain/entities/fuel.dart';

/// Yakıt özetinin tarih aralığı.
enum FuelRange { thisMonth, last3Months, last12Months, all }

extension FuelRangeX on FuelRange {
  String get label => switch (this) {
    FuelRange.thisMonth => 'Bu ay'.tr,
    FuelRange.last3Months => 'Son 3 ay'.tr,
    FuelRange.last12Months => 'Son 12 ay'.tr,
    FuelRange.all => 'Tümü'.tr,
  };

  /// Aralığın başlangıcı (dahil). "Tümü" için `null`.
  DateTime? startFor(DateTime now) => switch (this) {
    FuelRange.thisMonth => DateTime(now.year, now.month),
    FuelRange.last3Months => DateTime(now.year, now.month - 2),
    FuelRange.last12Months => DateTime(now.year, now.month - 11),
    FuelRange.all => null,
  };
}

/// Yakıt kayıtlarını araca göre gruplamak için anahtar. Araçsız kayıtlar tek grupta toplanır.
abstract class FuelVehicleKey {
  static const String none = '__none__';
  static String of(Expense e) => e.fuel?.vehicleId ?? none;
}

/// İki "depo full" dolum arasındaki yol: tüketim bu aralıktan hesaplanır.
@immutable
class FuelSegment {
  final int distanceKm;
  final int litersX100;
  final int costCents;
  final DateTime endDate;

  const FuelSegment({
    required this.distanceKm,
    required this.litersX100,
    required this.costCents,
    required this.endDate,
  });

  /// L/100 km
  double get consumption => litersX100 / distanceKm;
}

/// Yakıt özeti (maliyet, hacim, ortalama fiyat, tüketim). Saf hesaplama; birim testi vardır.
@immutable
class FuelStats {
  /// Aralıktaki kayıtlar, en yeni önce.
  final List<Expense> entries;
  final DateTime? spanStart;
  final DateTime? spanEnd;

  /// Günlük ortalamaların bölündüğü gün sayısı.
  final int days;
  final int totalCostCents;

  /// Litre bilgisi olan kayıtların toplamları.
  final int litersX100;
  final int volumeCostCents;
  final int volumeCount;
  final int? minPriceCents;
  final int? maxPriceCents;
  final List<FuelSegment> segments;

  const FuelStats({
    required this.entries,
    required this.spanStart,
    required this.spanEnd,
    required this.days,
    required this.totalCostCents,
    required this.litersX100,
    required this.volumeCostCents,
    required this.volumeCount,
    required this.minPriceCents,
    required this.maxPriceCents,
    required this.segments,
  });

  static const empty = FuelStats(
    entries: [],
    spanStart: null,
    spanEnd: null,
    days: 0,
    totalCostCents: 0,
    litersX100: 0,
    volumeCostCents: 0,
    volumeCount: 0,
    minPriceCents: null,
    maxPriceCents: null,
    segments: [],
  );

  int get fillCount => entries.length;
  bool get isEmpty => entries.isEmpty;

  int? get dailyCostCents =>
      isEmpty || days <= 0 ? null : (totalCostCents / days).round();

  int? get dailyLitersX100 =>
      volumeCount == 0 || days <= 0 ? null : (litersX100 / days).round();

  int? get averageLitersPerFillX100 =>
      volumeCount == 0 ? null : (litersX100 / volumeCount).round();

  int? get averagePriceCents => litersX100 <= 0
      ? null
      : FuelMath.pricePerLiterCents(volumeCostCents, litersX100);

  int get distanceKm => segments.fold(0, (sum, s) => sum + s.distanceKm);

  double? get averageConsumption {
    final distance = distanceKm;
    if (distance <= 0) return null;
    final liters = segments.fold(0, (sum, s) => sum + s.litersX100);
    return liters / distance;
  }

  double? get bestConsumption => segments.isEmpty
      ? null
      : segments.map((s) => s.consumption).reduce(math.min);

  double? get worstConsumption => segments.isEmpty
      ? null
      : segments.map((s) => s.consumption).reduce(math.max);

  /// Kilometre başına yakıt maliyeti (kuruş).
  int? get costPerKmCents {
    final distance = distanceKm;
    if (distance <= 0) return null;
    final cost = segments.fold(0, (sum, s) => sum + s.costCents);
    return (cost / distance).round();
  }

  /// [expenses]: kullanıcının akaryakıt harcamaları. [vehicleKey] verilirse
  /// yalnızca o aracın kayıtları ([FuelVehicleKey.none]: araçsız kayıtlar).
  static FuelStats compute({
    required Iterable<Expense> expenses,
    required FuelRange range,
    required DateTime now,
    String? vehicleKey,
  }) {
    final scoped = vehicleKey == null
        ? expenses.toList()
        : expenses.where((e) => FuelVehicleKey.of(e) == vehicleKey).toList();
    if (scoped.isEmpty) return empty;

    final start = range.startFor(now);
    bool inRange(DateTime d) => start == null || !d.isBefore(start);

    final entries = scoped.where((e) => inRange(e.date)).toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    var total = 0;
    var liters = 0;
    var volumeCost = 0;
    var volumeCount = 0;
    int? minPrice;
    int? maxPrice;
    for (final e in entries) {
      total += e.amountInCents;
      final f = e.fuel;
      if (f == null || !f.hasVolume) continue;
      liters += f.litersX100;
      volumeCost += e.amountInCents;
      volumeCount++;
      minPrice = minPrice == null
          ? f.pricePerLiterCents
          : math.min(minPrice, f.pricePerLiterCents);
      maxPrice = maxPrice == null
          ? f.pricePerLiterCents
          : math.max(maxPrice, f.pricePerLiterCents);
    }

    // Günlük ortalama: aralığın başı veya ilk kayıt (hangisi sonraysa) → bugün.
    DateTime dayOf(DateTime d) => DateTime.utc(d.year, d.month, d.day);
    final first = scoped
        .map((e) => e.date)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    final spanStart = dayOf(
      start == null || first.isAfter(start) ? first : start,
    );
    var spanEnd = dayOf(now);
    if (entries.isNotEmpty && dayOf(entries.first.date).isAfter(spanEnd)) {
      spanEnd = dayOf(entries.first.date);
    }
    final days = entries.isEmpty
        ? 0
        : math.max(1, spanEnd.difference(spanStart).inDays + 1);

    // Tüketim: her araç için iki "depo full" (kilometreli) dolum arasındaki yol.
    final segments = <FuelSegment>[];
    final byVehicle = <String, List<Expense>>{};
    for (final e in scoped) {
      byVehicle.putIfAbsent(FuelVehicleKey.of(e), () => []).add(e);
    }
    for (final list in byVehicle.values) {
      list.sort((a, b) {
        final byDate = a.date.compareTo(b.date);
        if (byDate != 0) return byDate;
        return (a.fuel?.odometerKm ?? 0).compareTo(b.fuel?.odometerKm ?? 0);
      });
      int? anchorKm;
      var accLiters = 0;
      var accCost = 0;
      var broken = false;
      for (final e in list) {
        final f = e.fuel;
        if (f == null || !f.hasVolume) {
          // Litresi bilinmeyen dolum bu aralığın hesabını bozar.
          broken = true;
          continue;
        }
        accLiters += f.litersX100;
        accCost += e.amountInCents;
        if (!f.fullTank) continue;
        final km = f.odometerKm;
        if (km != null &&
            anchorKm != null &&
            !broken &&
            km > anchorKm &&
            inRange(e.date)) {
          segments.add(
            FuelSegment(
              distanceKm: km - anchorKm,
              litersX100: accLiters,
              costCents: accCost,
              endDate: e.date,
            ),
          );
        }
        anchorKm = km;
        accLiters = 0;
        accCost = 0;
        broken = false;
      }
    }

    return FuelStats(
      entries: entries,
      spanStart: entries.isEmpty ? null : spanStart,
      spanEnd: entries.isEmpty ? null : spanEnd,
      days: days,
      totalCostCents: total,
      litersX100: liters,
      volumeCostCents: volumeCost,
      volumeCount: volumeCount,
      minPriceCents: minPrice,
      maxPriceCents: maxPrice,
      segments: segments,
    );
  }
}
