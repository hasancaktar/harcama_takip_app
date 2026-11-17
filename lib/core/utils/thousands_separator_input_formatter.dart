import 'dart:math' as math;
import 'package:flutter/services.dart';

/// Türkiye yerel sayı formatına uygun (binlik ayırıcı nokta, ondalık ayırıcı virgül)
/// otomatik binlik ayırıcı [TextInputFormatter].
///
/// Örnekler:
///  - "50000" -> "50.000"
///  - "150000" -> "150.000"
///  - "1250000" -> "1.250.000"
///  - "50000000" -> "50.000.000"
///  - "50000,50" -> "50.000,50"
///
/// Kullanıcı yazarken veya silerken imleç konumunu (cursor position) korur.
class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  final int maxIntegerDigits;
  final int maxDecimalDigits;

  const ThousandsSeparatorInputFormatter({
    this.maxIntegerDigits = 11,
    this.maxDecimalDigits = 2,
  });

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    var text = newValue.text;
    var selectionIndex = newValue.selection.extentOffset;

    // Kullanıcı bir noktayı geriye doğru silmeye çalıştıysa (örn. "50.|000" -> backspace),
    // noktanın hemen solundaki basamağı da siliyoruz.
    if (oldValue.text.length == newValue.text.length + 1 &&
        oldValue.selection.isCollapsed &&
        oldValue.selection.baseOffset > 0 &&
        oldValue.text[oldValue.selection.baseOffset - 1] == '.') {
      final deleteIndex = oldValue.selection.baseOffset - 2;
      if (deleteIndex >= 0) {
        text = oldValue.text.substring(0, deleteIndex) +
            oldValue.text.substring(oldValue.selection.baseOffset);
        selectionIndex = deleteIndex;
      }
    }

    // Yalnızca rakam ve virgül kabul edilir. Kullanıcı nokta girdiyse binlik için
    // otomatik oluşturulduğundan doğrudan yok sayılır; virgül yoksa ve klavyede
    // yalnızca nokta tuşu varsa (örn. web/tablet sayısal tuş takımı) virgül gibi ele alınabilir.
    final commaIndex = text.indexOf(',');
    String rawInteger;
    String? rawDecimal;

    if (commaIndex != -1) {
      rawInteger = text.substring(0, commaIndex).replaceAll(RegExp(r'\D'), '');
      final afterComma = text.substring(commaIndex + 1).replaceAll(RegExp(r'\D'), '');
      rawDecimal = afterComma.substring(0, math.min(afterComma.length, maxDecimalDigits));
    } else {
      rawInteger = text.replaceAll(RegExp(r'\D'), '');
      rawDecimal = null;
    }

    // Basamak sınırı
    if (rawInteger.length > maxIntegerDigits) {
      rawInteger = rawInteger.substring(0, maxIntegerDigits);
    }

    // Baştaki anlamsız sıfırları temizle (tek sıfır hariç: "05" -> "5", "0" -> "0")
    if (rawInteger.length > 1 && rawInteger.startsWith('0')) {
      rawInteger = rawInteger.replaceFirst(RegExp(r'^0+'), '');
      if (rawInteger.isEmpty) rawInteger = '0';
    }

    if (rawInteger.isEmpty && rawDecimal == null) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    // Tamsayı kısmını 3'lü gruplar halinde noktayla biçimlendir
    final formattedInteger = _formatInteger(rawInteger);

    // Son metni oluştur
    final buffer = StringBuffer(formattedInteger);
    final hasCommaInInput = commaIndex != -1;
    if (hasCommaInInput) {
      buffer.write(',');
      if (rawDecimal != null && rawDecimal.isNotEmpty) {
        buffer.write(rawDecimal);
      }
    }

    final formattedText = buffer.toString();

    // İmleç konumunu yeniden hesapla
    final newCursor = _calculateCursorPosition(
      rawInput: text,
      selectionIndex: selectionIndex,
      formattedText: formattedText,
      hasComma: hasCommaInInput,
    );

    return TextEditingValue(
      text: formattedText,
      selection: TextSelection.collapsed(offset: newCursor),
    );
  }

  static String _formatInteger(String digits) {
    if (digits.isEmpty) return '';
    final buffer = StringBuffer();
    final len = digits.length;
    for (var i = 0; i < len; i++) {
      if (i > 0 && (len - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }

  static int _calculateCursorPosition({
    required String rawInput,
    required int selectionIndex,
    required String formattedText,
    required bool hasComma,
  }) {
    // rawInput içinde imleçten önceki basamak sayısını ve virgülü geçip geçmediğini say
    final safeIndex = selectionIndex.clamp(0, rawInput.length);
    var digitsBefore = 0;
    var passedComma = false;

    for (var i = 0; i < safeIndex; i++) {
      final ch = rawInput[i];
      if (RegExp(r'\d').hasMatch(ch)) {
        digitsBefore++;
      } else if (ch == ',') {
        passedComma = true;
      }
    }

    // formattedText içinde aynı sayıda basamağa (ve virgüle) denk gelen konumu bul
    var targetOffset = 0;
    var digitsCounted = 0;

    while (targetOffset < formattedText.length) {
      final ch = formattedText[targetOffset];
      if (RegExp(r'\d').hasMatch(ch)) {
        if (digitsCounted == digitsBefore && !passedComma) {
          break;
        }
        digitsCounted++;
        targetOffset++;
        if (digitsCounted == digitsBefore && !passedComma) {
          break;
        }
      } else if (ch == ',') {
        if (passedComma) {
          targetOffset++;
          if (digitsCounted == digitsBefore) {
            break;
          }
        } else {
          break;
        }
      } else {
        // Binlik ayırıcı nokta
        targetOffset++;
      }
    }

    return targetOffset.clamp(0, formattedText.length);
  }
}
