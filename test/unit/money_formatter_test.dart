import 'package:flutter_test/flutter_test.dart';
import 'package:harcama_takip/core/utils/money_formatter.dart';

void main() {
  group('MoneyFormatter.formatCents', () {
    test('Türk lirası biçiminde gösterir', () {
      expect(MoneyFormatter.formatCents(12550), contains('125,50'));
      expect(MoneyFormatter.formatCents(0), contains('0,00'));
      expect(MoneyFormatter.formatCents(50), contains('0,50'));
      expect(MoneyFormatter.formatCents(123456789), contains('1.234.567,89'));
    });

    test('form alanı için sembolsüz biçim üretir ve geri çözülebilir', () {
      expect(MoneyFormatter.formatForInput(125050), '1.250,50');
      expect(MoneyFormatter.formatForInput(5000000), '50.000');
      expect(MoneyFormatter.formatForInput(15000000), '150.000');
      expect(MoneyFormatter.formatForInput(125000000), '1.250.000');
      expect(MoneyFormatter.formatForInput(5000000000), '50.000.000');
      expect(
        MoneyFormatter.parseToCents(MoneyFormatter.formatForInput(125050)),
        125050,
      );
      expect(
        MoneyFormatter.parseToCents(MoneyFormatter.formatForInput(5000000)),
        5000000,
      );
      expect(MoneyFormatter.formatForInput(0), '');
    });
  });

  group('MoneyFormatter.parseToCents', () {
    test('yaygın girdileri doğru çözer', () {
      expect(MoneyFormatter.parseToCents('125,50'), 12550);
      expect(MoneyFormatter.parseToCents('125.50'), 12550);
      expect(MoneyFormatter.parseToCents('125,5'), 12550);
      expect(MoneyFormatter.parseToCents('100'), 10000);
      expect(MoneyFormatter.parseToCents('0,99'), 99);
      expect(MoneyFormatter.parseToCents('1.250,50'), 125050);
      expect(MoneyFormatter.parseToCents('1.250.000'), 125000000);
      // Türkçe binlik ayırıcı: "10.000" on bin liradır (1,25 / 10,00 değil)
      expect(MoneyFormatter.parseToCents('10.000'), 1000000);
      expect(MoneyFormatter.parseToCents('1.250'), 125000);
      expect(MoneyFormatter.parseToCents('12.5'), 1250);
      expect(MoneyFormatter.parseToCents('₺ 1 250,50'), 125050);
    });

    test('kayan nokta hatası yapmaz', () {
      expect(MoneyFormatter.parseToCents('0,29'), 29);
      expect(MoneyFormatter.parseToCents('1,15'), 115);
      expect(MoneyFormatter.parseToCents('4,35'), 435);
    });

    test('belirsiz ve geçersiz girdileri reddeder', () {
      expect(MoneyFormatter.parseToCents(''), 0);
      expect(MoneyFormatter.parseToCents('geçersiz'), 0);
      expect(MoneyFormatter.parseToCents('-50'), 0);
      expect(MoneyFormatter.parseToCents('0'), 0);
      expect(MoneyFormatter.parseToCents('12,505'), 0);
      expect(MoneyFormatter.parseToCents('12.50.5'), 0);
      expect(MoneyFormatter.parseToCents('1234.567'), 0);
      expect(MoneyFormatter.parseToCents('1,2,3'), 0);
      expect(MoneyFormatter.parseToCents('1,250.50'), 0);
    });

    test('azami tutarı aşan girdiyi reddeder', () {
      expect(
        MoneyFormatter.parseToCents('100000000'),
        MoneyFormatter.maxAmountInCents,
      );
      expect(MoneyFormatter.parseToCents('100000000,01'), 0);
    });
  });

  group('MoneyFormatter.divideInstallmentCents', () {
    test('kuruş kaybetmeden böler, kalanı ilk taksite verir', () {
      expect(MoneyFormatter.divideInstallmentCents(10000, 3), [
        3334,
        3333,
        3333,
      ]);
      final six = MoneyFormatter.divideInstallmentCents(100000, 6);
      expect(six.first, 16670);
      expect(six.skip(1), everyElement(16666));
      expect(six.reduce((a, b) => a + b), 100000);
      expect(MoneyFormatter.divideInstallmentCents(30000, 3), [
        10000,
        10000,
        10000,
      ]);
    });

    test('geçersiz taksit sayısında tutarı tek parça döner', () {
      expect(MoneyFormatter.divideInstallmentCents(500, 0), [500]);
    });
  });
}
