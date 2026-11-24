import 'package:flutter_test/flutter_test.dart';
import 'package:harcama_takip/domain/entities/fuel.dart';
import 'package:harcama_takip/domain/entities/fuel_prices.dart';

/// Shell servisinin yanıtından kısaltılmış örnek (ürün kodları sondaki
/// boşluklarla gelir).
Map<String, dynamic> shellSample() => {
  'products': [
    {
      'fepProductCode': '37  ',
      'fepProductName': 'KURSUZ 97',
      'genProductName': 'V-Power',
    },
    {
      'fepProductCode': '34  ',
      'fepProductName': 'VP DIESEL',
      'genProductName': 'VP Diesel',
    },
    {
      'fepProductCode': '5   ',
      'fepProductName': 'LPG',
      'genProductName': 'LPG',
    },
    {
      'fepProductCode': '99  ',
      'fepProductName': 'ADBLUE',
      'genProductName': 'AdBlue',
    },
  ],
  'groups': [
    {
      'cityCode': '034',
      'cityName': 'ISTANBUL',
      'counties': [
        {
          'countyCode': '034001',
          'prices': {'34  ': 88.9, '37  ': 68.4, '5   ': 51.56, '99  ': 20.0},
        },
        {
          'countyCode': '034002',
          'prices': {'34  ': 89.0, '37  ': 68.5},
        },
        {
          'countyCode': '034003',
          'prices': {'34  ': 89.1, '37  ': 68.6, '5   ': 'yok'},
        },
      ],
    },
    {
      'cityCode': '046',
      'cityName': 'K.MARAS',
      'counties': [
        {
          'countyCode': '046001',
          'prices': {'37  ': 70.2},
        },
      ],
    },
    {'cityCode': 'x', 'cityName': 'BOZUK', 'counties': []},
    {'cityCode': '006', 'cityName': 'ANKARA', 'counties': []},
  ],
};

void main() {
  final now = DateTime(2026, 11, 25, 9, 30);

  test(
    'il fiyatı ilçe fiyatlarının ortalamasıdır; ürünler yakıt türüne eşlenir',
    () {
      final table = FuelPriceTable.parseShell(shellSample(), now: now);
      expect(table.cities.keys, unorderedEquals(['34', '46']));
      final istanbul = table.city('34')!;
      expect(istanbul.name, 'İstanbul');
      expect(istanbul.priceOf(FuelTypes.gasoline), 6850);
      expect(istanbul.priceOf(FuelTypes.diesel), 8900);
      // LPG yalnızca bir ilçede geçerli fiyatla var.
      expect(istanbul.priceOf(FuelTypes.lpg), 5156);
      expect(table.city('46')!.name, 'Kahramanmaraş');
      expect(table.priceOf('46', FuelTypes.diesel), isNull);
      expect(table.priceOf(null, FuelTypes.gasoline), isNull);
      expect(table.fetchedAt, now);
    },
  );

  test('beklenmeyen yanıt hata verir (sessizce yok sayılır)', () {
    expect(
      () => FuelPriceTable.parseShell('html', now: now),
      throwsFormatException,
    );
    expect(
      () => FuelPriceTable.parseShell({'products': [], 'groups': []}, now: now),
      throwsFormatException,
    );
  });

  test('81 il plaka sırasıyla adlandırılır', () {
    expect(TurkishProvinces.names, hasLength(81));
    expect(TurkishProvinces.nameOf('1'), 'Adana');
    expect(TurkishProvinces.nameOf('34'), 'İstanbul');
    expect(TurkishProvinces.nameOf('81'), 'Düzce');
    expect(TurkishProvinces.nameOf('82'), isNull);
    expect(TurkishProvinces.nameOf('0'), isNull);
  });
}
