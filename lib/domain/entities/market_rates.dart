import 'package:flutter/foundation.dart';

/// Tek bir piyasa verisi (satış fiyatı ve günlük yüzde değişim).
@immutable
class MarketQuote {
  final String symbol;
  final double price;

  /// Günlük değişim (yüzde).
  final double changePercent;

  /// Fiyatın para birimi: 'TRY' veya 'USD'.
  final String currency;

  const MarketQuote({
    required this.symbol,
    required this.price,
    required this.changePercent,
    required this.currency,
  });
}

/// Dolar, euro, ons altın ve bitcoin.
@immutable
class MarketRates {
  /// Gösterim sırası.
  static const List<String> symbols = ['USD', 'EUR', 'XAUUSD', 'BTC'];

  final Map<String, MarketQuote> quotes;
  final DateTime fetchedAt;

  const MarketRates({required this.quotes, required this.fetchedAt});

  /// Gösterim sırasıyla mevcut veriler.
  List<MarketQuote> get ordered => [
    for (final s in symbols)
      if (quotes[s] != null) quotes[s]!,
  ];

  /// genelpara.com yanıtını çözer. Bozuk kayıtlar atlanır; hiç veri yoksa
  /// [FormatException] fırlatır.
  ///
  /// Yanıt: `{"success": true, "data": {"USD": {"satis": "50.63",
  /// "degisim": "+0.01", "kur": "TRY"}, ...}}` (sayılar metin olarak gelir).
  static MarketRates parseGenelPara(Object? json, {required DateTime now}) {
    if (json is! Map || json['success'] != true || json['data'] is! Map) {
      throw const FormatException('market rates');
    }
    final quotes = <String, MarketQuote>{};
    (json['data'] as Map).forEach((key, value) {
      if (key is! String || !symbols.contains(key) || value is! Map) return;
      final price = _number(value['satis']) ?? _number(value['alis']);
      if (price == null || price <= 0) return;
      quotes[key] = MarketQuote(
        symbol: key,
        price: price,
        changePercent: _number(value['degisim']) ?? 0,
        currency: value['kur'] == 'USD' ? 'USD' : 'TRY',
      );
    });
    if (quotes.isEmpty) throw const FormatException('market rates: empty');
    return MarketRates(quotes: quotes, fetchedAt: now);
  }

  static double? _number(Object? v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.replaceAll('+', '').trim());
    return null;
  }
}
