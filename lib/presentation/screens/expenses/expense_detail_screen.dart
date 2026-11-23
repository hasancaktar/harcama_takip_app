import 'package:harcama_takip/core/l10n/app_locale.dart';
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
import '../../../domain/entities/fuel.dart';
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
      title: 'Harcama silinsin mi?'.tr,
      message: '"{0}" ({1}) kaydı silinecek.'.trArgs([
        expense.title,
        MoneyFormatter.formatCents(expense.amountInCents),
      ]),
      confirmLabel: 'Sil'.tr,
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
        context.showSuccess('Harcama silindi.'.tr);
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
        title: Text('Harcama detayı'.tr),
        actions: [
          if (canEdit)
            IconButton(
              tooltip: 'Düzenle'.tr,
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => context.push('/expenses/$expenseId/edit'),
            ),
          if (canDelete)
            IconButton(
              tooltip: 'Sil'.tr,
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
            return EmptyStateView(
              icon: Icons.search_off_rounded,
              title: 'Harcama bulunamadı'.tr,
              message: 'Bu kayıt silinmiş veya görüntüleme yetkiniz yok.'.tr,
            );
          }
          final payment = AppConstants.getPaymentMethod(expense.paymentMethod);
          final owner = expense.ownerUid == uid
              ? 'Siz'.tr
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
                      label: 'Tarih'.tr,
                      value: DateFormats.dayTime(expense.date),
                    ),
                    _DetailRow(
                      icon: payment.icon,
                      label: 'Ödeme'.tr,
                      value: payment.name,
                    ),
                    if (expense.cardLast4 != null)
                      _DetailRow(
                        icon: Icons.credit_card_rounded,
                        label: 'Kart'.tr,
                        value: '•••• ${expense.cardLast4}',
                      ),
                    _DetailRow(
                      icon: Icons.receipt_rounded,
                      label: expense.isCreditCard
                          ? 'Ekstre dönemi'.tr
                          : 'Dönem'.tr,
                      value: DateFormats.period(expense.statementPeriod),
                    ),
                    _DetailRow(
                      icon: expense.isTeam
                          ? Icons.groups_rounded
                          : Icons.person_rounded,
                      label: 'Görünürlük'.tr,
                      value: expense.isTeam
                          ? 'Takım harcaması'.tr
                          : 'Bireysel'.tr,
                    ),
                    if (expense.isTeam && owner != null)
                      _DetailRow(
                        icon: Icons.badge_outlined,
                        label: 'Ekleyen'.tr,
                        value: owner,
                      ),
                    if (expense.isInstallment)
                      _DetailRow(
                        icon: Icons.splitscreen_rounded,
                        label: 'Taksit'.tr,
                        value:
                            '${expense.installmentNumber} / ${expense.totalInstallments}',
                      ),
                    if (expense.fuel case final fuel?) ...[
                      if (fuel.vehicleName != null)
                        _DetailRow(
                          icon: Icons.directions_car_rounded,
                          label: 'Araç'.tr,
                          value: fuel.vehicleName!,
                        ),
                      _DetailRow(
                        icon: Icons.local_gas_station_rounded,
                        label: 'Yakıt'.tr,
                        value: fuel.hasVolume
                            ? '${FuelTypes.label(fuel.fuelType)} · '
                                  '${FuelMath.formatLiters(fuel.litersX100)}'
                            : FuelTypes.label(fuel.fuelType),
                      ),
                      if (fuel.pricePerLiterCents > 0)
                        _DetailRow(
                          icon: Icons.sell_rounded,
                          label: 'Litre fiyatı'.tr,
                          value: MoneyFormatter.formatCents(
                            fuel.pricePerLiterCents,
                          ),
                        ),
                      if (fuel.odometerKm != null)
                        _DetailRow(
                          icon: Icons.speed_rounded,
                          label: 'Kilometre'.tr,
                          value: FuelMath.formatKm(fuel.odometerKm!),
                        ),
                      _DetailRow(
                        icon: Icons.water_drop_rounded,
                        label: 'Dolum'.tr,
                        value: fuel.fullTank
                            ? 'Depo full'.tr
                            : 'Kısmi dolum'.tr,
                      ),
                    ],
                    if (expense.notes != null)
                      _DetailRow(
                        icon: Icons.notes_rounded,
                        label: 'Not'.tr,
                        value: expense.notes!,
                        multiline: true,
                      ),
                  ],
                ),
              ),
              if (expense.fuel != null && expense.ownerUid == uid) ...[
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: 'Yakıt özetini aç'.tr,
                  outlined: true,
                  icon: Icons.local_gas_station_rounded,
                  onPressed: () => context.push('/fuel'),
                ),
              ],
              if (expense.isInstallment &&
                  expense.installmentPlanId != null) ...[
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: 'Taksit planını görüntüle'.tr,
                  outlined: true,
                  icon: Icons.splitscreen_rounded,
                  onPressed: () => context.push(
                    '/installments/${expense.installmentPlanId}',
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              Text(
                'Son güncelleme: {0}'.trArgs([
                  DateFormats.dayTime(expense.updatedAt),
                ]),
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
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.4,
              ),
              child: Text(
                label,
                style: context.textStyles.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
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
