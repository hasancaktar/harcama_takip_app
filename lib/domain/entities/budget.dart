import 'package:flutter/foundation.dart';

@immutable
class Budget {
  final String id;
  final String ownerUid;
  final String? teamId;
  final String visibility; // 'personal' | 'team'
  final String period; // 'YYYY-MM'
  final int totalBudgetInCents;
  final Map<String, int> categoryBudgetsInCents;
  final bool rolloverRemaining;
  final List<int> alertThresholds; // [50, 75, 90, 100]
  final String currency;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Budget({
    required this.id,
    required this.ownerUid,
    this.teamId,
    required this.visibility,
    required this.period,
    required this.totalBudgetInCents,
    this.categoryBudgetsInCents = const {},
    this.rolloverRemaining = false,
    this.alertThresholds = const [50, 75, 90, 100],
    this.currency = 'TRY',
    required this.createdAt,
    required this.updatedAt,
  });

  Budget copyWith({
    String? id,
    String? ownerUid,
    String? teamId,
    String? visibility,
    String? period,
    int? totalBudgetInCents,
    Map<String, int>? categoryBudgetsInCents,
    bool? rolloverRemaining,
    List<int>? alertThresholds,
    String? currency,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Budget(
      id: id ?? this.id,
      ownerUid: ownerUid ?? this.ownerUid,
      teamId: teamId ?? this.teamId,
      visibility: visibility ?? this.visibility,
      period: period ?? this.period,
      totalBudgetInCents: totalBudgetInCents ?? this.totalBudgetInCents,
      categoryBudgetsInCents: categoryBudgetsInCents ?? this.categoryBudgetsInCents,
      rolloverRemaining: rolloverRemaining ?? this.rolloverRemaining,
      alertThresholds: alertThresholds ?? this.alertThresholds,
      currency: currency ?? this.currency,
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
      'period': period,
      'totalBudgetInCents': totalBudgetInCents,
      'categoryBudgetsInCents': categoryBudgetsInCents,
      'rolloverRemaining': rolloverRemaining,
      'alertThresholds': alertThresholds,
      'currency': currency,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Budget.fromMap(Map<String, dynamic> map) {
    final catRaw = map['categoryBudgetsInCents'] as Map<String, dynamic>? ?? {};
    final catMap = catRaw.map((k, v) => MapEntry(k, v as int));

    return Budget(
      id: map['id'] as String? ?? '',
      ownerUid: map['ownerUid'] as String? ?? '',
      teamId: map['teamId'] as String?,
      visibility: map['visibility'] as String? ?? 'personal',
      period: map['period'] as String? ?? '',
      totalBudgetInCents: map['totalBudgetInCents'] as int? ?? 0,
      categoryBudgetsInCents: catMap,
      rolloverRemaining: map['rolloverRemaining'] as bool? ?? false,
      alertThresholds: List<int>.from(map['alertThresholds'] ?? [50, 75, 90, 100]),
      currency: map['currency'] as String? ?? 'TRY',
      createdAt: map['createdAt'] != null ? DateTime.parse(map['createdAt'].toString()) : DateTime.now(),
      updatedAt: map['updatedAt'] != null ? DateTime.parse(map['updatedAt'].toString()) : DateTime.now(),
    );
  }
}
