import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/stream_utils.dart';
import '../../domain/entities/expense.dart';
import '../../domain/entities/fuel_prices.dart';
import '../../domain/entities/vehicle.dart';
import '../services/fuel_stats.dart';
import 'auth_providers.dart';
import 'repository_providers.dart';
import 'settings_providers.dart';

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

/// Pompa fiyatlarının yenilenme aralığı.
const fuelPriceRefreshInterval = Duration(minutes: 3);

/// Güncel pompa fiyatları: ilk izlemede hemen, sonra 3 dakikada bir çekilir.
/// Hatalar kullanıcıya gösterilmez; son başarılı tablo korunur (hiç yoksa `null`).
final fuelPricesProvider = StreamProvider<FuelPriceTable?>((ref) {
  final client = ref.watch(fuelPriceClientProvider);
  final poll = pollLatest(client.fetch, fuelPriceRefreshInterval);
  ref.onDispose(poll.cancel);
  return poll.stream;
});

/// Fiyatları izlenen il (plaka kodu). Cihazda saklanır; varsayılan İstanbul.
class FuelPriceCityController extends Notifier<String?> {
  static const _key = 'fuel_price_city';

  /// İstanbul
  static const defaultCity = '34';

  @override
  String? build() {
    final code = ref.watch(sharedPreferencesProvider)?.getString(_key);
    return code != null && TurkishProvinces.nameOf(code) != null
        ? code
        : defaultCity;
  }

  Future<void> set(String code) async {
    state = code;
    await ref.read(sharedPreferencesProvider)?.setString(_key, code);
  }
}

final fuelPriceCityProvider =
    NotifierProvider<FuelPriceCityController, String?>(
      FuelPriceCityController.new,
    );

/// Seçili ilin güncel fiyatları (yoksa `null`).
final selectedCityFuelPricesProvider = Provider<CityFuelPrices?>((ref) {
  final table = ref.watch(fuelPricesProvider).valueOrNull;
  return table?.city(ref.watch(fuelPriceCityProvider));
});
