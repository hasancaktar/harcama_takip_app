import 'package:flutter_test/flutter_test.dart';
import 'package:harcama_takip/application/services/fuel_stats.dart';
import 'package:harcama_takip/core/constants/app_constants.dart';
import 'package:harcama_takip/domain/entities/expense.dart';
import 'package:harcama_takip/domain/entities/fuel.dart';
import 'package:intl/date_symbol_data_local.dart';

int _seq = 0;

Expense fill(
  DateTime date, {
  required int litersX100,
  required int price,
  int? km,
  bool full = true,
  String? vehicle = 'v1',
  String type = FuelTypes.gasoline,
  int? amount,
  bool details = true,
}) {
  final cents = amount ?? FuelMath.amountCents(litersX100, price);
  return Expense(
    id: 'f${_seq++}',
    ownerUid: 'u',
    visibility: 'personal',
    title: 'Akaryakıt',
    amountInCents: cents,
    category: AppConstants.fuelCategoryId,
    date: date,
    paymentMethod: 'cash',
    statementPeriod: '${date.year}-${date.month.toString().padLeft(2, '0')}',
    fuel: details
        ? FuelDetails(
            fuelType: type,
            litersX100: litersX100,
            pricePerLiterCents: price,
            vehicleId: vehicle,
            vehicleName: vehicle == null ? null : 'Araç $vehicle',
            odometerKm: km,
            fullTank: full,
          )
        : null,
    createdBy: 'u',
    createdAt: date,
    updatedAt: date,
  );
}

/// 2 full dolum aralığı: 700 km'de 45 L, 500 km'de 30 L.
List<Expense> _history() => [
  fill(DateTime(2026, 9, 1), litersX100: 4000, price: 6000, km: 10000),
  fill(
    DateTime(2026, 9, 15),
    litersX100: 2000,
    price: 6200,
    km: 10300,
    full: false,
  ),
  fill(DateTime(2026, 10, 1), litersX100: 2500, price: 6400, km: 10700),
  fill(DateTime(2026, 11, 1), litersX100: 3000, price: 6600, km: 11200),
];

final _now = DateTime(2026, 11, 20, 18);

void main() {
  setUpAll(() => initializeDateFormatting('tr_TR'));

  group('FuelMath', () {
    test('tutar, litre ve litre fiyatı birbirinden hesaplanır', () {
      expect(FuelMath.amountCents(3658, 6669), 243952);
      expect(FuelMath.litersX100(100000, 6669), 1499);
      expect(FuelMath.pricePerLiterCents(266800, 4000), 6670);
      expect(FuelMath.litersX100(100000, 0), 0);
      expect(FuelMath.pricePerLiterCents(100000, 0), 0);
    });

    test('biçimler Türkçe sayı yazımını kullanır', () {
      expect(FuelMath.formatLiters(3658), '36,58 L');
      expect(FuelMath.formatLiters(102425), '1.024,25 L');
      expect(FuelMath.formatKm(85150), '85.150 km');
      expect(FuelMath.formatConsumption(6.74), '6,74 L/100 km');
    });
  });

  group('FuelDetails', () {
    test('harcama ile birlikte yazılıp okunur; tam sayı litre de okunur', () {
      final e = fill(
        DateTime(2026, 11, 2),
        litersX100: 3658,
        price: 6669,
        km: 85150,
        full: false,
      );
      final map = e.toMap();
      expect(map['fuel'], {
        'type': 'gasoline',
        'liters': 36.58,
        'pricePerLiterCents': 6669,
        'vehicleId': 'v1',
        'vehicleName': 'Araç v1',
        'odometerKm': 85150,
        'fullTank': false,
      });
      expect(Expense.fromMap(map).fuel, e.fuel);

      // Web'de 40.0 tam sayı olarak saklanır.
      final web = Map<String, dynamic>.from(map)
        ..['fuel'] = {...map['fuel'] as Map, 'liters': 40, 'type': 'x'};
      final parsed = Expense.fromMap(web).fuel!;
      expect(parsed.litersX100, 4000);
      expect(parsed.fuelType, FuelTypes.gasoline);
    });

    test('yakıt bilgisi olmayan harcamada alan boş kalır', () {
      final e = fill(
        DateTime(2026, 11, 2),
        litersX100: 0,
        price: 0,
        amount: 50000,
        details: false,
      );
      expect(e.toMap()['fuel'], isNull);
      expect(Expense.fromMap(e.toMap()).fuel, isNull);
    });
  });

  group('FuelHistory', () {
    test('türe göre son litre fiyatı ve araca göre en yüksek km bulunur', () {
      final entries = [
        ..._history(),
        fill(
          DateTime(2026, 11, 5),
          litersX100: 3000,
          price: 3100,
          type: FuelTypes.lpg,
          vehicle: 'v2',
          km: 500,
        ),
      ];
      expect(FuelHistory.lastPrice(entries, FuelTypes.gasoline), 6600);
      expect(FuelHistory.lastPrice(entries, FuelTypes.lpg), 3100);
      expect(FuelHistory.lastPrice(entries, FuelTypes.diesel), isNull);
      expect(FuelHistory.lastOdometer(entries, 'v1'), 11200);
      expect(FuelHistory.lastOdometer(entries, 'v2'), 500);
      expect(FuelHistory.last(entries)!.vehicleId, 'v2');
    });
  });

  group('FuelStats', () {
    test('tüm kayıtlar: maliyet, hacim, fiyat ve tüketim', () {
      final s = FuelStats.compute(
        expenses: _history(),
        range: FuelRange.all,
        now: _now,
      );
      expect(s.fillCount, 4);
      expect(s.totalCostCents, 722000);
      expect(s.litersX100, 11500);
      expect(s.averageLitersPerFillX100, 2875);
      expect(s.averagePriceCents, 6278);
      expect(s.minPriceCents, 6000);
      expect(s.maxPriceCents, 6600);
      // 1 Eylül – 20 Kasım: 81 gün
      expect(s.days, 81);
      expect(s.dailyCostCents, 8914);
      expect(s.distanceKm, 1200);
      expect(s.averageConsumption, closeTo(6.25, 1e-9));
      expect(s.bestConsumption, closeTo(6.0, 1e-9));
      expect(s.worstConsumption, closeTo(45 / 7, 1e-9));
      // (2.840 + 1.980) ₺ / 1.200 km
      expect(s.costPerKmCents, 402);
      expect(s.entries.first.date, DateTime(2026, 11, 1));
    });

    test('bu ay: yalnızca ay içindeki kayıt ve onunla biten tüketim', () {
      final s = FuelStats.compute(
        expenses: _history(),
        range: FuelRange.thisMonth,
        now: _now,
      );
      expect(s.fillCount, 1);
      expect(s.totalCostCents, 198000);
      expect(s.days, 20);
      expect(s.segments, hasLength(1));
      expect(s.averageConsumption, closeTo(6.0, 1e-9));
      expect(s.costPerKmCents, 396);
    });

    test('aralık ilk kayıttan önce başlıyorsa günler ilk kayıttan sayılır', () {
      final s = FuelStats.compute(
        expenses: _history(),
        range: FuelRange.last12Months,
        now: _now,
      );
      expect(s.days, 81);
      expect(s.spanStart, DateTime.utc(2026, 9, 1));
    });

    test(
      'araç filtresi diğer araçları ve araçsız kayıtları dışarıda bırakır',
      () {
        final entries = [
          ..._history(),
          fill(
            DateTime(2026, 11, 3),
            litersX100: 1000,
            price: 3100,
            vehicle: 'v2',
          ),
          fill(
            DateTime(2026, 11, 4),
            litersX100: 1000,
            price: 6500,
            vehicle: null,
          ),
        ];
        final v1 = FuelStats.compute(
          expenses: entries,
          range: FuelRange.all,
          now: _now,
          vehicleKey: 'v1',
        );
        expect(v1.fillCount, 4);
        final none = FuelStats.compute(
          expenses: entries,
          range: FuelRange.all,
          now: _now,
          vehicleKey: FuelVehicleKey.none,
        );
        expect(none.fillCount, 1);
        expect(none.totalCostCents, 65000);
        expect(none.averageConsumption, isNull);
      },
    );

    test(
      'litresi bilinmeyen dolum veya kilometresiz full dolum zinciri bozar',
      () {
        // Yakıt bilgisi olmayan (eski) kayıt araçsızdır; araçsız kayıtların
        // zincirini bozar, araçlı kayıtları etkilemez.
        Expense unknown() => fill(
          DateTime(2026, 9, 10),
          litersX100: 0,
          price: 0,
          amount: 50000,
          details: false,
        );
        final withUnknown = [
          for (final vehicle in [null, 'v1']) ...[
            fill(
              DateTime(2026, 9, 1),
              litersX100: 4000,
              price: 6000,
              km: 10000,
              vehicle: vehicle,
            ),
            fill(
              DateTime(2026, 10, 1),
              litersX100: 2500,
              price: 6400,
              km: 10700,
              vehicle: vehicle,
            ),
            fill(
              DateTime(2026, 11, 1),
              litersX100: 3000,
              price: 6600,
              km: 11200,
              vehicle: vehicle,
            ),
          ],
          unknown(),
        ];
        final none = FuelStats.compute(
          expenses: withUnknown,
          range: FuelRange.all,
          now: _now,
          vehicleKey: FuelVehicleKey.none,
        );
        // Bilinmeyen dolumlu ilk aralık sayılmaz, ikinci aralık sayılır.
        expect(none.segments, hasLength(1));
        expect(none.averageConsumption, closeTo(6.0, 1e-9));
        expect(none.totalCostCents, 240000 + 50000 + 160000 + 198000);
        expect(none.litersX100, 9500);
        expect(none.volumeCount, 3);

        final v1 = FuelStats.compute(
          expenses: withUnknown,
          range: FuelRange.all,
          now: _now,
          vehicleKey: 'v1',
        );
        expect(v1.segments, hasLength(2));

        final noKm = [
          fill(DateTime(2026, 9, 1), litersX100: 4000, price: 6000, km: 10000),
          fill(DateTime(2026, 10, 1), litersX100: 2500, price: 6400),
          fill(DateTime(2026, 11, 1), litersX100: 3000, price: 6600, km: 11200),
        ];
        final b = FuelStats.compute(
          expenses: noKm,
          range: FuelRange.all,
          now: _now,
        );
        expect(b.segments, isEmpty);
        expect(b.averageConsumption, isNull);
        expect(b.costPerKmCents, isNull);
      },
    );

    test('kayıt yoksa özet boştur', () {
      final s = FuelStats.compute(
        expenses: const [],
        range: FuelRange.all,
        now: _now,
      );
      expect(s.isEmpty, isTrue);
      expect(s.dailyCostCents, isNull);
      expect(s.averagePriceCents, isNull);
    });
  });

  group('Akaryakıt kategorisi', () {
    tearDown(() => CategoryRegistry.update(const []));

    test('varsayılan listede vardır', () {
      CategoryRegistry.update(const []);
      expect(
        AppConstants.categories.map((c) => c.id),
        contains(AppConstants.fuelCategoryId),
      );
    });

    test('yöneticinin listesinde olmasa da seçilebilir', () {
      CategoryRegistry.update(const [
        CategoryItem(id: 'market', nameTr: 'Market', order: 0),
        CategoryItem(id: 'other', nameTr: 'Diğer', order: 9),
      ]);
      expect(AppConstants.categories.map((c) => c.id), [
        'market',
        AppConstants.fuelCategoryId,
        'other',
      ]);
    });

    test('yönetici pasif yaparsa seçicide görünmez ama adı çözülür', () {
      CategoryRegistry.update(const [
        CategoryItem(id: 'market', nameTr: 'Market', order: 0),
        CategoryItem(
          id: AppConstants.fuelCategoryId,
          nameTr: 'Yakıt',
          isActive: false,
          order: 1,
        ),
      ]);
      expect(
        AppConstants.categories.map((c) => c.id),
        isNot(contains(AppConstants.fuelCategoryId)),
      );
      expect(
        AppConstants.getCategoryById(AppConstants.fuelCategoryId).nameTr,
        'Yakıt',
      );
    });
  });
}
