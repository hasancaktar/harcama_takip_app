import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:harcama_takip/core/constants/app_constants.dart';
import 'package:harcama_takip/core/l10n/app_locale.dart';
import 'package:harcama_takip/core/l10n/translations_en.dart';

/// Kaynak kodda `.tr` / `.trArgs([...])` ile kullanılan bir metin.
class _SourceKey {
  final String text;
  final String file;
  final int line;
  final bool hasInterpolation;

  const _SourceKey(this.text, this.file, this.line, this.hasInterpolation);

  @override
  String toString() => '$file:$line  "$text"';
}

bool _isIdentifierChar(String c) => RegExp(r'[A-Za-z0-9_$]').hasMatch(c);

/// Bir Dart dosyasındaki dize sabitlerini (yorumlar hariç) okur ve hemen ardından
/// `.tr` / `.trArgs` gelenleri döner. Kaçış dizileri çalışma anındaki karşılığına çevrilir.
List<_SourceKey> _scan(String src, String file) {
  final keys = <_SourceKey>[];
  var i = 0;
  // Yan yana yazılmış dizeler ('a' 'b') tek bir dize sayılır.
  StringBuffer? pending;
  var pendingEnd = -1;
  var pendingStart = 0;
  var pendingInterpolation = false;

  int skipString(int start) {
    // start: açılış tırnağının konumu. Dönen: kapanış tırnağından sonraki konum.
    final quote = src[start];
    final triple = src.startsWith(quote * 3, start);
    final delimiter = triple ? quote * 3 : quote;
    var j = start + delimiter.length;
    while (j < src.length) {
      if (src[j] == r'\') {
        j += 2;
        continue;
      }
      if (src.startsWith(delimiter, j)) return j + delimiter.length;
      if (src[j] == r'$' && j + 1 < src.length && src[j + 1] == '{') {
        var depth = 1;
        j += 2;
        while (j < src.length && depth > 0) {
          final c = src[j];
          if (c == "'" || c == '"') {
            j = skipString(j);
            continue;
          }
          if (c == '{') depth++;
          if (c == '}') depth--;
          j++;
        }
        continue;
      }
      j++;
    }
    return src.length;
  }

  while (i < src.length) {
    final c = src[i];
    if (src.startsWith('//', i)) {
      final end = src.indexOf('\n', i);
      i = end < 0 ? src.length : end;
      continue;
    }
    if (src.startsWith('/*', i)) {
      final end = src.indexOf('*/', i);
      i = end < 0 ? src.length : end + 2;
      continue;
    }
    if (c != "'" && c != '"') {
      i++;
      continue;
    }

    final raw =
        i > 0 && src[i - 1] == 'r' && (i < 2 || !_isIdentifierChar(src[i - 2]));
    final triple = src.startsWith(c * 3, i);
    final delimiter = triple ? c * 3 : c;
    final text = StringBuffer();
    var interpolation = false;
    var j = i + delimiter.length;
    while (j < src.length && !src.startsWith(delimiter, j)) {
      final ch = src[j];
      if (!raw && ch == r'\' && j + 1 < src.length) {
        final next = src[j + 1];
        text.write(switch (next) {
          'n' => '\n',
          't' => '\t',
          'r' => '\r',
          _ => next,
        });
        j += 2;
        continue;
      }
      if (!raw && ch == r'$' && j + 1 < src.length) {
        final next = src[j + 1];
        if (next == '{') {
          interpolation = true;
          var depth = 1;
          j += 2;
          while (j < src.length && depth > 0) {
            final inner = src[j];
            if (inner == "'" || inner == '"') {
              j = skipString(j);
              continue;
            }
            if (inner == '{') depth++;
            if (inner == '}') depth--;
            j++;
          }
          continue;
        }
        if (RegExp(r'[A-Za-z_]').hasMatch(next)) interpolation = true;
      }
      text.write(ch);
      j++;
    }
    final end = j + delimiter.length;

    final adjacent =
        pending != null && src.substring(pendingEnd, i).trim().isEmpty;
    if (adjacent) {
      pending.write(text);
      pendingInterpolation = pendingInterpolation || interpolation;
    } else {
      pending = StringBuffer(text.toString());
      pendingStart = i;
      pendingInterpolation = interpolation;
    }
    pendingEnd = end;

    final rest = src.substring(end).trimLeft();
    if (RegExp(r'^\.tr(Args)?(?![A-Za-z0-9_])').hasMatch(rest)) {
      final line = '\n'.allMatches(src.substring(0, pendingStart)).length + 1;
      keys.add(
        _SourceKey(pending.toString(), file, line, pendingInterpolation),
      );
    }
    i = end;
  }
  return keys;
}

Set<String> _placeholders(String text) =>
    RegExp(r'\{(\d+)\}').allMatches(text).map((m) => m.group(1)!).toSet();

void main() {
  late final List<_SourceKey> sourceKeys;

  setUpAll(() {
    final files =
        Directory('lib')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))
            .where((f) => !f.uri.pathSegments.last.startsWith('translations_'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    sourceKeys = [
      for (final file in files)
        ..._scan(file.readAsStringSync(), file.path.replaceAll(r'\', '/')),
    ];
  });

  tearDown(() => AppLocale.set(AppLocale.fallback));

  /// Değeri sabit tablolardan gelen ve çalışma anında çevrilen metinler.
  Set<String> dynamicKeys() {
    AppLocale.set(AppLocale.fallback);
    return {for (final m in AppConstants.paymentMethodItems) m.name};
  }

  test('kaynak tarayıcı yeterince metin bulur', () {
    expect(sourceKeys.length, greaterThan(600));
  });

  test('enterpolasyonlu metinler .tr yerine .trArgs ile yer tutucu kullanır', () {
    final dynamic = sourceKeys.where((k) => k.hasInterpolation).toList();
    expect(
      dynamic,
      isEmpty,
      reason:
          'Bu metinlerde \$değişken var; çeviri anahtarı sabit olmalı. '
          "'{0} ...'.trArgs([değer]) biçimini kullanın:\n${dynamic.join('\n')}",
    );
  });

  test('koddaki her metnin İngilizce karşılığı vardır', () {
    final missing = <String, _SourceKey>{};
    for (final key in sourceKeys) {
      if (!translationsEn.containsKey(key.text)) {
        missing.putIfAbsent(key.text, () => key);
      }
    }
    for (final name in dynamicKeys()) {
      if (!translationsEn.containsKey(name)) {
        missing[name] = _SourceKey(
          name,
          'AppConstants.paymentMethodItems',
          0,
          false,
        );
      }
    }
    expect(
      missing.values.toList(),
      isEmpty,
      reason:
          'lib/core/l10n/translations_en.dart dosyasına eklenmeli:\n'
          '${missing.values.join('\n')}',
    );
  });

  test('çeviri tablosunda kullanılmayan anahtar yoktur', () {
    final used = {...sourceKeys.map((k) => k.text), ...dynamicKeys()};
    final orphans = translationsEn.keys
        .where((k) => !used.contains(k))
        .toList();
    expect(
      orphans,
      isEmpty,
      reason: 'Kodda artık kullanılmıyor:\n${orphans.join('\n')}',
    );
  });

  test('çeviriler boş değildir ve yer tutucuları kaynakla aynıdır', () {
    final problems = <String>[];
    translationsEn.forEach((source, translation) {
      if (translation.trim().isEmpty) problems.add('Boş çeviri: "$source"');
      final expected = _placeholders(source);
      final actual = _placeholders(translation);
      if (expected.length != actual.length || !expected.containsAll(actual)) {
        problems.add('Yer tutucu uyuşmuyor: "$source" -> "$translation"');
      }
      // Baştaki/sondaki boşluklar cümle birleştirmede anlam taşır; korunmalıdır.
      if (source.startsWith(' ') != translation.startsWith(' ') ||
          source.endsWith(' ') != translation.endsWith(' ')) {
        problems.add('Baş/son boşluk uyuşmuyor: "$source" -> "$translation"');
      }
    });
    expect(problems, isEmpty, reason: problems.join('\n'));
  });

  test('yerleşik kategorilerin Türkçe ve İngilizce adı vardır', () {
    for (final category in AppConstants.defaultCategories) {
      expect(category.nameTr, isNotEmpty, reason: category.id);
      expect(category.nameEn, isNotEmpty, reason: category.id);
    }
  });

  group('AppLocale', () {
    test('Türkçe kaynak dildir; metin olduğu gibi döner', () {
      AppLocale.set('tr');
      expect('Kaydet'.tr, 'Kaydet');
      expect('{0} gün kaldı'.trArgs([3]), '3 gün kaldı');
      expect(AppLocale.intlLocale, 'tr_TR');
    });

    test('İngilizce seçilince metinler ve yer tutucular çevrilir', () {
      AppLocale.set('en');
      expect('Kaydet'.tr, 'Save');
      expect('{0} gün kaldı'.trArgs([3]), '3 days left');
      expect(
        '{0} kullanıcıdan {1} tanesi şu an bildirim alabiliyor.'.trArgs([
          10,
          4,
        ]),
        '4 of 10 users can currently receive notifications.',
      );
      expect(AppConstants.getPaymentMethod('cash').name, 'Cash');
      expect(AppConstants.otherCategory.name, 'Other');
      expect(AppLocale.intlLocale, 'en_US');
    });

    test('çevirisi olmayan metin Türkçe kaynağa düşer', () {
      AppLocale.set('en');
      expect('Bu metnin çevirisi yok'.tr, 'Bu metnin çevirisi yok');
    });

    test('desteklenmeyen dil kodu varsayılan dile döner', () {
      AppLocale.set('de');
      expect(AppLocale.code, 'tr');
      expect('Kaydet'.tr, 'Kaydet');
    });

    test(
      'her desteklenen dilin adı ve (kaynak dil dışında) tablosu vardır',
      () {
        for (final locale in AppLocale.supportedLocales) {
          final code = locale.languageCode;
          expect(AppLocale.languageNames[code], isNotNull, reason: code);
          if (code != AppLocale.fallback) {
            expect(AppLocale.tableOf(code), isNotNull, reason: code);
          }
        }
      },
    );
  });
}
