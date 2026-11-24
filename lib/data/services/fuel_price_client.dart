import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/entities/fuel_prices.dart';

/// Güncel pompa fiyatlarını getirir.
abstract class IFuelPriceClient {
  Future<FuelPriceTable> fetch();
}

/// Shell Türkiye'nin herkese açık pompa fiyatı servisi.
class ShellFuelPriceClient implements IFuelPriceClient {
  static final Uri endpoint = Uri.parse(
    'https://pompafiyat.turkiyeshell.com/api/Public/prices',
  );

  final http.Client _client;

  ShellFuelPriceClient({http.Client? client})
    : _client = client ?? http.Client();

  @override
  Future<FuelPriceTable> fetch() async {
    final res = await _client
        .get(endpoint, headers: const {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw http.ClientException('HTTP ${res.statusCode}', endpoint);
    }
    return FuelPriceTable.parseShell(
      jsonDecode(utf8.decode(res.bodyBytes)),
      now: DateTime.now(),
    );
  }
}
