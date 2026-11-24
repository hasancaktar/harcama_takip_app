import 'package:flutter/foundation.dart';

import '../../core/utils/json_parsers.dart';

/// Banka kartı (vadesiz hesaba bağlı). Kredi kartından farklı olarak kesim ve
/// son ödeme günü yoktur; harcamalar yapıldığı aya yazılır. Yalnızca sahibine
/// görünür. Kredi kartlarından ayrı koleksiyonda (`debitCards`) tutulur ki eski
/// uygulama sürümleri bunları kredi kartı sanmasın.
@immutable
class DebitCard {
  final String id;
  final String ownerUid;
  final String name;
  final String bankName;
  final String last4Digits;
  final String colorHex;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const DebitCard({
    required this.id,
    required this.ownerUid,
    required this.name,
    required this.bankName,
    required this.last4Digits,
    this.colorHex = '#0F766E',
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  String get displayName => '$name •••• $last4Digits';

  Map<String, dynamic> toMap() => {
    'id': id,
    'ownerUid': ownerUid,
    'name': name,
    'bankName': bankName,
    'last4Digits': last4Digits,
    'colorHex': colorHex,
    'isActive': isActive,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory DebitCard.fromMap(Map<String, dynamic> map) {
    final createdAt = JsonParsers.date(
      map['createdAt'],
      fallback: DateTime.now(),
    );
    return DebitCard(
      id: JsonParsers.string(map['id']),
      ownerUid: JsonParsers.string(map['ownerUid']),
      name: JsonParsers.string(map['name']),
      bankName: JsonParsers.string(map['bankName']),
      last4Digits: JsonParsers.string(map['last4Digits']),
      colorHex: JsonParsers.string(map['colorHex'], fallback: '#0F766E'),
      isActive: JsonParsers.boolValue(map['isActive'], fallback: true),
      createdAt: createdAt,
      updatedAt: JsonParsers.date(map['updatedAt'], fallback: createdAt),
    );
  }
}
