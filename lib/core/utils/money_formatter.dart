import 'package:intl/intl.dart';

/// Para değerlerini daima tamsayı kuruş (amountInCents) olarak işleyen yardımcı.
///
/// Kayan nokta hatalarından kaçınmak için tüm hesaplamalar kuruş cinsinden
/// tamsayı ile yapılır; yalnızca gösterim sırasında TL'ye çevrilir.
abstract class MoneyFormatter {
  /// Tek bir harcama için kabul edilen azami tutar (100 milyon TL).
  static const int maxAmountInCents = 10000000000;

  static final NumberFormat _tryFormatter = NumberFormat.currency(
    locale: 'tr_TR',
    symbol: '₺',
    decimalDigits: 2,
  );

  static final NumberFormat _compactFormatter = NumberFormat.compactCurrency(
    locale: 'tr_TR',
    symbol: '₺',
    decimalDigits: 1,
  );

  static final NumberFormat _plainFormatter = NumberFormat.decimalPatternDigits(
    locale: 'tr_TR',
    decimalDigits: 2,
  );

  /// Kuruş değerini biçimlendirilmiş para dizesine dönüştürür.
  /// Örnek: 12550 -> "₺125,50"
  static String formatCents(int amountInCents, {String currency = 'TRY'}) {
    final double value = amountInCents / 100.0;
    if (currency == 'TRY') {
      return _tryFormatter.format(value);
    }
    return NumberFormat.currency(
      locale: 'tr_TR',
      symbol: '$currency ',
      decimalDigits: 2,
    ).format(value);
  }

  /// Grafik eksenleri gibi dar alanlar için kısa gösterim. Örnek: 1250000 -> "₺12,5 B"
  static String formatCompact(int amountInCents) {
    return _compactFormatter.format(amountInCents / 100.0);
  }

  /// Form alanına geri yazmak için sembolsüz gösterim. Örnek: 125050 -> "1.250,50"
  static String formatForInput(int amountInCents) {
    if (amountInCents <= 0) return '';
    return _plainFormatter.format(amountInCents / 100.0);
  }

  /// Kullanıcının girdiği metni kuruş tamsayısına dönüştürür.
  ///
  /// Kabul edilen biçimler: "125", "125,5", "125,50", "125.50", "1.250", "1.250,50", "1 250,50".
  /// Türkçe kullanıma uygun olarak nokta binlik, virgül ondalık ayırıcıdır ("1.250" = 1250 TL).
  /// Hatalı girdiler (ör. virgülden sonra 3+ hane, harf, negatif) için 0 döner.
  static int parseToCents(String input) {
    var s = input.trim().replaceAll('₺', '').replaceAll(RegExp(r'\s'), '');
    if (s.isEmpty || s.startsWith('-')) return 0;

    final hasComma = s.contains(',');
    final hasDot = s.contains('.');

    if (hasComma && hasDot) {
      // Türkçe biçim: nokta binlik ayırıcı, virgül ondalık ayırıcı.
      if (s.lastIndexOf('.') > s.indexOf(',')) return 0;
      s = s.replaceAll('.', '').replaceAll(',', '.');
    } else if (hasComma) {
      if (','.allMatches(s).length > 1) return 0;
      s = s.replaceAll(',', '.');
    } else if (hasDot) {
      // Türkçede nokta binlik ayırıcıdır: "1.250.000" ve "10.000" tamsayıdır.
      // Tek nokta ve ardından 1-2 hane ise ondalık kabul edilir ("12.5", "12.50").
      final dotCount = '.'.allMatches(s).length;
      final afterDot = s.length - s.lastIndexOf('.') - 1;
      if (dotCount > 1 || afterDot == 3) {
        if (!RegExp(r'^\d{1,3}(\.\d{3})+$').hasMatch(s)) return 0;
        s = s.replaceAll('.', '');
      }
    }

    final match = RegExp(r'^(\d+)(?:\.(\d{0,2}))?$').firstMatch(s);
    if (match == null) return 0;

    final whole = int.tryParse(match.group(1)!);
    if (whole == null) return 0;
    final fraction = (match.group(2) ?? '').padRight(2, '0');
    final cents = whole * 100 + int.parse(fraction.isEmpty ? '0' : fraction);
    if (cents <= 0 || cents > maxAmountInCents) return 0;
    return cents;
  }

  /// Toplam tutarı taksit sayısına kuruş kaybı olmadan böler.
  /// Kalan kuruşlar deterministik olarak ilk taksite eklenir.
  /// Örnek: 10000 kuruş / 3 taksit -> [3334, 3333, 3333]
  static List<int> divideInstallmentCents(
    int totalAmountInCents,
    int totalInstallments,
  ) {
    if (totalInstallments <= 0) return [totalAmountInCents];
    final int baseAmount = totalAmountInCents ~/ totalInstallments;
    final int remainder = totalAmountInCents % totalInstallments;
    return List<int>.generate(
      totalInstallments,
      (i) => i == 0 ? baseAmount + remainder : baseAmount,
    );
  }
}
