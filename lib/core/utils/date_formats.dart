import 'package:harcama_takip/core/l10n/app_locale.dart';
import 'package:intl/intl.dart';

import 'statement_calculator.dart';

/// Uygulama genelinde tutarlı Türkçe tarih biçimleri.
abstract class DateFormats {
  static String get _locale => AppLocale.intlLocale;

  /// "Kasım 2026"
  static String period(String period) {
    if (!StatementCalculator.isValidPeriod(period)) return period;
    return DateFormat(
      'MMMM yyyy',
      _locale,
    ).format(StatementCalculator.periodStart(period));
  }

  /// "Kas 2026"
  static String periodShort(String period) {
    if (!StatementCalculator.isValidPeriod(period)) return period;
    return DateFormat(
      'MMM yy',
      _locale,
    ).format(StatementCalculator.periodStart(period));
  }

  /// "16 Kasım 2026"
  static String day(DateTime date) =>
      DateFormat('d MMMM yyyy', _locale).format(date);

  /// "16 Kas"
  static String dayShort(DateTime date) =>
      DateFormat('d MMM', _locale).format(date);

  /// "16 Kasım 2026, 14:30"
  static String dayTime(DateTime date) =>
      DateFormat('d MMMM yyyy, HH:mm', _locale).format(date);

  /// "Pazartesi, 16 Kasım"
  static String weekdayDay(DateTime date) =>
      DateFormat('EEEE, d MMMM', _locale).format(date);

  /// "14:30"
  static String time(DateTime date) =>
      DateFormat('HH:mm', _locale).format(date);

  /// Liste başlıkları için göreli gün: "Bugün", "Dün" veya "Pazartesi, 16 Kasım".
  static String relativeDay(DateTime date, {DateTime? now}) {
    final today = _dateOnly(now ?? DateTime.now());
    final target = _dateOnly(date);
    final diff = today.difference(target).inDays;
    if (diff == 0) return 'Bugün'.tr;
    if (diff == 1) return 'Dün'.tr;
    if (diff == -1) return 'Yarın'.tr;
    return weekdayDay(date);
  }

  /// Bir tarihe kalan gün sayısını kullanıcı dostu metne çevirir.
  static String daysUntil(DateTime date, {DateTime? now}) {
    final diff = _dateOnly(date)
        .difference(_dateOnly(now ?? DateTime.now()))
        .inDays;
    if (diff < 0) return '{0} gün önce'.trArgs([-diff]);
    if (diff == 0) return 'Bugün'.tr;
    if (diff == 1) return 'Yarın'.tr;
    return '{0} gün kaldı'.trArgs([diff]);
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
}
