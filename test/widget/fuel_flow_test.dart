import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:harcama_takip/application/providers/fuel_providers.dart';
import 'package:harcama_takip/core/constants/app_constants.dart';
import 'package:harcama_takip/core/firebase/firebase_initialization.dart';
import 'package:harcama_takip/domain/entities/app_user.dart';
import 'package:harcama_takip/domain/entities/expense.dart';
import 'package:harcama_takip/domain/entities/fuel.dart';
import 'package:harcama_takip/domain/entities/vehicle.dart';
import 'package:harcama_takip/main.dart';
import 'package:harcama_takip/presentation/navigation/app_router.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../helpers/fakes.dart';

const _uid = 'u-ayse';

class _Backend extends TestBackend {
  final _auth = FakeAuthRepository(
    initialUser: const AppUser(
      uid: _uid,
      email: 'ayse@example.com',
      displayName: 'Ayşe Yılmaz',
      emailVerified: true,
    ),
  );

  @override
  FakeAuthRepository get auth => _auth;
}

final _created = DateTime(2026, 1, 1);

Vehicle _vehicle(String id, String name, {String type = FuelTypes.gasoline}) =>
    Vehicle(
      id: id,
      ownerUid: _uid,
      name: name,
      brand: 'Fiat',
      fuelType: type,
      odometerKm: 85000,
      createdAt: _created,
      updatedAt: _created,
    );

int _seq = 0;
Expense _fill(
  DateTime date, {
  required int litersX100,
  required int price,
  int? km,
  bool full = true,
}) => Expense(
  id: 'prev-${_seq++}',
  ownerUid: _uid,
  visibility: 'personal',
  title: 'Akaryakıt',
  amountInCents: FuelMath.amountCents(litersX100, price),
  category: AppConstants.fuelCategoryId,
  date: date,
  paymentMethod: 'cash',
  statementPeriod: '${date.year}-${date.month.toString().padLeft(2, '0')}',
  fuel: FuelDetails(
    fuelType: FuelTypes.gasoline,
    litersX100: litersX100,
    pricePerLiterCents: price,
    vehicleId: 'v1',
    vehicleName: 'Egea Cross',
    odometerKm: km,
    fullTank: full,
  ),
  createdBy: _uid,
  createdAt: date,
  updatedAt: date,
);

Future<void> _settle(WidgetTester tester, {int frames = 12}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await _settle(tester, frames: 3);
  await tester.tap(finder);
  await _settle(tester);
}

Future<GoRouter> _pump(
  WidgetTester tester,
  TestBackend backend, {
  DateTime? now,
}) async {
  tester.view.physicalSize = const Size(420, 1100);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...backend.overrides,
        if (now != null) fuelClockProvider.overrideWithValue(() => now),
      ],
      child: const ExpenseTrackerApp(
        initResult: FirebaseInitResult(isSuccess: true),
      ),
    ),
  );
  await _settle(tester);
  return ProviderScope.containerOf(
    tester.element(find.byType(ExpenseTrackerApp)),
  ).read(appRouterProvider);
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 1));
}

TextEditingController _controller(WidgetTester tester, String key) =>
    tester.widget<TextFormField>(find.byKey(ValueKey(key))).controller!;

Finder get _amountField => find.byType(TextFormField).first;

void main() {
  setUpAll(() => initializeDateFormatting('tr_TR'));

  testWidgets(
    'tutar girilince litre son fiyattan hesaplanır ve yakıt bilgileriyle kaydedilir',
    (tester) async {
      final backend = _Backend();
      backend.vehicles.seed([_vehicle('v1', 'Egea Cross')]);
      backend.expenses.seed([
        _fill(DateTime(2026, 11, 1), litersX100: 3000, price: 6669, km: 85150),
      ]);
      final router = await _pump(tester, backend);
      router.go('/expenses/new?category=fuel');
      await _settle(tester);

      expect(find.text('Yakıt bilgileri'), findsOneWidget);
      expect(find.text('Egea Cross'), findsOneWidget);
      expect(_controller(tester, 'fuel-price').text, '66,69');
      expect(find.text('Son kayıt: 85.150 km'), findsOneWidget);
      // Akaryakıtta taksit ve otomatik ödeme seçenekleri yoktur.
      expect(find.text('Otomatik Ödeme'), findsNothing);
      expect(find.text('Taksit sayısı'), findsNothing);

      await tester.enterText(_amountField, '1000');
      await _settle(tester, frames: 3);
      expect(_controller(tester, 'fuel-liters').text, '14,99');
      expect(find.text('Otomatik hesaplandı'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('fuel-odometer')),
        '85600',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await _settle(tester, frames: 3);
      await _tap(tester, find.text('Nakit'));
      await _tap(tester, find.text('Harcamayı kaydet'));

      final saved = backend.expenses.all.singleWhere(
        (e) => !e.id.startsWith('prev-'),
      );
      expect(saved.category, AppConstants.fuelCategoryId);
      expect(saved.title, 'Akaryakıt');
      expect(saved.amountInCents, 100000);
      expect(saved.paymentMethod, 'cash');
      expect(
        saved.fuel,
        const FuelDetails(
          fuelType: FuelTypes.gasoline,
          litersX100: 1499,
          pricePerLiterCents: 6669,
          vehicleId: 'v1',
          vehicleName: 'Egea Cross',
          odometerKm: 85600,
          fullTank: true,
        ),
      );
      await _unmount(tester);
    },
  );

  testWidgets(
    'litre girilince tutar, tutar ve litre girilince fiyat hesaplanır; formdan araç eklenir',
    (tester) async {
      final backend = _Backend();
      final router = await _pump(tester, backend);
      router.go('/expenses/new?category=fuel');
      await _settle(tester);

      expect(_controller(tester, 'fuel-price').text, isEmpty);
      await tester.enterText(find.byKey(const ValueKey('fuel-liters')), '40');
      await tester.enterText(_amountField, '2668');
      await _settle(tester, frames: 3);
      // Fiyat bilinmiyordu: tutar ÷ litre
      expect(_controller(tester, 'fuel-price').text, '66,70');

      // Fiyat değişince en eski girilen alan (litre) yeniden hesaplanır.
      await tester.enterText(find.byKey(const ValueKey('fuel-price')), '70');
      await _settle(tester, frames: 3);
      expect(_controller(tester, 'fuel-liters').text, '38,11');
      expect(
        tester.widget<TextFormField>(_amountField).controller!.text,
        '2.668',
      );

      // Litre fiyatı ve tutar varken litre değişince tutar hesaplanır.
      await tester.enterText(find.byKey(const ValueKey('fuel-liters')), '50');
      await _settle(tester, frames: 3);
      expect(
        tester.widget<TextFormField>(_amountField).controller!.text,
        '3.500',
      );

      // Araç yokken formdan eklenir ve seçilir; yakıt türü araçtan gelir.
      FocusManager.instance.primaryFocus?.unfocus();
      await _settle(tester, frames: 3);
      await _tap(tester, find.widgetWithText(TextButton, 'Araç ekle'));
      await tester.enterText(
        find
            .descendant(
              of: find.byType(AlertDialog),
              matching: find.byType(TextFormField),
            )
            .first,
        'Clio',
      );
      await _tap(
        tester,
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Motorin'),
        ),
      );
      await _tap(tester, find.widgetWithText(FilledButton, 'Kaydet'));

      expect(backend.vehicles.all.single.name, 'Clio');
      expect(backend.vehicles.all.single.fuelType, FuelTypes.diesel);
      expect(find.text('Clio'), findsOneWidget);
      final diesel = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, 'Motorin'),
      );
      expect(diesel.selected, isTrue);
      // Kullanıcının yazdığı fiyat korunur.
      expect(_controller(tester, 'fuel-price').text, '70');
      await _unmount(tester);
    },
  );

  testWidgets(
    'Raporlar > Yakıt takibi: maliyet, hacim, fiyat ve 100 km tüketimi',
    (tester) async {
      final backend = _Backend();
      backend.vehicles.seed([_vehicle('v1', 'Egea Cross')]);
      backend.expenses.seed([
        _fill(DateTime(2026, 9, 1), litersX100: 4000, price: 6000, km: 10000),
        _fill(
          DateTime(2026, 9, 15),
          litersX100: 2000,
          price: 6200,
          km: 10300,
          full: false,
        ),
        _fill(DateTime(2026, 10, 1), litersX100: 2500, price: 6400, km: 10700),
        _fill(DateTime(2026, 11, 1), litersX100: 3000, price: 6600, km: 11200),
      ]);
      final router = await _pump(
        tester,
        backend,
        now: DateTime(2026, 11, 20, 18),
      );
      router.go('/reports');
      await _settle(tester);
      await _tap(tester, find.text('Yakıt takibi'));

      expect(
        find.text('4 dolum · 1 Eylül 2026 – 20 Kasım 2026'),
        findsOneWidget,
      );
      expect(find.text('₺7.220,00'), findsOneWidget);
      expect(find.text('115,00 L'), findsOneWidget);
      expect(find.text('₺62,78'), findsOneWidget);
      expect(find.text('6,25 L/100 km'), findsOneWidget);
      expect(find.text('₺4,02'), findsOneWidget); // km başına
      expect(find.text('Kısmi dolum'), findsOneWidget);

      await _tap(tester, find.widgetWithText(ChoiceChip, 'Bu ay'));
      expect(
        find.text('1 dolum · 1 Kasım 2026 – 20 Kasım 2026'),
        findsOneWidget,
      );
      expect(find.text('₺1.980,00'), findsWidgets);
      expect(find.text('6,00 L/100 km'), findsWidgets);
      await _unmount(tester);
    },
  );

  testWidgets('Araçlarım: araç eklenir ve silinir', (tester) async {
    final backend = _Backend();
    final router = await _pump(tester, backend);
    router.go('/fuel/vehicles');
    await _settle(tester);

    expect(find.text('Henüz araç eklemediniz'), findsOneWidget);
    await _tap(tester, find.widgetWithText(FilledButton, 'Araç ekle'));
    await tester.enterText(
      find
          .descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(TextFormField),
          )
          .first,
      'Egea Cross',
    );
    await _tap(tester, find.widgetWithText(FilledButton, 'Kaydet'));
    expect(backend.vehicles.all.single.name, 'Egea Cross');
    expect(find.text('Egea Cross'), findsOneWidget);
    expect(find.text('Benzin'), findsOneWidget);

    await _tap(tester, find.byTooltip('Araç işlemleri'));
    await _tap(tester, find.text('Sil').last);
    // Onay penceresi
    await _tap(tester, find.widgetWithText(FilledButton, 'Sil'));
    expect(backend.vehicles.all, isEmpty);
    await _unmount(tester);
  });
}
