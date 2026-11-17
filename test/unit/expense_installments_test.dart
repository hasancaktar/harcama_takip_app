import 'package:flutter_test/flutter_test.dart';
import 'package:harcama_takip/application/services/installment_posting_service.dart';
import 'package:harcama_takip/core/utils/money_formatter.dart';
import 'package:harcama_takip/core/utils/statement_calculator.dart';
import 'package:harcama_takip/domain/entities/installment_plan.dart';

void main() {
  group('Kredi kartı harcamalarında otomatik taksit oluşturma', () {
    test('30.000 TL 3 taksit: Kasım 2026, Aralık 2026, Ocak 2027 dönemlerine tam bölünür', () {
      final startDate = DateTime(2026, 11, 10);
      const totalCents = 3000000; // 30.000 TL
      const installments = 3;
      const cutoffDay = 15;

      final centsList = MoneyFormatter.divideInstallmentCents(totalCents, installments);
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
      expect(schedule[2].statementPeriod, '2027-01'); // Yıl geçişi (Aralık -> Ocak)

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

      final totalPosted = result.postings.fold<int>(0, (sum, e) => sum + e.amountInCents);
      expect(totalPosted, totalCents);
    });

    test('kuruş farkı olan taksitler kuruş kaybı olmadan ilk taksite eklenir', () {
      const totalCents = 10000; // 100,00 TL / 3 taksit
      const installments = 3;
      final centsList = MoneyFormatter.divideInstallmentCents(totalCents, installments);
      expect(centsList, [3334, 3333, 3333]);
      expect(centsList.reduce((a, b) => a + b), totalCents);
    });
  });
}
