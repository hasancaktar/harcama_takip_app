import 'package:flutter/foundation.dart';

import '../../core/utils/json_parsers.dart';
import '../../core/utils/statement_calculator.dart';

@immutable
class InstallmentPlan {
  final String id;
  final String ownerUid;
  final String? teamId;
  final String visibility; // 'personal' | 'team'
  final String title;
  final int totalAmountInCents;
  final int totalInstallments;
  final String cardId;
  final String cardLast4;
  final String category;
  final DateTime startDate;
  final String currency;
  final List<StatementInstallmentScheduleItem> installmentSchedule;
  final String status; // 'active' | 'completed' | 'cancelled'
  final DateTime createdAt;
  final DateTime updatedAt;

  const InstallmentPlan({
    required this.id,
    required this.ownerUid,
    this.teamId,
    required this.visibility,
    required this.title,
    required this.totalAmountInCents,
    required this.totalInstallments,
    required this.cardId,
    required this.cardLast4,
    required this.category,
    required this.startDate,
    this.currency = 'TRY',
    required this.installmentSchedule,
    this.status = 'active',
    required this.createdAt,
    required this.updatedAt,
  });

  /// Harcama olarak yazılmış taksit sayısı. Taksitler plan oluşturulurken
  /// gelecek aylara da yazıldığı için bu, ödenen taksit sayısı **değildir**;
  /// ilerleme ve kalan borç için [billedCountAt] / [remainingAmountAt] kullanın.
  int get postedCount => installmentSchedule.where((s) => s.isPosted).length;
  bool get isActive => status == 'active';

  /// Taksit [now] itibarıyla ekstreye yansıdı mı? (Harcama olarak yazılmış ve
  /// ekstre dönemi içinde bulunulan aydan sonra değil.)
  static bool isBilledAt(StatementInstallmentScheduleItem item, DateTime now) =>
      item.isPosted &&
      item.statementPeriod.compareTo(StatementCalculator.periodOf(now)) <= 0;

  /// Ekstreye yansımamış ama ileride yansıyacak taksitler. İptal edilmiş planda
  /// harcamalardan kaldırılan taksitler bu listeye girmez.
  List<StatementInstallmentScheduleItem> upcomingAt(DateTime now) =>
      installmentSchedule
          .where((s) => !isBilledAt(s, now) && (isActive || s.isPosted))
          .toList();

  int billedCountAt(DateTime now) =>
      installmentSchedule.where((s) => isBilledAt(s, now)).length;

  int billedAmountAt(DateTime now) => installmentSchedule
      .where((s) => isBilledAt(s, now))
      .fold(0, (sum, s) => sum + s.amountInCents);

  /// Henüz ekstreye yansımamış taksitlerin toplamı (kalan borç).
  int remainingAmountAt(DateTime now) =>
      upcomingAt(now).fold(0, (sum, s) => sum + s.amountInCents);

  /// Bir sonraki ekstreye yansıyacak taksit.
  StatementInstallmentScheduleItem? nextInstallmentAt(DateTime now) {
    final upcoming = upcomingAt(now);
    return upcoming.isEmpty ? null : upcoming.first;
  }

  /// Tüm taksitler ekstreye yansıdıysa plan tamamlanmış sayılır.
  bool isCompletedAt(DateTime now) =>
      status == 'completed' ||
      (isActive &&
          installmentSchedule.isNotEmpty &&
          installmentSchedule.every((s) => isBilledAt(s, now)));

  /// Ekranda gösterilecek durum: `active`, `completed` veya `cancelled`.
  String displayStatusAt(DateTime now) =>
      isCompletedAt(now) ? 'completed' : status;

  InstallmentPlan copyWith({
    List<StatementInstallmentScheduleItem>? installmentSchedule,
    String? status,
    DateTime? updatedAt,
  }) {
    return InstallmentPlan(
      id: id,
      ownerUid: ownerUid,
      teamId: teamId,
      visibility: visibility,
      title: title,
      totalAmountInCents: totalAmountInCents,
      totalInstallments: totalInstallments,
      cardId: cardId,
      cardLast4: cardLast4,
      category: category,
      startDate: startDate,
      currency: currency,
      installmentSchedule: installmentSchedule ?? this.installmentSchedule,
      status: status ?? this.status,
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
      'totalAmountInCents': totalAmountInCents,
      'totalInstallments': totalInstallments,
      'cardId': cardId,
      'cardLast4': cardLast4,
      'category': category,
      'startDate': startDate.toIso8601String(),
      'currency': currency,
      'installmentSchedule': installmentSchedule.map((i) => i.toMap()).toList(),
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory InstallmentPlan.fromMap(Map<String, dynamic> map) {
    final scheduleRaw = map['installmentSchedule'];
    final schedule = <StatementInstallmentScheduleItem>[];
    if (scheduleRaw is Iterable) {
      for (final raw in scheduleRaw) {
        final item = JsonParsers.map(raw);
        final cutoff = JsonParsers.dateOrNull(item['statementCutoffDate']);
        if (cutoff == null) continue;
        schedule.add(
          StatementInstallmentScheduleItem(
            installmentNumber: JsonParsers.intValue(
              item['installmentNumber'],
              fallback: schedule.length + 1,
            ),
            amountInCents: JsonParsers.intValue(item['amountInCents']),
            statementPeriod: JsonParsers.string(item['statementPeriod']),
            statementCutoffDate: cutoff,
            dueDate: JsonParsers.date(item['dueDate'], fallback: cutoff),
            status: JsonParsers.string(item['status'], fallback: 'upcoming'),
          ),
        );
      }
    }
    final createdAt = JsonParsers.date(
      map['createdAt'],
      fallback: DateTime.now(),
    );
    return InstallmentPlan(
      id: JsonParsers.string(map['id']),
      ownerUid: JsonParsers.string(map['ownerUid']),
      teamId: JsonParsers.stringOrNull(map['teamId']),
      visibility: JsonParsers.string(map['visibility'], fallback: 'personal'),
      title: JsonParsers.string(map['title']),
      totalAmountInCents: JsonParsers.intValue(map['totalAmountInCents']),
      totalInstallments: JsonParsers.intValue(
        map['totalInstallments'],
        fallback: schedule.length,
      ).clamp(1, 120),
      cardId: JsonParsers.string(map['cardId']),
      cardLast4: JsonParsers.string(map['cardLast4']),
      category: JsonParsers.string(map['category'], fallback: 'other'),
      startDate: JsonParsers.date(map['startDate'], fallback: createdAt),
      currency: JsonParsers.string(map['currency'], fallback: 'TRY'),
      installmentSchedule: schedule,
      status: JsonParsers.string(map['status'], fallback: 'active'),
      createdAt: createdAt,
      updatedAt: JsonParsers.date(map['updatedAt'], fallback: createdAt),
    );
  }
}
