import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore belgelerinden gelen gevşek tipli verileri güvenle okumak için yardımcılar.
///
/// Belgeler farklı istemciler (mobil, web, bulut fonksiyonu) tarafından yazılabildiği için
/// tarih alanları ISO metni, [Timestamp] veya milisaniye olarak gelebilir; sayılar web'de
/// `double` olarak dönebilir. Bu yardımcılar tek bir bozuk alanın tüm listeyi
/// çökertmesini engeller.
abstract class JsonParsers {
  static DateTime? dateOrNull(Object? value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return null;
  }

  static DateTime date(Object? value, {DateTime? fallback}) =>
      dateOrNull(value) ?? fallback ?? DateTime.fromMillisecondsSinceEpoch(0);

  static int intValue(Object? value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.round();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  static bool boolValue(Object? value, {bool fallback = false}) =>
      value is bool ? value : fallback;

  static String string(Object? value, {String fallback = ''}) =>
      value is String ? value : fallback;

  static String? stringOrNull(Object? value) =>
      value is String && value.isNotEmpty ? value : null;

  static List<String> stringList(Object? value) {
    if (value is Iterable) return value.whereType<String>().toList();
    return const [];
  }

  static List<int> intList(Object? value, {List<int> fallback = const []}) {
    if (value is Iterable) {
      return value.whereType<num>().map((e) => e.round()).toList();
    }
    return fallback;
  }

  static Map<String, dynamic> map(Object? value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  static Map<String, int> intMap(Object? value) {
    if (value is! Map) return const {};
    final result = <String, int>{};
    value.forEach((key, v) {
      if (key is String && v is num) result[key] = v.round();
    });
    return result;
  }
}
