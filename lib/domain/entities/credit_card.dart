import 'package:flutter/foundation.dart';

import '../../core/utils/json_parsers.dart';

@immutable
class CreditCard {
  final String id;
  final String ownerUid;
  final String? teamId;
  final bool isSharedWithTeam;
  final String name;
  final String bankName;
  final String last4Digits;
  final String colorHex;
  final int limitInCents;
  final int cutoffDay; // 1 - 31
  final int paymentDueDaysAfterCutoff;
  final String currency;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CreditCard({
    required this.id,
    required this.ownerUid,
    this.teamId,
    this.isSharedWithTeam = false,
    required this.name,
    required this.bankName,
    required this.last4Digits,
    this.colorHex = '#1E3A8A',
    this.limitInCents = 0,
    required this.cutoffDay,
    this.paymentDueDaysAfterCutoff = 10,
    this.currency = 'TRY',
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  String get displayName => '$name •••• $last4Digits';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ownerUid': ownerUid,
      'teamId': teamId,
      'isSharedWithTeam': isSharedWithTeam,
      'name': name,
      'bankName': bankName,
      'last4Digits': last4Digits,
      'colorHex': colorHex,
      'limitInCents': limitInCents,
      'cutoffDay': cutoffDay,
      'paymentDueDaysAfterCutoff': paymentDueDaysAfterCutoff,
      'currency': currency,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory CreditCard.fromMap(Map<String, dynamic> map) {
    final createdAt = JsonParsers.date(
      map['createdAt'],
      fallback: DateTime.now(),
    );
    final cutoff = JsonParsers.intValue(map['cutoffDay'], fallback: 1);
    return CreditCard(
      id: JsonParsers.string(map['id']),
      ownerUid: JsonParsers.string(map['ownerUid']),
      teamId: JsonParsers.stringOrNull(map['teamId']),
      isSharedWithTeam: JsonParsers.boolValue(map['isSharedWithTeam']),
      name: JsonParsers.string(map['name']),
      bankName: JsonParsers.string(map['bankName']),
      last4Digits: JsonParsers.string(map['last4Digits']),
      colorHex: JsonParsers.string(map['colorHex'], fallback: '#1E3A8A'),
      limitInCents: JsonParsers.intValue(map['limitInCents']),
      cutoffDay: cutoff.clamp(1, 31),
      paymentDueDaysAfterCutoff: JsonParsers.intValue(
        map['paymentDueDaysAfterCutoff'],
        fallback: 10,
      ),
      currency: JsonParsers.string(map['currency'], fallback: 'TRY'),
      isActive: JsonParsers.boolValue(map['isActive'], fallback: true),
      createdAt: createdAt,
      updatedAt: JsonParsers.date(map['updatedAt'], fallback: createdAt),
    );
  }
}
