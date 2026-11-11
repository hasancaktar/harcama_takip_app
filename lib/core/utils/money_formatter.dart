import 'package:intl/intl.dart';

/// Para değerlerini daima tamsayı kuruş (amountInCents) olarak işleyen formatlayıcı.
abstract class MoneyFormatter {
  static final NumberFormat _tryFormatter = NumberFormat.currency(
    locale: 'tr_TR',
    symbol: '₺',
    decimalDigits: 2,
  );

  /// Kuruş değerini biçimlendirilmiş para dizesine dönüştürür.
  /// Örnek: 12550 -> "₺125,50"
  static String formatCents(int amountInCents, {String currency = 'TRY'}) {
    final double value = amountInCents / 100.0;
    if (currency == 'TRY') {
      return _tryFormatter.format(value);
    }
    final customFormatter = NumberFormat.currency(
      locale: 'tr_TR',
      symbol: currency,
      decimalDigits: 2,
    );
    return customFormatter.format(value);
  }

  /// Kullanıcının formdan girdiği metni kuruş tamsayısına dönüştürür.
  /// Örnek: "125,50" -> 12550, "125.5" -> 12550, "100" -> 10000
  static int parseToCents(String input) {
    if (input.trim().isEmpty) return 0;
    String sanitized = input.trim().replaceAll('₺', '').replaceAll(' ', '');
    // Eğer virgül varsa noktaya çevir veya binlik ayracı temizle
    if (sanitized.contains(',') && sanitized.contains('.')) {
      sanitized = sanitized.replaceAll('.', '').replaceAll(',', '.');
    } else if (sanitized.contains(',')) {
      sanitized = sanitized.replaceAll(',', '.');
    }
    final double? parsed = double.tryParse(sanitized);
    if (parsed == null || parsed <= 0) return 0;
    return (parsed * 100).round();
  }

  /// Toplam tutarı taksit sayısına tam ve kuruş kaybı olmadan böler.
  /// Kalan kuruşlar deterministik olarak ilk taksite dağıtılır.
  /// Örnek: 10000 kuruş / 3 taksit -> [3334, 3333, 3333]
  static List<int> divideInstallmentCents(int totalAmountInCents, int totalInstallments) {
    if (totalInstallments <= 0) return [totalAmountInCents];
    final int baseAmount = totalAmountInCents ~/ totalInstallments;
    final int remainder = totalAmountInCents % totalInstallments;

    final List<int> installments = [];
    for (int i = 0; i < totalInstallments; i++) {
      if (i == 0) {
        installments.add(baseAmount + remainder);
      } else {
        installments.add(baseAmount);
      }
    }
    return installments;
  }
}
