import 'package:flutter/foundation.dart';

import '../../core/utils/json_parsers.dart';
import '../../core/utils/statement_calculator.dart';

/// Her ay aynı gün tekrarlanan ödeme (otomatik ödeme talimatı, abonelik, fatura).
///
/// Her ayın kaydı, o ay geldiğinde harcama olarak yazılır (uygulama açılışında
/// eşitlenir; bkz. RecurringPaymentService). Harcama kimliği ödeme + ay ile
/// belirlenir, böylece aynı ay iki kez yazılmaz. Sonlandırılan ödemenin geçmiş
/// kayıtları korunur; bitiş tarihinden sonraki kayıtları silinir.
@immutable
class RecurringPayment {
  final String id;
  final String ownerUid;
  final String? teamId;
  final String visibility; // 'personal' | 'team'
  final String title;
  final int amountInCents;
  final String currency;
  final String category;

  /// Ödemenin yapıldığı kredi kartı; `null` ise karttan bağımsız (banka hesabı).
  final String? cardId;
  final String? cardLast4;

  /// Kartın kesim günü (ekstre dönemi hesabı için kayıt anındaki değer).
  final int? cardCutoffDay;

  /// Ayın kaçıncı günü ödendiği (1-31). Kısa aylarda ayın son günü kullanılır.
  final int dayOfMonth;

  /// İlk ödemenin tarihi (saat bilgisi her ayın kaydında korunur).
  final DateTime startDate;

  /// Sonlandırıldığı an; bu andan sonraki ödemeler yazılmaz.
  final DateTime? endDate;

  /// Harcama olarak yazılmış son ay ('YYYY-MM').
  final String? lastPostedMonth;
  final String status; // 'active' | 'cancelled'
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const RecurringPayment({
    required this.id,
    required this.ownerUid,
    this.teamId,
    required this.visibility,
    required this.title,
    required this.amountInCents,
    this.currency = 'TRY',
    required this.category,
    this.cardId,
    this.cardLast4,
    this.cardCutoffDay,
    required this.dayOfMonth,
    required this.startDate,
    this.endDate,
    this.lastPostedMonth,
    this.status = 'active',
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isActive => status == 'active';
  bool get hasCard => cardId != null;
  String get startMonth => StatementCalculator.periodOf(startDate);

  /// Harcama belgesinin kimliği (deterministik; aynı ay iki kez yazılmaz).
  static String expenseIdFor(String paymentId, String month) =>
      '${paymentId}_$month';

  /// [month] ('YYYY-MM') ayındaki ödeme tarihi; ay kısaysa ayın son günü.
  DateTime occurrenceDate(String month) {
    final start = StatementCalculator.periodStart(month);
    final lastDay = DateTime(start.year, start.month + 1, 0).day;
    final day = dayOfMonth > lastDay ? lastDay : dayOfMonth;
    return DateTime(
      start.year,
      start.month,
      day,
      startDate.hour,
      startDate.minute,
    );
  }

  /// [now] itibarıyla yazılması gereken ama henüz yazılmamış aylar (bu ay dahil).
  List<String> dueMonths(DateTime now) {
    if (!isActive) return const [];
    final current = StatementCalculator.periodOf(now);
    var month = lastPostedMonth == null
        ? startMonth
        : StatementCalculator.shiftPeriod(lastPostedMonth!, 1);
    if (month.compareTo(startMonth) < 0) month = startMonth;
    final result = <String>[];
    while (month.compareTo(current) <= 0) {
      result.add(month);
      month = StatementCalculator.shiftPeriod(month, 1);
    }
    return result;
  }

  /// Yazılmış olup tarihi [now]'dan sonra olan aylar (sonlandırma veya
  /// düzenlemede bunlar silinir ya da yeni değerlerle yeniden yazılır).
  List<String> postedMonthsAfter(DateTime now) {
    final last = lastPostedMonth;
    if (last == null) return const [];
    final result = <String>[];
    var month = startMonth;
    while (month.compareTo(last) <= 0) {
      if (occurrenceDate(month).isAfter(now)) result.add(month);
      month = StatementCalculator.shiftPeriod(month, 1);
    }
    return result;
  }

  /// Bugünden sonraki ilk ödeme tarihi (sonlandırılmışsa `null`).
  DateTime? nextOccurrenceAfter(DateTime now) {
    if (!isActive) return null;
    var month = StatementCalculator.periodOf(now);
    if (month.compareTo(startMonth) < 0) month = startMonth;
    for (var i = 0; i < 3; i++) {
      final date = occurrenceDate(month);
      if (date.isAfter(now)) return date;
      month = StatementCalculator.shiftPeriod(month, 1);
    }
    return null;
  }

  RecurringPayment copyWith({
    String? title,
    int? amountInCents,
    String? category,
    String? cardId,
    String? cardLast4,
    int? cardCutoffDay,
    bool clearCard = false,
    int? dayOfMonth,
    DateTime? endDate,
    String? lastPostedMonth,
    String? status,
    String? notes,
    DateTime? updatedAt,
  }) {
    return RecurringPayment(
      id: id,
      ownerUid: ownerUid,
      teamId: teamId,
      visibility: visibility,
      title: title ?? this.title,
      amountInCents: amountInCents ?? this.amountInCents,
      currency: currency,
      category: category ?? this.category,
      cardId: clearCard ? null : (cardId ?? this.cardId),
      cardLast4: clearCard ? null : (cardLast4 ?? this.cardLast4),
      cardCutoffDay: clearCard ? null : (cardCutoffDay ?? this.cardCutoffDay),
      dayOfMonth: dayOfMonth ?? this.dayOfMonth,
      startDate: startDate,
      endDate: endDate ?? this.endDate,
      lastPostedMonth: lastPostedMonth ?? this.lastPostedMonth,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ownerUid': ownerUid,
      'teamId': teamId,
      'visibility': visibility,
      'title': title,
      'amountInCents': amountInCents,
      'currency': currency,
      'category': category,
      'cardId': cardId,
      'cardLast4': cardLast4,
      'cardCutoffDay': cardCutoffDay,
      'dayOfMonth': dayOfMonth,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'lastPostedMonth': lastPostedMonth,
      'status': status,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory RecurringPayment.fromMap(Map<String, dynamic> map) {
    final createdAt = JsonParsers.date(
      map['createdAt'],
      fallback: DateTime.now(),
    );
    final cutoff = JsonParsers.intValue(map['cardCutoffDay']);
    final lastPosted = JsonParsers.stringOrNull(map['lastPostedMonth']);
    return RecurringPayment(
      id: JsonParsers.string(map['id']),
      ownerUid: JsonParsers.string(map['ownerUid']),
      teamId: JsonParsers.stringOrNull(map['teamId']),
      visibility: JsonParsers.string(map['visibility'], fallback: 'personal'),
      title: JsonParsers.string(map['title']),
      amountInCents: JsonParsers.intValue(map['amountInCents']),
      currency: JsonParsers.string(map['currency'], fallback: 'TRY'),
      category: JsonParsers.string(map['category'], fallback: 'other'),
      cardId: JsonParsers.stringOrNull(map['cardId']),
      cardLast4: JsonParsers.stringOrNull(map['cardLast4']),
      cardCutoffDay: cutoff >= 1 && cutoff <= 31 ? cutoff : null,
      dayOfMonth: JsonParsers.intValue(
        map['dayOfMonth'],
        fallback: 1,
      ).clamp(1, 31),
      startDate: JsonParsers.date(map['startDate'], fallback: createdAt),
      endDate: JsonParsers.dateOrNull(map['endDate']),
      lastPostedMonth:
          lastPosted != null && StatementCalculator.isValidPeriod(lastPosted)
          ? lastPosted
          : null,
      status: JsonParsers.string(map['status'], fallback: 'active'),
      notes: JsonParsers.stringOrNull(map['notes']),
      createdAt: createdAt,
      updatedAt: JsonParsers.date(map['updatedAt'], fallback: createdAt),
    );
  }
}
