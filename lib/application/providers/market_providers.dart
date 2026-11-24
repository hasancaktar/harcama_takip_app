import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/stream_utils.dart';
import '../../domain/entities/market_rates.dart';
import 'repository_providers.dart';
import 'settings_providers.dart';

/// Piyasa verilerinin yenilenme aralığı.
const marketRatesRefreshInterval = Duration(minutes: 3);

/// Dolar, euro, ons altın ve bitcoin: ilk izlemede hemen, sonra 3 dakikada bir
/// çekilir. Hatalar gösterilmez; son başarılı veri korunur (hiç yoksa `null`).
/// Yalnızca gösterim açıkken izlenir (Özet ekranı).
final marketRatesProvider = StreamProvider.autoDispose<MarketRates?>((ref) {
  final client = ref.watch(marketRatesClientProvider);
  final poll = pollLatest(client.fetch, marketRatesRefreshInterval);
  ref.onDispose(poll.cancel);
  return poll.stream;
});

/// Özet ekranında piyasa verileri gösterilsin mi? Cihazda saklanır; varsayılan açık.
class ShowMarketRatesController extends Notifier<bool> {
  static const _key = 'show_market_rates';

  @override
  bool build() => ref.watch(sharedPreferencesProvider)?.getBool(_key) ?? true;

  Future<void> set(bool value) async {
    state = value;
    await ref.read(sharedPreferencesProvider)?.setBool(_key, value);
  }
}

final showMarketRatesProvider =
    NotifierProvider<ShowMarketRatesController, bool>(
      ShowMarketRatesController.new,
    );
