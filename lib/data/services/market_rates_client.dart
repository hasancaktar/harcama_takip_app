import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/entities/market_rates.dart';

/// Güncel döviz, altın ve kripto verilerini getirir.
abstract class IMarketRatesClient {
  Future<MarketRates> fetch();
}

/// genelpara.com açık servisi. Dört veri tek istekte alınır (servis istek
/// sayısını sınırlar).
class GenelParaMarketRatesClient implements IMarketRatesClient {
  static final Uri endpoint = Uri.parse(
    'https://api.genelpara.com/json/'
    '?list=doviz,altin,kripto&sembol=USD,EUR,XAUUSD,BTC',
  );

  final http.Client _client;

  GenelParaMarketRatesClient({http.Client? client})
    : _client = client ?? http.Client();

  @override
  Future<MarketRates> fetch() async {
    final res = await _client
        .get(endpoint, headers: const {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw http.ClientException('HTTP ${res.statusCode}', endpoint);
    }
    return MarketRates.parseGenelPara(
      jsonDecode(utf8.decode(res.bodyBytes)),
      now: DateTime.now(),
    );
  }
}
