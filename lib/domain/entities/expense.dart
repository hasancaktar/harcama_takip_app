import 'package:flutter/foundation.dart';

import '../../core/utils/json_parsers.dart';
import 'fuel.dart';

@immutable
class Expense {
  final String id;
  final String? teamId;
  final String ownerUid;
  final String visibility; // 'personal' | 'team'
  final String title;
  final int amountInCents;
  final String currency;
  final String category;
  final DateTime date;
  final String paymentMethod; // 'cash' | 'debit_card' | 'credit_card' | 'bank_transfer' | 'auto_payment' | 'other'
  final String? cardId;
  final String? cardLast4;
  final bool isInstallment;
  final String? installmentPlanId;
  final int installmentNumber;
  final int totalInstallments;

  /// Otomatik (her ay tekrarlanan) ödemeden oluşturulduysa ödemenin kimliği.
  final String? recurringPaymentId;

  /// Akaryakıt harcamasında litre, litre fiyatı, araç ve kilometre bilgisi.
  final FuelDetails? fuel;
  final String statementPeriod; // 'YYYY-MM'
  final String? notes;
  final List<String> tags;
  final String status; // 'active' | 'deleted'
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final String? deletedBy;

  const Expense({
    required this.id,
    this.teamId,
    required this.ownerUid,
    required this.visibility,
    required this.title,
    required this.amountInCents,
    this.currency = 'TRY',
    required this.category,
    required this.date,
    required this.paymentMethod,
    this.cardId,
    this.cardLast4,
    this.isInstallment = false,
    this.installmentPlanId,
    this.installmentNumber = 1,
    this.totalInstallments = 1,
    this.recurringPaymentId,
    this.fuel,
    required this.statementPeriod,
    this.notes,
    this.tags = const [],
    this.status = 'active',
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.deletedBy,
  });

  bool get isTeam => visibility == 'team';
  bool get isCreditCard => paymentMethod == 'credit_card';
  bool get isRecurring => recurringPaymentId != null;

  Expense copyWith({
    String? title,
    int? amountInCents,
    String? category,
    DateTime? date,
    String? paymentMethod,
    String? visibility,
    String? statementPeriod,
    DateTime? updatedAt,
    String? status,
  }) {
    return Expense(
      id: id,
      teamId: teamId,
      ownerUid: ownerUid,
      visibility: visibility ?? this.visibility,
      title: title ?? this.title,
      amountInCents: amountInCents ?? this.amountInCents,
      currency: currency,
      category: category ?? this.category,
      date: date ?? this.date,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      cardId: cardId,
      cardLast4: cardLast4,
      isInstallment: isInstallment,
      installmentPlanId: installmentPlanId,
      installmentNumber: installmentNumber,
      totalInstallments: totalInstallments,
      recurringPaymentId: recurringPaymentId,
      fuel: fuel,
      statementPeriod: statementPeriod ?? this.statementPeriod,
      notes: notes,
      tags: tags,
      status: status ?? this.status,
      createdBy: createdBy,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt,
      deletedBy: deletedBy,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'teamId': teamId,
      'ownerUid': ownerUid,
      'visibility': visibility,
      'title': title,
      'amountInCents': amountInCents,
      'currency': currency,
      'category': category,
      'date': date.toIso8601String(),
      'paymentMethod': paymentMethod,
      'cardId': cardId,
      'cardLast4': cardLast4,
      'isInstallment': isInstallment,
      'installmentPlanId': installmentPlanId,
      'installmentNumber': installmentNumber,
      'totalInstallments': totalInstallments,
      'recurringPaymentId': recurringPaymentId,
      'fuel': fuel?.toMap(),
      'statementPeriod': statementPeriod,
      'notes': notes,
      'tags': tags,
      'status': status,
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'deletedAt': deletedAt?.toIso8601String(),
      'deletedBy': deletedBy,
    };
  }

  factory Expense.fromMap(Map<String, dynamic> map) {
    final createdAt = JsonParsers.date(
      map['createdAt'],
      fallback: DateTime.now(),
    );
    return Expense(
      id: JsonParsers.string(map['id']),
      teamId: JsonParsers.stringOrNull(map['teamId']),
      ownerUid: JsonParsers.string(map['ownerUid']),
      visibility: JsonParsers.string(map['visibility'], fallback: 'personal'),
      title: JsonParsers.string(map['title']),
      amountInCents: JsonParsers.intValue(map['amountInCents']),
      currency: JsonParsers.string(map['currency'], fallback: 'TRY'),
      category: JsonParsers.string(map['category'], fallback: 'other'),
      date: JsonParsers.date(map['date'], fallback: createdAt),
      paymentMethod: JsonParsers.string(map['paymentMethod'], fallback: 'cash'),
      cardId: JsonParsers.stringOrNull(map['cardId']),
      cardLast4: JsonParsers.stringOrNull(map['cardLast4']),
      isInstallment: JsonParsers.boolValue(map['isInstallment']),
      installmentPlanId: JsonParsers.stringOrNull(map['installmentPlanId']),
      installmentNumber: JsonParsers.intValue(
        map['installmentNumber'],
        fallback: 1,
      ),
      totalInstallments: JsonParsers.intValue(
        map['totalInstallments'],
        fallback: 1,
      ),
      recurringPaymentId: JsonParsers.stringOrNull(map['recurringPaymentId']),
      fuel: FuelDetails.fromMap(map['fuel']),
      statementPeriod: JsonParsers.string(map['statementPeriod']),
      notes: JsonParsers.stringOrNull(map['notes']),
      tags: JsonParsers.stringList(map['tags']),
      status: JsonParsers.string(map['status'], fallback: 'active'),
      createdBy: JsonParsers.string(map['createdBy']),
      createdAt: createdAt,
      updatedAt: JsonParsers.date(map['updatedAt'], fallback: createdAt),
      deletedAt: JsonParsers.dateOrNull(map['deletedAt']),
      deletedBy: JsonParsers.stringOrNull(map['deletedBy']),
    );
  }
}
