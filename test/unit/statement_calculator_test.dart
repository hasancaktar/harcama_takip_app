import 'package:flutter_test/flutter_test.dart';
import 'package:harcama_takip/core/utils/statement_calculator.dart';

void main() {
  group('StatementCalculator Tests', () {
    test('Clamps cutoff day for 28/29/30/31 day months', () {
      // 31. gün hedefi:
      // Ocak (31 gün) -> 31
      expect(StatementCalculator.getEffectiveCutoffDay(2026, 1, 31), equals(31));
      // Şubat 2026 (28 gün) -> 28
      expect(StatementCalculator.getEffectiveCutoffDay(2026, 2, 31), equals(28));
      // Şubat 2028 (Artık yıl - 29 gün) -> 29
      expect(StatementCalculator.getEffectiveCutoffDay(2028, 2, 31), equals(29));
      // Nisan (30 gün) -> 30
      expect(StatementCalculator.getEffectiveCutoffDay(2026, 4, 31), equals(30));
      // Normal gün (örneğin 15. gün) -> 15
      expect(StatementCalculator.getEffectiveCutoffDay(2026, 2, 15), equals(15));
    });

    test('Resolves statement period correctly for transactions before and after cutoff', () {
      // Kart kesim günü 15
      // 10 Kasım 2026 harcaması -> 2026-11 dönemine aittir
      final t1 = DateTime(2026, 11, 10, 14, 30);
      expect(StatementCalculator.resolveStatementPeriod(t1, 15), equals('2026-11'));

      // 15 Kasım 2026 saat 20:00 (tam kesim günü) -> 2026-11 dönemine aittir
      final t2 = DateTime(2026, 11, 15, 20, 00);
      expect(StatementCalculator.resolveStatementPeriod(t2, 15), equals('2026-11'));

      // 16 Kasım 2026 saat 00:01 (kesimden hemen sonra) -> sonraki dönem 2026-12 dönemine aittir
      final t3 = DateTime(2026, 11, 16, 0, 1);
      expect(StatementCalculator.resolveStatementPeriod(t3, 15), equals('2026-12'));
    });

    test('Handles year transition correctly (December to January)', () {
      // 20 Aralık 2026'da yapılan harcama, kesim günü 15 ise -> 2027-01 dönemine aittir
      final tDec = DateTime(2026, 12, 20, 10, 0);
      expect(StatementCalculator.resolveStatementPeriod(tDec, 15), equals('2027-01'));

      // 10 Aralık 2026 harcaması, kesim günü 15 -> 2026-12
      final tDecBefore = DateTime(2026, 12, 10, 10, 0);
      expect(StatementCalculator.resolveStatementPeriod(tDecBefore, 15), equals('2026-12'));
    });

    test('Generates installment schedule across year boundaries and calculates due dates', () {
      // 20 Kasım 2026 başlangıçlı, kesim günü 15 (yani ilk dönem 2026-12), 3 taksit
      final startDate = DateTime(2026, 11, 20);
      final schedule = StatementCalculator.generateSchedule(
        startDate: startDate,
        cutoffDay: 15,
        totalInstallments: 3,
        installmentCentsList: [3334, 3333, 3333],
        paymentDueDaysAfterCutoff: 10,
      );

      expect(schedule.length, equals(3));

      // Taksit 1: 2026-12
      expect(schedule[0].statementPeriod, equals('2026-12'));
      expect(schedule[0].amountInCents, equals(3334));
      expect(schedule[0].dueDate.day, equals(25)); // 15 + 10 = 25 Aralık

      // Taksit 2: 2027-01 (Yıl atlama)
      expect(schedule[1].statementPeriod, equals('2027-01'));
      expect(schedule[1].amountInCents, equals(3333));

      // Taksit 3: 2027-02
      expect(schedule[2].statementPeriod, equals('2027-02'));
      expect(schedule[2].amountInCents, equals(3333));
    });
  });
}
