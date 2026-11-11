import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../application/providers/card_providers.dart';
import '../../../application/providers/expense_providers.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/utils/statement_calculator.dart';
import '../../widgets/app_card.dart';
import '../../widgets/category_badge.dart';

class CardStatementDetailScreen extends ConsumerWidget {
  final String cardId;

  const CardStatementDetailScreen({super.key, required this.cardId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cards = ref.watch(creditCardsProvider).value ?? [];
    final currentPeriod = ref.watch(selectedPeriodProvider);
    final expenses = ref.watch(expensesStreamProvider).value ?? [];

    final card = cards.firstWhere(
      (c) => c.id == cardId,
      orElse: () => cards.isNotEmpty ? cards.first : throw Exception('Kart bulunamadı'),
    );

    final cardColor = Color(int.parse(card.colorHex.replaceFirst('#', '0xFF')));

    // Bu karta ve seçili ekstre dönemine ait harcamalar
    final cardExpenses = expenses.where((e) => e.cardId == card.id).toList();
    final statementTotalCents = cardExpenses.fold<int>(0, (sum, e) => sum + e.amountInCents);

    // Son ödeme tarihi hesabı
    final dueDate = StatementCalculator.calculateDueDate(
      statementPeriod: currentPeriod,
      cutoffDay: card.cutoffDay,
      paymentDueDaysAfterCutoff: card.paymentDueDaysAfterCutoff,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(card.name),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Kart Başlık Kartviziti
          AppCard(
            color: cardColor,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      card.bankName,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const Icon(Icons.contactless_rounded, color: Colors.white70),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  '•••• •••• •••• ${card.last4Digits}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      card.name,
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    Text(
                      'Kesim: ${card.cutoffDay}. gün',
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Seçili Ekstre Özeti
          AppCard(
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Dönem: $currentPeriod', style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(
                      'Son Ödeme: ${DateFormat('d MMMM yyyy', 'tr_TR').format(dueDate)}',
                      style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Dönem Borcu:', style: TextStyle(fontSize: 14)),
                    Text(
                      MoneyFormatter.formatCents(statementTotalCents),
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Ekstre Harcamaları
          Text(
            'Bu Ekstrenin Harcamaları',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          if (cardExpenses.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Bu ekstre döneminde bu karta ait harcama bulunmamaktadır.'),
              ),
            )
          else
            ...cardExpenses.map((exp) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AppCard(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      CategoryBadge(categoryId: exp.category, showLabel: false),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(exp.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            Text(
                              DateFormat('d MMMM yyyy, HH:mm', 'tr_TR').format(exp.date),
                              style: TextStyle(fontSize: 11, color: theme.hintColor),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        MoneyFormatter.formatCents(exp.amountInCents),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
