import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harcama_takip/core/utils/thousands_separator_input_formatter.dart';
import 'package:harcama_takip/core/utils/money_formatter.dart';

void main() {
  group('ThousandsSeparatorInputFormatter', () {
    const formatter = ThousandsSeparatorInputFormatter();

    TextEditingValue format(String oldText, String newText, {int? newCursor}) {
      return formatter.formatEditUpdate(
        TextEditingValue(
          text: oldText,
          selection: TextSelection.collapsed(offset: oldText.length),
        ),
        TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: newCursor ?? newText.length),
        ),
      );
    }

    test('kullanıcının girdiği tutarlara otomatik binlik ayırıcı ekler', () {
      expect(format('', '50000').text, '50.000');
      expect(format('', '150000').text, '150.000');
      expect(format('', '1250000').text, '1.250.000');
      expect(format('', '50000000').text, '50.000.000');
    });

    test('formatlanmış değerler MoneyFormatter.parseToCents ile doğru kuruşa çözülür', () {
      expect(MoneyFormatter.parseToCents(format('', '50000').text), 5000000);
      expect(MoneyFormatter.parseToCents(format('', '150000').text), 15000000);
      expect(MoneyFormatter.parseToCents(format('', '1250000').text), 125000000);
      expect(MoneyFormatter.parseToCents(format('', '50000000').text), 5000000000);
    });

    test('ondalık virgül ve kuruş girişini destekler', () {
      expect(format('50.000', '50.000,').text, '50.000,');
      expect(format('50.000,', '50.000,5').text, '50.000,5');
      expect(format('50.000,5', '50.000,50').text, '50.000,50');
      // 2 haneden fazla kuruş girilmesini sınırlar
      expect(format('50.000,50', '50.000,505').text, '50.000,50');
    });

    test('adım adım rakam girerken imleç sona doğru ilerler', () {
      var v = format('', '5');
      expect(v.text, '5');
      expect(v.selection.baseOffset, 1);

      v = format('5', '50');
      expect(v.text, '50');
      expect(v.selection.baseOffset, 2);

      v = format('50', '500');
      expect(v.text, '500');
      expect(v.selection.baseOffset, 3);

      v = format('500', '5000');
      expect(v.text, '5.000');
      expect(v.selection.baseOffset, 5);

      v = format('5.000', '50000');
      expect(v.text, '50.000');
      expect(v.selection.baseOffset, 6);
    });

    test('nokta silindiğinde önceki rakamı da silerek akıcı deneyim sunar', () {
      // 50.|000 konumunda backspace basıldığında
      final res = formatter.formatEditUpdate(
        const TextEditingValue(
          text: '50.000',
          selection: TextSelection.collapsed(offset: 3),
        ),
        const TextEditingValue(
          text: '50000',
          selection: TextSelection.collapsed(offset: 2),
        ),
      );
      expect(res.text, '5.000');
    });
  });
}
