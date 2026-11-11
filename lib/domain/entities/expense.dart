import 'package:flutter/foundation.dart';

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
  final String? subCategory;
  final DateTime date;
  final String paymentMethod; // 'cash' | 'debit_card' | 'credit_card' | 'bank_transfer' | 'auto_payment' | 'other'
  final String? cardId;
  final String? cardLast4;
  final bool isInstallment;
  final String? installmentPlanId;
  final int installmentNumber;
  final int totalInstallments;
  final String statementPeriod; // 'YYYY-MM'
  final String? notes;
  final List<String> tags;
  final String? receiptUrl;
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
    this.subCategory,
    required this.date,
    required this.paymentMethod,
    this.cardId,
    this.cardLast4,
    this.isInstallment = false,
    this.installmentPlanId,
    this.installmentNumber = 1,
    this.totalInstallments = 1,
    required this.statementPeriod,
    this.notes,
    this.tags = const [],
    this.receiptUrl,
    this.status = 'active',
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.deletedBy,
  });

  Expense copyWith({
    String? id,
    String? teamId,
    String? ownerUid,
    String? visibility,
    String? title,
    int? amountInCents,
    String? currency,
    String? category,
    String? subCategory,
    DateTime? date,
    String? paymentMethod,
    String? cardId,
    String? cardLast4,
    bool? isInstallment,
    String? installmentPlanId,
    int? installmentNumber,
    int totalInstallments = 1,
    String? statementPeriod,
    String? notes,
    List<String>? tags,
    String? receiptUrl,
    String? status,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    String? deletedBy,
  }) {
    return Expense(
      id: id ?? this.id,
      teamId: teamId ?? this.teamId,
      ownerUid: ownerUid ?? this.ownerUid,
      visibility: visibility ?? this.visibility,
      title: title ?? this.title,
      amountInCents: amountInCents ?? this.amountInCents,
      currency: currency ?? this.currency,
      category: category ?? this.category,
      subCategory: subCategory ?? this.subCategory,
      date: date ?? this.date,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      cardId: cardId ?? this.cardId,
      cardLast4: cardLast4 ?? this.cardLast4,
      isInstallment: isInstallment ?? this.isInstallment,
      installmentPlanId: installmentPlanId ?? this.installmentPlanId,
      installmentNumber: installmentNumber ?? this.installmentNumber,
      totalInstallments: totalInstallments,
      statementPeriod: statementPeriod ?? this.statementPeriod,
      notes: notes ?? this.notes,
      tags: tags ?? this.tags,
      receiptUrl: receiptUrl ?? this.receiptUrl,
      status: status ?? this.status,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      deletedBy: deletedBy ?? this.deletedBy,
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
      'subCategory': subCategory,
      'date': date.toIso8601String(),
      'paymentMethod': paymentMethod,
      'cardId': cardId,
      'cardLast4': cardLast4,
      'isInstallment': isInstallment,
      'installmentPlanId': installmentPlanId,
      'installmentNumber': installmentNumber,
      'totalInstallments': totalInstallments,
      'statementPeriod': statementPeriod,
      'notes': notes,
      'tags': tags,
      'receiptUrl': receiptUrl,
      'status': status,
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'deletedAt': deletedAt?.toIso8601String(),
      'deletedBy': deletedBy,
    };
  }

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'] as String? ?? '',
      teamId: map['teamId'] as String?,
      ownerUid: map['ownerUid'] as String? ?? '',
      visibility: map['visibility'] as String? ?? 'personal',
      title: map['title'] as String? ?? '',
      amountInCents: map['amountInCents'] as int? ?? 0,
      currency: map['currency'] as String? ?? 'TRY',
      category: map['category'] as String? ?? 'other',
      subCategory: map['subCategory'] as String?,
      date: map['date'] != null ? DateTime.parse(map['date'].toString()) : DateTime.now(),
      paymentMethod: map['paymentMethod'] as String? ?? 'cash',
      cardId: map['cardId'] as String?,
      cardLast4: map['cardLast4'] as String?,
      isInstallment: map['isInstallment'] as bool? ?? false,
      installmentPlanId: map['installmentPlanId'] as String?,
      installmentNumber: map['installmentNumber'] as int? ?? 1,
      totalInstallments: map['totalInstallments'] as int? ?? 1,
      statementPeriod: map['statementPeriod'] as String? ?? '',
      notes: map['notes'] as String?,
      tags: List<String>.from(map['tags'] ?? []),
      receiptUrl: map['receiptUrl'] as String?,
      status: map['status'] as String? ?? 'active',
      createdBy: map['createdBy'] as String? ?? '',
      createdAt: map['createdAt'] != null ? DateTime.parse(map['createdAt'].toString()) : DateTime.now(),
      updatedAt: map['updatedAt'] != null ? DateTime.parse(map['updatedAt'].toString()) : DateTime.now(),
      deletedAt: map['deletedAt'] != null ? DateTime.parse(map['deletedAt'].toString()) : null,
      deletedBy: map['deletedBy'] as String?,
    );
  }
}
