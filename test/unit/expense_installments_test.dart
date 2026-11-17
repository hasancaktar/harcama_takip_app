import 'package:flutter_test/flutter_test.dart';
import 'package:harcama_takip/application/services/installment_posting_service.dart';
import 'package:harcama_takip/core/utils/money_formatter.dart';
import 'package:harcama_takip/core/utils/statement_calculator.dart';
import 'package:harcama_takip/domain/entities/installment_plan.dart';

import '../helpers/fakes.dart';

void main() {
  group('Kredi kartı harcamalarında otomatik taksit oluşturma', () {
    test('30.000 TL 3 taksit: Kasım 2026, Aralık 2026, Ocak 2027 dönemlerine tam bölünür', () {
      final startDate = DateTime(2026, 11, 10);
      const totalCents = 3000000; // 30.000 TL
      const installments = 3;
      const cutoffDay = 15;

      final centsList = MoneyFormatter.divideInstallmentCents(
        totalCents,
        installments,
      );
      expect(centsList, [1000000, 1000000, 1000000]); // Her taksit 10.000 TL
      expect(centsList.reduce((a, b) => a + b), totalCents);

      final schedule = StatementCalculator.generateSchedule(
        startDate: startDate,
        cutoffDay: cutoffDay,
        totalInstallments: installments,
        installmentCentsList: centsList,
        paymentDueDaysAfterCutoff: 10,
      );

      expect(schedule.length, 3);
      expect(schedule[0].statementPeriod, '2026-11');
      expect(schedule[1].statementPeriod, '2026-12');
      expect(
        schedule[2].statementPeriod,
        '2027-01',
      ); // Yıl geçişi (Aralık -> Ocak)

      const planId = 'test-plan-1';
      final plan = InstallmentPlan(
        id: planId,
        ownerUid: 'user-1',
        visibility: 'personal',
        title: 'Telefon',
        totalAmountInCents: totalCents,
        totalInstallments: installments,
        cardId: 'card-1',
        cardLast4: '1234',
        category: 'electronics',
        startDate: startDate,
        installmentSchedule: schedule,
        createdAt: startDate,
        updatedAt: startDate,
      );

      final result = InstallmentPostingService.applyAllPostings(
        plan,
        now: startDate,
        actorUid: 'user-1',
      );

      expect(result.postings.length, 3);
      expect(result.postings[0].title, 'Telefon - 1. Taksit');
      expect(result.postings[0].statementPeriod, '2026-11');
      expect(result.postings[0].amountInCents, 1000000);
      expect(result.postings[0].date, startDate);

      expect(result.postings[1].title, 'Telefon - 2. Taksit');
      expect(result.postings[1].statementPeriod, '2026-12');
      expect(result.postings[1].amountInCents, 1000000);

      expect(result.postings[2].title, 'Telefon - 3. Taksit');
      expect(result.postings[2].statementPeriod, '2027-01');
      expect(result.postings[2].amountInCents, 1000000);

      final totalPosted = result.postings.fold<int>(
        0,
        (sum, e) => sum + e.amountInCents,
      );
      expect(totalPosted, totalCents);
    });

    test(
      'kuruş farkı olan taksitler kuruş kaybı olmadan ilk taksite eklenir',
      () {
        const totalCents = 10000; // 100,00 TL / 3 taksit
        const installments = 3;
        final centsList = MoneyFormatter.divideInstallmentCents(
          totalCents,
          installments,
        );
        expect(centsList, [3334, 3333, 3333]);
        expect(centsList.reduce((a, b) => a + b), totalCents);
      },
    );
  });

  group('Baştan yazılan taksitlerde ilerleme, kalan borç ve iptal', () {
    // 30.000 TL, 3 taksit: Kasım 2026, Aralık 2026, Ocak 2027.
    InstallmentPlan postedPlan() {
      final start = DateTime(2026, 11, 10);
      final plan = InstallmentPlan(
        id: 'p1',
        ownerUid: 'u1',
        visibility: 'personal',
        title: 'Telefon',
        totalAmountInCents: 3000000,
        totalInstallments: 3,
        cardId: 'c1',
        cardLast4: '1234',
        category: 'shopping',
        startDate: start,
        installmentSchedule: StatementCalculator.generateSchedule(
          startDate: start,
          cutoffDay: 15,
          totalInstallments: 3,
          installmentCentsList: const [1000000, 1000000, 1000000],
        ),
        createdAt: start,
        updatedAt: start,
      );
      return InstallmentPostingService.applyAllPostings(
        plan,
        now: start,
        actorUid: 'u1',
      ).plan;
    }

    test('ilk ay: yalnızca 1. taksit yansımış, kalan borç 2 taksit', () {
      final plan = postedPlan();
      final now = DateTime(2026, 11, 20);
      expect(plan.postedCount, 3); // hepsi harcama olarak yazıldı
      expect(plan.billedCountAt(now), 1);
      expect(plan.billedAmountAt(now), 1000000);
      expect(plan.remainingAmountAt(now), 2000000);
      expect(plan.nextInstallmentAt(now)?.statementPeriod, '2026-12');
      expect(plan.displayStatusAt(now), 'active');
    });

    test('ikinci ayda ilerleme artar', () {
      final plan = postedPlan();
      final now = DateTime(2026, 12, 2);
      expect(plan.billedCountAt(now), 2);
      expect(plan.remainingAmountAt(now), 1000000);
      expect(plan.nextInstallmentAt(now)?.statementPeriod, '2027-01');
    });

    test('son taksit yansıyınca plan tamamlanmış görünür', () {
      final plan = postedPlan();
      final now = DateTime(2027, 1, 5);
      expect(plan.billedCountAt(now), 3);
      expect(plan.remainingAmountAt(now), 0);
      expect(plan.nextInstallmentAt(now), isNull);
      expect(plan.isCompletedAt(now), isTrue);
      expect(plan.displayStatusAt(now), 'completed');
    });

    test(
      'iptal: gelecek taksitler silinir, bu aya kadar yansıyanlar kalır',
      () async {
        final repo = FakeInstallmentRepository();
        final plan = postedPlan();
        repo.plans.value = [plan];
        final now = DateTime(2026, 12, 2);

        await repo.cancelPlan(plan, actorUid: 'u1', now: now);

        final cancelled = repo.plans.value.single;
        expect(cancelled.status, 'cancelled');
        expect(repo.cancelledExpenseIds, {'p1_3_2027-01'});
        expect(cancelled.billedCountAt(now), 2);
        // İptal edilen planda kalan borç yoktur.
        expect(cancelled.remainingAmountAt(now), 0);
        expect(cancelled.nextInstallmentAt(now), isNull);
        expect(cancelled.displayStatusAt(now), 'cancelled');
        expect(cancelled.installmentSchedule.last.status, 'upcoming');
      },
    );

    test('eski usul (ayı gelince işlenen) planlar aynı sonucu verir', () {
      final start = DateTime(2026, 11, 10);
      final legacy = InstallmentPostingService.applyDuePostings(
        postedPlan().copyWith(
          installmentSchedule: [
            for (final s in postedPlan().installmentSchedule)
              s.copyWith(status: 'upcoming'),
          ],
        ),
        now: start,
        actorUid: 'u1',
      ).plan;
      final now = DateTime(2026, 11, 20);
      expect(legacy.billedCountAt(now), 1);
      expect(legacy.remainingAmountAt(now), 2000000);
    });
  });
}
