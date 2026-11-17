import 'package:harcama_takip/core/l10n/app_locale.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers/auth_providers.dart';
import '../../../application/providers/installment_providers.dart';
import '../../../application/providers/repository_providers.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_formats.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../domain/entities/installment_plan.dart';
import '../../widgets/app_card.dart';
import '../../widgets/category_badge.dart';
import '../../widgets/common.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/state_views.dart';

class InstallmentPlanDetailScreen extends ConsumerWidget {
  final String planId;
  const InstallmentPlanDetailScreen({super.key, required this.planId});

  Future<void> _cancel(
    BuildContext context,
    WidgetRef ref,
    InstallmentPlan plan,
  ) async {
    final now = DateTime.now();
    final upcoming = plan.upcomingAt(now);
    final ok = await showConfirmDialog(
      context,
      title: 'Taksit planı iptal edilsin mi?'.tr,
      message: 'Henüz ekstreye yansımamış {0} taksit ({1}) gelecek ayların harcamalarından kaldırılacak. Bu aya kadar yansıyan taksitler korunur. Bu işlem geri alınamaz.'
          .trArgs([
            upcoming.length,
            MoneyFormatter.formatCents(plan.remainingAmountAt(now)),
          ]),
      confirmLabel: 'Planı iptal et'.tr,
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    try {
      final uid = ref.read(currentUserIdProvider);
      if (uid == null) return;
      await ref
          .read(installmentRepositoryProvider)
          .cancelPlan(plan, actorUid: uid, now: now);
      if (context.mounted) context.showSuccess('Taksit planı iptal edildi.'.tr);
    } catch (e) {
      if (context.mounted) context.showError(e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planAsync = ref.watch(installmentPlanByIdProvider(planId));
    final uid = ref.watch(currentUserIdProvider);
    final scheme = context.colors;

    return Scaffold(
      appBar: AppBar(title: Text('Taksit planı'.tr)),
      body: AsyncValueView<InstallmentPlan?>(
        value: planAsync,
        onRetry: () => ref.invalidate(installmentPlanByIdProvider(planId)),
        data: (plan) {
          if (plan == null) {
            return EmptyStateView(
              icon: Icons.search_off_rounded,
              title: 'Plan bulunamadı'.tr,
              message: 'Plan silinmiş veya görüntüleme yetkiniz yok.'.tr,
            );
          }
          final now = DateTime.now();
          final canCancel =
              plan.displayStatusAt(now) == 'active' && plan.ownerUid == uid;
          final paid = plan.billedAmountAt(now);
          final remaining = plan.remainingAmountAt(now);
          return PageListView(
            maxWidth: AppSpacing.maxFormWidth,
            children: [
              const SizedBox(height: AppSpacing.sm),
              Center(child: CategoryBadge(categoryId: plan.category)),
              const SizedBox(height: AppSpacing.sm),
              Text(
                plan.title,
                textAlign: TextAlign.center,
                style: context.textStyles.headlineSmall,
              ),
              Text(
                '{0} · {1} taksit · •••• {2}'.trArgs([
                  MoneyFormatter.formatCents(plan.totalAmountInCents),
                  plan.totalInstallments,
                  plan.cardLast4,
                ]),
                textAlign: TextAlign.center,
                style: context.textStyles.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    UsageBar(
                      ratio: plan.totalAmountInCents == 0
                          ? 0
                          : paid / plan.totalAmountInCents,
                      semanticsLabel: 'Ödeme ilerlemesi'.tr,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Expanded(
                          child: _Kpi(
                            label: 'İşlenen'.tr,
                            value: MoneyFormatter.formatCents(paid),
                          ),
                        ),
                        Expanded(
                          child: _Kpi(
                            label: 'Kalan'.tr,
                            value: MoneyFormatter.formatCents(remaining),
                          ),
                        ),
                        Expanded(
                          child: _Kpi(
                            label: 'Taksit'.tr,
                            value:
                                '${plan.billedCountAt(now)}/${plan.totalInstallments}',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (plan.status == 'cancelled') ...[
                const SizedBox(height: AppSpacing.md),
                InlineMessage(
                  tone: MessageTone.warning,
                  message: 'Bu plan iptal edildi. Ekstreye yansımamış taksitler harcamalardan kaldırıldı.'
                      .tr,
                ),
              ],
              SectionHeader(title: 'Ödeme takvimi'.tr),
              AppCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                child: Column(
                  children: [
                    for (final item in plan.installmentSchedule)
                      if (InstallmentPlan.isBilledAt(item, now) ||
                          plan.isActive ||
                          item.isPosted)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.xs,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                InstallmentPlan.isBilledAt(item, now)
                                    ? Icons.check_circle_rounded
                                    : Icons.radio_button_unchecked_rounded,
                                size: 20,
                                color: InstallmentPlan.isBilledAt(item, now)
                                    ? context.semantic.success
                                    : scheme.outline,
                                semanticLabel:
                                    InstallmentPlan.isBilledAt(item, now)
                                    ? 'İşlendi'.tr
                                    : 'Bekliyor'.tr,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '{0}. taksit · {1}'.trArgs([
                                        item.installmentNumber,
                                        DateFormats.period(
                                          item.statementPeriod,
                                        ),
                                      ]),
                                      style: context.textStyles.titleSmall,
                                    ),
                                    Text(
                                      'Son ödeme {0}'.trArgs([
                                        DateFormats.day(item.dueDate),
                                      ]),
                                      style: context.textStyles.bodySmall
                                          ?.copyWith(
                                            color: scheme.onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                MoneyFormatter.formatCents(item.amountInCents),
                                style: context.textStyles.titleSmall,
                              ),
                            ],
                          ),
                        ),
                  ],
                ),
              ),
              if (canCancel) ...[
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  label: 'Planı iptal et'.tr,
                  outlined: true,
                  destructive: true,
                  icon: Icons.block_rounded,
                  onPressed: () => _cancel(context, ref, plan),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _Kpi extends StatelessWidget {
  final String label;
  final String value;
  const _Kpi({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: context.textStyles.labelMedium?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(value, style: context.textStyles.titleSmall),
        ),
      ],
    );
  }
}
