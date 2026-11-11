import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../application/providers/auth_providers.dart';
import '../../../application/providers/repository_providers.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../domain/entities/expense.dart';
import '../../widgets/app_card.dart';
import '../../widgets/category_badge.dart';
import '../../widgets/loading_indicator.dart';

class ExpenseDetailScreen extends ConsumerWidget {
  final String expenseId;

  const ExpenseDetailScreen({super.key, required this.expenseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final expenseRepo = ref.watch(expenseRepositoryProvider);
    final uid = ref.watch(currentUserIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Harcama Detayı'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Harcamayı Sil'),
                  content: const Text('Bu harcamayı silmek istediğinizden emin misiniz?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                      child: const Text('Sil'),
                    ),
                  ],
                ),
              );

              if (confirm == true && uid != null) {
                await expenseRepo.softDeleteExpense(expenseId, uid);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Harcama silindi.')),
                  );
                  context.pop();
                }
              }
            },
          ),
        ],
      ),
      body: FutureBuilder<Expense?>(
        future: expenseRepo.getExpenseById(expenseId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingIndicator();
          }

          final expense = snapshot.data;
          if (expense == null) {
            return const Center(child: Text('Harcama kaydı bulunamadı.'));
          }

          final paymentName = AppConstants.paymentMethods[expense.paymentMethod] ?? 'Diğer';

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Tutar ve Kategori Başlığı
              Center(
                child: Column(
                  children: [
                    CategoryBadge(categoryId: expense.category, showLabel: true),
                    const SizedBox(height: 12),
                    Text(
                      expense.title,
                      style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      MoneyFormatter.formatCents(expense.amountInCents, currency: expense.currency),
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Detay Kartı
              AppCard(
                child: Column(
                  children: [
                    _DetailRow(
                      icon: Icons.calendar_today_rounded,
                      label: 'Tarih',
                      value: DateFormat('d MMMM yyyy, HH:mm', 'tr_TR').format(expense.date),
                    ),
                    const Divider(),
                    _DetailRow(
                      icon: Icons.groups_rounded,
                      label: 'Görünürlük',
                      value: expense.visibility == 'team' ? 'Takım Harcaması' : 'Bireysel Harcama',
                    ),
                    const Divider(),
                    _DetailRow(
                      icon: Icons.payment_rounded,
                      label: 'Ödeme Yöntemi',
                      value: paymentName,
                    ),
                    if (expense.cardLast4 != null) ...[
                      const Divider(),
                      _DetailRow(
                        icon: Icons.credit_card_rounded,
                        label: 'Kart',
                        value: '•••• ${expense.cardLast4}',
                      ),
                    ],
                    const Divider(),
                    _DetailRow(
                      icon: Icons.receipt_rounded,
                      label: 'Ekstre Dönemi',
                      value: expense.statementPeriod,
                    ),
                    if (expense.isInstallment) ...[
                      const Divider(),
                      _DetailRow(
                        icon: Icons.splitscreen_rounded,
                        label: 'Taksit Durumu',
                        value: '${expense.installmentNumber}. / ${expense.totalInstallments} Taksit',
                      ),
                    ],
                    if (expense.notes != null) ...[
                      const Divider(),
                      _DetailRow(
                        icon: Icons.notes_rounded,
                        label: 'Not',
                        value: expense.notes!,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).hintColor),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }
}
