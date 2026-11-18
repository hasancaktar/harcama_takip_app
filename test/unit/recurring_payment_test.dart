import 'package:flutter_test/flutter_test.dart';
import 'package:harcama_takip/application/services/recurring_payment_service.dart';
import 'package:harcama_takip/domain/entities/expense.dart';
import 'package:harcama_takip/domain/entities/recurring_payment.dart';

import '../helpers/fakes.dart';

RecurringPayment _payment({
  int day = 15,
  DateTime? start,
  String? lastPosted,
  String? cardId,
  int? cutoff,
  String status = 'active',
}) {
  final s = start ?? DateTime(2026, 9, day, 9, 30);
  return RecurringPayment(
    id: 'r1',
    ownerUid: 'u1',
    visibility: 'personal',
    title: 'Elektrik',
    amountInCents: 85000,
    category: 'bills',
    cardId: cardId,
    cardLast4: cardId != null ? '4821' : null,
    cardCutoffDay: cutoff,
    dayOfMonth: day,
    startDate: s,
    lastPostedMonth: lastPosted,
    status: status,
    createdAt: s,
    updatedAt: s,
  );
}

void main() {
  group('RecurringPayment', () {
    test('kısa aylarda ayın son günü kullanılır, saat korunur', () {
      final p = _payment(day: 31, start: DateTime(2026, 1, 31, 8, 15));
      expect(p.occurrenceDate('2026-02'), DateTime(2026, 2, 28, 8, 15));
      expect(p.occurrenceDate('2026-04'), DateTime(2026, 4, 30, 8, 15));
      expect(p.occurrenceDate('2026-05'), DateTime(2026, 5, 31, 8, 15));
    });

    test('bu aya kadarki eksik aylar yazılır, gelecek aylar yazılmaz', () {
      final now = DateTime(2026, 11, 3);
      expect(_payment().dueMonths(now), ['2026-09', '2026-10', '2026-11']);
      expect(_payment(lastPosted: '2026-10').dueMonths(now), ['2026-11']);
      expect(_payment(lastPosted: '2026-11').dueMonths(now), isEmpty);
      expect(_payment(status: 'cancelled').dueMonths(now), isEmpty);
    });

    test('tarihi gelmemiş yazılmış aylar ve sıradaki ödeme', () {
      final p = _payment(lastPosted: '2026-11');
      expect(p.postedMonthsAfter(DateTime(2026, 11, 3)), ['2026-11']);
      expect(p.postedMonthsAfter(DateTime(2026, 11, 20)), isEmpty);
      expect(
        p.nextOccurrenceAfter(DateTime(2026, 11, 20)),
        DateTime(2026, 12, 15, 9, 30),
      );
    });

    test('Firestore haritasına yazılıp geri okunur', () {
      final p = _payment(lastPosted: '2026-10', cardId: 'c1', cutoff: 24);
      final back = RecurringPayment.fromMap(p.toMap());
      expect(back.toMap(), p.toMap());
    });
  });

  group('RecurringPaymentService', () {
    late FakeExpenseRepository expenses;
    late FakeRecurringPaymentRepository repo;
    late RecurringPaymentService service;

    setUp(() {
      expenses = FakeExpenseRepository();
      repo = FakeRecurringPaymentRepository(expenses);
      service = RecurringPaymentService(repo);
    });

    List<Expense> active() =>
        expenses.all.where((e) => e.status == 'active').toList()
          ..sort((a, b) => a.date.compareTo(b.date));

    test(
      'oluşturunca başlangıçtan bu aya kadar her ay bir kayıt yazılır',
      () async {
        await service.create(
          _payment(),
          actorUid: 'u1',
          now: DateTime(2026, 11, 3),
        );
        expect(active().map((e) => e.id), [
          'r1_2026-09',
          'r1_2026-10',
          'r1_2026-11',
        ]);
        final e = active().first;
        expect(e.recurringPaymentId, 'r1');
        expect(e.paymentMethod, 'auto_payment');
        expect(e.statementPeriod, '2026-09');
        expect(e.amountInCents, 85000);
        expect(repo.payments.value.single.lastPostedMonth, '2026-11');
      },
    );

    test(
      'karttan ödenen kayıt kredi kartı ekstresine (kesim gününe göre) yazılır',
      () async {
        await service.create(
          _payment(day: 28, cardId: 'c1', cutoff: 24),
          actorUid: 'u1',
          now: DateTime(2026, 9, 30),
        );
        final e = active().single;
        expect(e.paymentMethod, 'credit_card');
        expect(e.cardId, 'c1');
        expect(e.statementPeriod, '2026-10');
      },
    );

    test('eşitleme yalnızca eksik ayları yazar ve tekrar yazmaz', () async {
      await service.create(
        _payment(),
        actorUid: 'u1',
        now: DateTime(2026, 9, 20),
      );
      // Kullanıcı eylül kaydını elle değiştirdi; eşitleme ona dokunmamalı.
      await expenses.updateExpense(
        active().single.copyWith(amountInCents: 91000),
      );

      expect(await service.syncOwn('u1', now: DateTime(2026, 11, 2)), 2);
      expect(await service.syncOwn('u1', now: DateTime(2026, 11, 2)), 0);
      expect(active().map((e) => e.amountInCents), [91000, 85000, 85000]);
    });

    test(
      'sonlandırınca geçmiş kayıtlar kalır, tarihi gelmemiş kayıt silinir',
      () async {
        await service.create(
          _payment(),
          actorUid: 'u1',
          now: DateTime(2026, 11, 3),
        );
        final payment = repo.payments.value.single;
        await service.cancel(
          payment,
          actorUid: 'u1',
          now: DateTime(2026, 11, 3),
        );

        expect(active().map((e) => e.id), ['r1_2026-09', 'r1_2026-10']);
        final cancelled = repo.payments.value.single;
        expect(cancelled.status, 'cancelled');
        expect(cancelled.endDate, DateTime(2026, 11, 3));
        expect(await service.syncOwn('u1', now: DateTime(2027, 2, 1)), 0);
      },
    );

    test(
      'düzenleme gelecek aylara ve tarihi gelmemiş bu ay kaydına uygulanır',
      () async {
        await service.create(
          _payment(),
          actorUid: 'u1',
          now: DateTime(2026, 11, 3),
        );
        final before = repo.payments.value.single;
        await service.update(
          before,
          before.copyWith(amountInCents: 99000, dayOfMonth: 20),
          actorUid: 'u1',
          now: DateTime(2026, 11, 3),
        );
        expect(active().map((e) => e.amountInCents), [85000, 85000, 99000]);
        expect(active().last.date, DateTime(2026, 11, 20, 9, 30));

        await service.syncOwn('u1', now: DateTime(2026, 12, 1));
        expect(active().last.id, 'r1_2026-12');
        expect(active().last.amountInCents, 99000);
      },
    );
  });
}
