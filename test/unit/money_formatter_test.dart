import 'package:flutter_test/flutter_test.dart';
import 'package:harcama_takip/core/utils/money_formatter.dart';

void main() {
  group('MoneyFormatter Tests', () {
    test('formatCents formats correctly in Turkish Lira', () {
      expect(MoneyFormatter.formatCents(12550), contains('125,50'));
      expect(MoneyFormatter.formatCents(0), contains('0,00'));
      expect(MoneyFormatter.formatCents(100), contains('1,00'));
      expect(MoneyFormatter.formatCents(50), contains('0,50'));
    });

    test('parseToCents parses string inputs correctly', () {
      expect(MoneyFormatter.parseToCents('125,50'), equals(12550));
      expect(MoneyFormatter.parseToCents('125.50'), equals(12550));
      expect(MoneyFormatter.parseToCents('100'), equals(10000));
      expect(MoneyFormatter.parseToCents('0,99'), equals(99));
      expect(MoneyFormatter.parseToCents(''), equals(0));
      expect(MoneyFormatter.parseToCents('geçersiz'), equals(0));
    });

    test('divideInstallmentCents divides without loss and gives remainder to first installment', () {
      // 100 TL / 3 taksit = 10000 kuruş / 3 -> [3334, 3333, 3333]
      final result1 = MoneyFormatter.divideInstallmentCents(10000, 3);
      expect(result1, equals([3334, 3333, 3333]));
      expect(result1.reduce((a, b) => a + b), equals(10000));

      // 1000 TL / 6 taksit = 100000 kuruş / 6 -> [16670, 16666, 16666, 16666, 16666, 16666]
      final result2 = MoneyFormatter.divideInstallmentCents(100000, 6);
      expect(result2.length, equals(6));
      expect(result2.first, equals(16670));
      expect(result2.skip(1), everyElement(equals(16666)));
      expect(result2.reduce((a, b) => a + b), equals(100000));

      // Tam bölünen: 300 TL / 3 taksit -> [10000, 10000, 10000]
      final result3 = MoneyFormatter.divideInstallmentCents(30000, 3);
      expect(result3, equals([10000, 10000, 10000]));
      expect(result3.reduce((a, b) => a + b), equals(30000));
    });
  });
}
