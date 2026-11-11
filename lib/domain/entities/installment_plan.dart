import 'package:flutter/foundation.dart';
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

  InstallmentPlan copyWith({
    String? id,
    String? ownerUid,
    String? teamId,
    String? visibility,
    String? title,
    int? totalAmountInCents,
    int? totalInstallments,
    String? cardId,
    String? cardLast4,
    String? category,
    DateTime? startDate,
    String? currency,
    List<StatementInstallmentScheduleItem>? installmentSchedule,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return InstallmentPlan(
      id: id ?? this.id,
      ownerUid: ownerUid ?? this.ownerUid,
      teamId: teamId ?? this.teamId,
      visibility: visibility ?? this.visibility,
      title: title ?? this.title,
      totalAmountInCents: totalAmountInCents ?? this.totalAmountInCents,
      totalInstallments: totalInstallments ?? this.totalInstallments,
      cardId: cardId ?? this.cardId,
      cardLast4: cardLast4 ?? this.cardLast4,
      category: category ?? this.category,
      startDate: startDate ?? this.startDate,
      currency: currency ?? this.currency,
      installmentSchedule: installmentSchedule ?? this.installmentSchedule,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
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
    final scheduleRaw = (map['installmentSchedule'] as List<dynamic>?) ?? [];
    final schedule = scheduleRaw.map((item) {
      final iMap = item as Map<String, dynamic>;
      return StatementInstallmentScheduleItem(
        installmentNumber: iMap['installmentNumber'] as int? ?? 1,
        amountInCents: iMap['amountInCents'] as int? ?? 0,
        statementPeriod: iMap['statementPeriod'] as String? ?? '',
        statementCutoffDate: DateTime.parse(iMap['statementCutoffDate'].toString()),
        dueDate: DateTime.parse(iMap['dueDate'].toString()),
        status: iMap['status'] as String? ?? 'upcoming',
      );
    }).toList();

    return InstallmentPlan(
      id: map['id'] as String? ?? '',
      ownerUid: map['ownerUid'] as String? ?? '',
      teamId: map['teamId'] as String?,
      visibility: map['visibility'] as String? ?? 'personal',
      title: map['title'] as String? ?? '',
      totalAmountInCents: map['totalAmountInCents'] as int? ?? 0,
      totalInstallments: map['totalInstallments'] as int? ?? 1,
      cardId: map['cardId'] as String? ?? '',
      cardLast4: map['cardLast4'] as String? ?? '',
      category: map['category'] as String? ?? 'other',
      startDate: map['startDate'] != null ? DateTime.parse(map['startDate'].toString()) : DateTime.now(),
      currency: map['currency'] as String? ?? 'TRY',
      installmentSchedule: schedule,
      status: map['status'] as String? ?? 'active',
      createdAt: map['createdAt'] != null ? DateTime.parse(map['createdAt'].toString()) : DateTime.now(),
      updatedAt: map['updatedAt'] != null ? DateTime.parse(map['updatedAt'].toString()) : DateTime.now(),
    );
  }
}
