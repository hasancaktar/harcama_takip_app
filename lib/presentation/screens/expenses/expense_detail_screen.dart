import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers/auth_providers.dart';
import '../../../application/providers/expense_providers.dart';
import '../../../application/providers/repository_providers.dart';
import '../../../application/providers/team_providers.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_formats.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../domain/entities/expense.dart';
import '../../widgets/app_card.dart';
import '../../widgets/category_badge.dart';
import '../../widgets/common.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/state_views.dart';

class ExpenseDetailScreen extends ConsumerWidget {
  final String expenseId;

  const ExpenseDetailScreen({super.key, required this.expenseId});

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    Expense expense,
  ) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Harcama silinsin mi?',
      message:
          '"${expense.title}" (${MoneyFormatter.formatCents(expense.amountInCents)}) kaydı silinecek.',
      confirmLabel: 'Sil',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
    final uid = ref.read(currentUserIdProvider);
    if (uid == null) return;
    try {
      await ref
          .read(expenseRepositoryProvider)
          .softDeleteExpense(expense.id, uid);
      if (context.mounted) {
        context.showSuccess('Harcama silindi.');
        context.canPop() ? context.pop() : context.go('/expenses');
      }
    } catch (e) {
      if (context.mounted) context.showError(e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expenseAsync = ref.watch(expenseByIdProvider(expenseId));
    final uid = ref.watch(currentUserIdProvider);
    final memberNames = ref.watch(memberNamesProvider);

    final expense = expenseAsync.valueOrNull;
    final canEdit =
        expense != null && expense.ownerUid == uid && !expense.isInstallment;
    final canDelete = expense != null && expense.ownerUid == uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Harcama detayı'),
        actions: [
          if (canEdit)
            IconButton(
              tooltip: 'Düzenle',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => context.push('/expenses/$expenseId/edit'),
            ),
          if (canDelete)
            IconButton(
              tooltip: 'Sil',
              icon: Icon(
                Icons.delete_outline_rounded,
                color: context.colors.error,
              ),
              onPressed: () => _delete(context, ref, expense),
            ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: AsyncValueView<Expense?>(
        value: expenseAsync,
        onRetry: () => ref.invalidate(expenseByIdProvider(expenseId)),
        data: (expense) {
          if (expense == null) {
            return const EmptyStateView(
              icon: Icons.search_off_rounded,
              title: 'Harcama bulunamadı',
              message: 'Bu kayıt silinmiş veya görüntüleme yetkiniz yok.',
            );
          }
          final payment = AppConstants.getPaymentMethod(expense.paymentMethod);
          final owner = expense.ownerUid == uid
              ? 'Siz'
              : memberNames[expense.ownerUid];
          return PageListView(
            maxWidth: AppSpacing.maxFormWidth,
            children: [
              const SizedBox(height: AppSpacing.md),
              Center(child: CategoryBadge(categoryId: expense.category)),
              const SizedBox(height: AppSpacing.md),
              Text(
                expense.title,
                style: context.textStyles.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                MoneyFormatter.formatCents(
                  expense.amountInCents,
                  currency: expense.currency,
                ),
                textAlign: TextAlign.center,
                style: context.textStyles.displaySmall?.copyWith(
                  color: context.colors.primary,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                child: Column(
                  children: [
                    _DetailRow(
                      icon: Icons.event_rounded,
                      label: 'Tarih',
                      value: DateFormats.dayTime(expense.date),
                    ),
                    _DetailRow(
                      icon: payment.icon,
                      label: 'Ödeme',
                      value: payment.name,
                    ),
                    if (expense.cardLast4 != null)
                      _DetailRow(
                        icon: Icons.credit_card_rounded,
                        label: 'Kart',
                        value: '•••• ${expense.cardLast4}',
                      ),
                    _DetailRow(
                      icon: Icons.receipt_rounded,
                      label: expense.isCreditCard ? 'Ekstre dönemi' : 'Dönem',
                      value: DateFormats.period(expense.statementPeriod),
                    ),
                    _DetailRow(
                      icon: expense.isTeam
                          ? Icons.groups_rounded
                          : Icons.person_rounded,
                      label: 'Görünürlük',
                      value: expense.isTeam ? 'Takım harcaması' : 'Bireysel',
                    ),
                    if (expense.isTeam && owner != null)
                      _DetailRow(
                        icon: Icons.badge_outlined,
                        label: 'Ekleyen',
                        value: owner,
                      ),
                    if (expense.isInstallment)
                      _DetailRow(
                        icon: Icons.splitscreen_rounded,
                        label: 'Taksit',
                        value:
                            '${expense.installmentNumber} / ${expense.totalInstallments}',
                      ),
                    if (expense.notes != null)
                      _DetailRow(
                        icon: Icons.notes_rounded,
                        label: 'Not',
                        value: expense.notes!,
                        multiline: true,
                      ),
                  ],
                ),
              ),
              if (expense.isInstallment &&
                  expense.installmentPlanId != null) ...[
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: 'Taksit planını görüntüle',
                  outlined: true,
                  icon: Icons.splitscreen_rounded,
                  onPressed: () => context.push(
                    '/installments/${expense.installmentPlanId}',
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              Text(
                'Son güncelleme: ${DateFormats.dayTime(expense.updatedAt)}',
                textAlign: TextAlign.center,
                style: context.textStyles.bodySmall?.copyWith(
                  color: context.colors.onSurfaceVariant,
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
  final bool multiline;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.multiline = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: multiline
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: scheme.onSurfaceVariant),
            const SizedBox(width: AppSpacing.sm),
            Text(
              label,
              style: context.textStyles.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: context.textStyles.titleSmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
