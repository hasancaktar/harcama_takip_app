import 'package:flutter/foundation.dart';

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
  final int paymentDueDaysAfterCutoff; // örn: 10 gün
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

  CreditCard copyWith({
    String? id,
    String? ownerUid,
    String? teamId,
    bool? isSharedWithTeam,
    String? name,
    String? bankName,
    String? last4Digits,
    String? colorHex,
    int? limitInCents,
    int? cutoffDay,
    int? paymentDueDaysAfterCutoff,
    String? currency,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CreditCard(
      id: id ?? this.id,
      ownerUid: ownerUid ?? this.ownerUid,
      teamId: teamId ?? this.teamId,
      isSharedWithTeam: isSharedWithTeam ?? this.isSharedWithTeam,
      name: name ?? this.name,
      bankName: bankName ?? this.bankName,
      last4Digits: last4Digits ?? this.last4Digits,
      colorHex: colorHex ?? this.colorHex,
      limitInCents: limitInCents ?? this.limitInCents,
      cutoffDay: cutoffDay ?? this.cutoffDay,
      paymentDueDaysAfterCutoff: paymentDueDaysAfterCutoff ?? this.paymentDueDaysAfterCutoff,
      currency: currency ?? this.currency,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

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
    return CreditCard(
      id: map['id'] as String? ?? '',
      ownerUid: map['ownerUid'] as String? ?? '',
      teamId: map['teamId'] as String?,
      isSharedWithTeam: map['isSharedWithTeam'] as bool? ?? false,
      name: map['name'] as String? ?? '',
      bankName: map['bankName'] as String? ?? '',
      last4Digits: map['last4Digits'] as String? ?? '',
      colorHex: map['colorHex'] as String? ?? '#1E3A8A',
      limitInCents: map['limitInCents'] as int? ?? 0,
      cutoffDay: map['cutoffDay'] as int? ?? 1,
      paymentDueDaysAfterCutoff: map['paymentDueDaysAfterCutoff'] as int? ?? 10,
      currency: map['currency'] as String? ?? 'TRY',
      isActive: map['isActive'] as bool? ?? true,
      createdAt: map['createdAt'] != null ? DateTime.parse(map['createdAt'].toString()) : DateTime.now(),
      updatedAt: map['updatedAt'] != null ? DateTime.parse(map['updatedAt'].toString()) : DateTime.now(),
    );
  }
}
