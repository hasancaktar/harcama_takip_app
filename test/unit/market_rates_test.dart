import 'package:flutter_test/flutter_test.dart';
import 'package:harcama_takip/domain/entities/market_rates.dart';
import 'package:harcama_takip/presentation/widgets/market_strip.dart';

void main() {
  final now = DateTime(2026, 11, 25, 9, 42);

  test(
    'genelpara yanıtı çözülür; sıralama sabittir, bilinmeyenler atlanır',
    () {
      final rates = MarketRates.parseGenelPara({
        'success': true,
        'data': {
          'BTC': {
            'alis': '59824.33',
            'satis': '59824.33',
            'degisim': '+0.05',
            'kur': 'USD',
          },
          'USD': {
            'alis': '50.6126',
            'satis': '50.6313',
            'degisim': '+0.01',
            'kur': 'TRY',
          },
          'EUR': {
            'alis': '55.5881',
            'satis': '55.6381',
            'degisim': '-0.12',
            'kur': 'TRY',
          },
          'XAUUSD': {
            'alis': '3554.81',
            'satis': '3555.30',
            'degisim': '+0.06',
            'kur': 'USD',
          },
          'GBP': {'satis': '66.1', 'kur': 'TRY'},
          'ETH': 'bozuk',
        },
      }, now: now);
      expect(rates.ordered.map((q) => q.symbol), [
        'USD',
        'EUR',
        'XAUUSD',
        'BTC',
      ]);
      final eur = rates.quotes['EUR']!;
      expect(eur.price, 55.6381);
      expect(eur.changePercent, -0.12);
      expect(eur.currency, 'TRY');
      expect(rates.quotes['BTC']!.currency, 'USD');
      expect(rates.fetchedAt, now);
    },
  );

  test('başarısız veya boş yanıt hata verir (sessizce yok sayılır)', () {
    expect(
      () => MarketRates.parseGenelPara({'success': false}, now: now),
      throwsFormatException,
    );
    expect(
      () => MarketRates.parseGenelPara({'success': true, 'data': {}}, now: now),
      throwsFormatException,
    );
    expect(
      () => MarketRates.parseGenelPara('limit', now: now),
      throwsFormatException,
    );
  });

  test('fiyat ve değişim Türkçe biçimde yazılır', () {
    MarketQuote q(String s, double p, String c) =>
        MarketQuote(symbol: s, price: p, changePercent: 0, currency: c);
    expect(MarketStrip.formatPrice(q('USD', 50.6313, 'TRY')), '₺50,63');
    expect(MarketStrip.formatPrice(q('XAUUSD', 3555.3, 'USD')), r'$3.555,30');
    expect(MarketStrip.formatPrice(q('BTC', 59824.33, 'USD')), r'$59.824');
    expect(MarketStrip.formatChange(-0.12), '%0,12');
  });
}
