import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/expense.dart';
import '../../domain/entities/vehicle.dart';
import '../services/fuel_stats.dart';
import 'auth_providers.dart';
import 'repository_providers.dart';

/// Kullanıcının araçları.
final vehiclesProvider = StreamProvider<List<Vehicle>>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(vehicleRepositoryProvider).watchVehicles(uid);
});

/// Kullanıcının kendi akaryakıt harcamaları (çalışma alanından bağımsız; araçlar
/// kişiseldir).
final fuelExpensesProvider = StreamProvider<List<Expense>>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(expenseRepositoryProvider).watchOwnFuelExpenses(uid);
});

final fuelRangeProvider = StateProvider<FuelRange>(
  (ref) => FuelRange.last12Months,
);

/// Özette seçili araç (`null`: tüm araçlar).
final fuelVehicleFilterProvider = StateProvider<String?>((ref) => null);

/// Özet ekranında "şimdi"; testlerde sabitlenebilir.
final fuelClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final fuelStatsProvider = Provider<FuelStats>((ref) {
  final expenses = ref.watch(fuelExpensesProvider).valueOrNull ?? const [];
  return FuelStats.compute(
    expenses: expenses,
    range: ref.watch(fuelRangeProvider),
    vehicleKey: ref.watch(fuelVehicleFilterProvider),
    now: ref.watch(fuelClockProvider)(),
  );
});

/// Özetteki araç seçenekleri: kayıtlı araçlar ve kayıtlarda geçen (silinmiş)
/// araçlar. Değer: görünen ad (`null`: araçsız kayıtlar).
final fuelVehicleOptionsProvider = Provider<Map<String, String?>>((ref) {
  final vehicles = ref.watch(vehiclesProvider).valueOrNull ?? const [];
  final expenses = ref.watch(fuelExpensesProvider).valueOrNull ?? const [];
  final options = <String, String?>{for (final v in vehicles) v.id: v.name};
  for (final e in expenses) {
    final key = FuelVehicleKey.of(e);
    options.putIfAbsent(
      key,
      () => key == FuelVehicleKey.none ? null : e.fuel?.vehicleName,
    );
  }
  return options;
});
