import 'package:flutter_test/flutter_test.dart';
import 'package:harcama_takip/core/utils/statement_calculator.dart';

void main() {
  group('Kesim günü', () {
    test(
      '28/29/30/31 günlük aylarda kesim gününü ayın son gününe sabitler',
      () {
        expect(StatementCalculator.getEffectiveCutoffDay(2026, 1, 31), 31);
        expect(StatementCalculator.getEffectiveCutoffDay(2026, 2, 31), 28);
        expect(StatementCalculator.getEffectiveCutoffDay(2028, 2, 31), 29);
        expect(StatementCalculator.getEffectiveCutoffDay(2026, 4, 31), 30);
        expect(StatementCalculator.getEffectiveCutoffDay(2026, 2, 15), 15);
      },
    );
  });

  group('Ekstre dönemi', () {
    test('kesim gününe kadar o ay, sonrasında sonraki ay', () {
      expect(
        StatementCalculator.resolveStatementPeriod(
          DateTime(2026, 11, 10, 14, 30),
          15,
        ),
        '2026-11',
      );
      expect(
        StatementCalculator.resolveStatementPeriod(
          DateTime(2026, 11, 15, 23, 59),
          15,
        ),
        '2026-11',
      );
      expect(
        StatementCalculator.resolveStatementPeriod(
          DateTime(2026, 11, 16, 0, 1),
          15,
        ),
        '2026-12',
      );
    });

    test('yıl geçişini doğru yapar', () {
      expect(
        StatementCalculator.resolveStatementPeriod(DateTime(2026, 12, 20), 15),
        '2027-01',
      );
      expect(
        StatementCalculator.resolveStatementPeriod(DateTime(2026, 12, 10), 15),
        '2026-12',
      );
    });

    test('REGRESYON: nakit harcamalar takvim ayına yazılır (eski sürüm sonraki aya yazıyordu)', () {
      final date = DateTime(2026, 11, 16, 12);
      expect(
        StatementCalculator.periodForExpense(date: date, paymentMethod: 'cash'),
        '2026-11',
      );
      expect(
        StatementCalculator.periodForExpense(
          date: date,
          paymentMethod: 'debit_card',
          cutoffDay: 1,
        ),
        '2026-11',
      );
      expect(
        StatementCalculator.periodForExpense(
          date: date,
          paymentMethod: 'credit_card',
          cutoffDay: 15,
        ),
        '2026-12',
      );
      expect(
        StatementCalculator.periodForExpense(
          date: date,
          paymentMethod: 'credit_card',
        ),
        '2026-11',
      );
    });
  });

  group('Dönem yardımcıları', () {
    test('kaydırma, doğrulama ve son dönemler', () {
      expect(StatementCalculator.shiftPeriod('2026-12', 1), '2027-01');
      expect(StatementCalculator.shiftPeriod('2026-01', -1), '2025-12');
      expect(StatementCalculator.isValidPeriod('2026-11'), isTrue);
      expect(StatementCalculator.isValidPeriod('2026-13'), isFalse);
      expect(StatementCalculator.isValidPeriod('26-1'), isFalse);
      expect(StatementCalculator.lastPeriods('2026-02', 3), [
        '2025-12',
        '2026-01',
        '2026-02',
      ]);
    });

    test('bir sonraki kesim tarihi (kesim günü dahil)', () {
      expect(
        StatementCalculator.nextCutoffDate(DateTime(2026, 11, 10), 15).day,
        15,
      );
      expect(
        StatementCalculator.nextCutoffDate(
          DateTime(2026, 11, 15, 20),
          15,
        ).month,
        11,
      );
      final next = StatementCalculator.nextCutoffDate(
        DateTime(2026, 11, 16),
        15,
      );
      expect([next.month, next.day], [12, 15]);
      final feb = StatementCalculator.nextCutoffDate(
        DateTime(
          2027,
          1,
          31,
          23,
          59,
          59,
          999,
        ).add(const Duration(milliseconds: 1)),
        31,
      );
      expect([feb.month, feb.day], [2, 28]);
    });

    test('son ödeme tarihi kesimden N gün sonradır', () {
      final due = StatementCalculator.calculateDueDate(
        statementPeriod: '2026-02',
        cutoffDay: 31,
        paymentDueDaysAfterCutoff: 10,
      );
      expect([due.month, due.day], [3, 10]);
    });
  });

  group('Taksit takvimi', () {
    test(
      'yıl sınırını aşan takvim üretir; tüm taksitler başlangıçta beklemede',
      () {
        final schedule = StatementCalculator.generateSchedule(
          startDate: DateTime(2026, 11, 20),
          cutoffDay: 15,
          totalInstallments: 3,
          installmentCentsList: const [3334, 3333, 3333],
          paymentDueDaysAfterCutoff: 10,
        );
        expect(schedule.map((s) => s.statementPeriod), [
          '2026-12',
          '2027-01',
          '2027-02',
        ]);
        expect(schedule.first.dueDate.day, 25);
        expect(schedule.every((s) => s.status == 'upcoming'), isTrue);
      },
    );

    test(
      'işleme kuralı: yalnızca içinde bulunulan döneme kadarki taksitler',
      () {
        final item = StatementInstallmentScheduleItem(
          installmentNumber: 2,
          amountInCents: 100,
          statementPeriod: '2026-12',
          statementCutoffDate: DateTime(2026, 12, 15, 23, 59),
          dueDate: DateTime(2026, 12, 25),
          status: 'upcoming',
        );
        expect(
          InstallmentPostingPolicy.isDue(item, DateTime(2026, 11, 30)),
          isFalse,
        );
        expect(
          InstallmentPostingPolicy.isDue(item, DateTime(2026, 12, 1)),
          isTrue,
        );
        expect(
          InstallmentPostingPolicy.isDue(
            item.copyWith(status: 'posted'),
            DateTime(2027, 1, 1),
          ),
          isFalse,
        );
        expect(
          InstallmentPostingPolicy.expenseIdFor('p1', item),
          'p1_2_2026-12',
        );
      },
    );
  });
}
