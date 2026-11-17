import 'package:flutter/widgets.dart';

import 'translations_en.dart';

/// Merkezi dil yönetimi.
///
/// Kaynak dil Türkçedir; arayüz metinleri kodda Türkçe yazılır ve `.tr` ile
/// etkin dile çevrilir (gettext yaklaşımı). Yeni bir dil eklemek için:
///  1. `translations_xx.dart` içinde Türkçe -> hedef dil eşlemesi oluşturun,
///  2. [_tables] ve [supportedLocales] listelerine ekleyin.
/// `test/unit/translations_test.dart`, koddaki her metnin çevirisinin bulunduğunu doğrular.
abstract class AppLocale {
  static const String fallback = 'tr';
  static const List<Locale> supportedLocales = [Locale('tr'), Locale('en')];
  static const Map<String, String> languageNames = {
    'tr': 'Türkçe',
    'en': 'English',
  };

  static const Map<String, Map<String, String>> _tables = {
    'en': translationsEn,
  };

  static String _code = fallback;

  static String get code => _code;
  static bool get isTurkish => _code == 'tr';
  static Locale get locale => Locale(_code);

  /// `intl` biçimlendirmeleri (tarih adları) için yerel ayar.
  static String get intlLocale => _code == 'en' ? 'en_US' : 'tr_TR';

  static void set(String code) {
    _code = languageNames.containsKey(code) ? code : fallback;
  }

  static String translate(String source) {
    if (_code == fallback) return source;
    return _tables[_code]?[source] ?? source;
  }

  /// Verilen dil için çeviri tablosu (testler için).
  static Map<String, String>? tableOf(String code) => _tables[code];
}

extension TranslateX on String {
  /// Etkin dildeki karşılığı (yoksa Türkçe kaynak metin).
  String get tr => AppLocale.translate(this);

  /// `{0}`, `{1}` yer tutuculu metinler için: `'{0} harcama'.trArgs([3])`.
  String trArgs(List<Object?> args) {
    var result = AppLocale.translate(this);
    for (var i = 0; i < args.length; i++) {
      result = result.replaceAll('{$i}', '${args[i]}');
    }
    return result;
  }
}
