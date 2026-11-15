import 'package:flutter/foundation.dart';

import '../../core/utils/json_parsers.dart';

@immutable
class Budget {
  final String id;
  final String ownerUid;
  final String? teamId;
  final String visibility; // 'personal' | 'team'
  final String period; // 'YYYY-MM'
  final int totalBudgetInCents;
  final Map<String, int> categoryBudgetsInCents;
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
    this.currency = 'TRY',
    required this.createdAt,
    required this.updatedAt,
  });

  /// Her çalışma alanı + dönem için tek bir bütçe belgesi olmasını garanti eden kimlik.
  /// (Önceki sürüm her kayıtta rastgele kimlik üretiyor, aynı aya birden fazla bütçe yazıyordu.)
  static String idFor({
    required String ownerUid,
    String? teamId,
    required String period,
  }) {
    return teamId != null
        ? 'team_${teamId}_$period'
        : 'user_${ownerUid}_$period';
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
      'currency': currency,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Budget.fromMap(Map<String, dynamic> map) {
    final createdAt = JsonParsers.date(
      map['createdAt'],
      fallback: DateTime.now(),
    );
    return Budget(
      id: JsonParsers.string(map['id']),
      ownerUid: JsonParsers.string(map['ownerUid']),
      teamId: JsonParsers.stringOrNull(map['teamId']),
      visibility: JsonParsers.string(map['visibility'], fallback: 'personal'),
      period: JsonParsers.string(map['period']),
      totalBudgetInCents: JsonParsers.intValue(map['totalBudgetInCents']),
      categoryBudgetsInCents: JsonParsers.intMap(map['categoryBudgetsInCents']),
      currency: JsonParsers.string(map['currency'], fallback: 'TRY'),
      createdAt: createdAt,
      updatedAt: JsonParsers.date(map['updatedAt'], fallback: createdAt),
    );
  }
}
