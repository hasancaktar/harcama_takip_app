import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers/auth_providers.dart';
import '../../../application/providers/card_providers.dart';
import '../../../application/providers/installment_providers.dart';
import '../../../application/providers/team_providers.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_formats.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/utils/statement_calculator.dart';
import '../../../domain/entities/credit_card.dart';
import '../../../domain/entities/installment_plan.dart';
import '../../widgets/app_card.dart';
import '../../widgets/common.dart';
import '../../widgets/credit_card_visual.dart';
import '../../widgets/state_views.dart';
import '../../widgets/workspace_selector.dart';

class CardsInstallmentsScreen extends ConsumerStatefulWidget {
  final int initialTab;
  const CardsInstallmentsScreen({super.key, this.initialTab = 0});

  @override
  ConsumerState<CardsInstallmentsScreen> createState() =>
      _CardsInstallmentsScreenState();
}

class _CardsInstallmentsScreenState
    extends ConsumerState<CardsInstallmentsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(
    length: 2,
    vsync: this,
    initialIndex: widget.initialTab,
  )..addListener(_onTab);

  void _onTab() {
    if (!_tabController.indexIsChanging) setState(() {});
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final onCards = _tabController.index == 0;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kartlar ve taksitler'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Kredi kartları'),
            Tab(text: 'Taksit planları'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            context.push(onCards ? '/cards/new' : '/installments/new'),
        icon: Icon(
          onCards ? Icons.add_card_rounded : Icons.playlist_add_rounded,
        ),
        label: Text(onCards ? 'Kart ekle' : 'Taksit ekle'),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [_CardsTab(), _InstallmentsTab()],
      ),
    );
  }
}

class _CardsTab extends ConsumerWidget {
  const _CardsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardsAsync = ref.watch(availableCardsProvider);
    final uid = ref.watch(currentUserIdProvider);
    final isTeam = ref.watch(activeTeamProvider) != null;

    return AsyncValueView<List<CreditCard>>(
      value: cardsAsync,
      loading: const SkeletonList(itemCount: 3, itemHeight: 180),
      onRetry: () => ref.invalidate(availableCardsProvider),
      data: (cards) {
        if (cards.isEmpty) {
          return EmptyStateView(
            icon: Icons.credit_card_off_rounded,
            title: 'Henüz kart eklemediniz',
            message: 'Kartınızın kesim gününü girin; harcamalar doğru ekstreye yazılsın, son ödeme tarihini kaçırmayın. Kart numarası istenmez.',
            actionLabel: 'Kart ekle',
            actionIcon: Icons.add_card_rounded,
            onAction: () => context.push('/cards/new'),
          );
        }
        final now = DateTime.now();
        return PageListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            96,
          ),
          children: [
            if (isTeam) ...[
              const Align(
                alignment: Alignment.centerLeft,
                child: WorkspaceSelector(),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            for (final card in cards) ...[
              Builder(
                builder: (context) {
                  final cutoff = StatementCalculator.nextCutoffDate(
                    now,
                    card.cutoffDay,
                  );
                  final due = StatementCalculator.calculateDueDate(
                    statementPeriod: StatementCalculator.periodOf(cutoff),
                    cutoffDay: card.cutoffDay,
                    paymentDueDaysAfterCutoff: card.paymentDueDaysAfterCutoff,
                  );
                  return CreditCardVisual(
                    card: card,
                    onTap: () => context.push('/cards/${card.id}'),
                    footer: Text(
                      [
                        'Sonraki kesim ${DateFormats.dayShort(cutoff)} (${DateFormats.daysUntil(cutoff, now: now)})',
                        'Son ödeme ${DateFormats.dayShort(due)}',
                        if (card.ownerUid != uid) 'Takım kartı',
                      ].join(' · '),
                      style: context.textStyles.bodySmall?.copyWith(
                        color: DefaultTextStyle.of(context).style.color
                            ?.withValues(alpha: 0.85),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ],
        );
      },
    );
  }
}

class _InstallmentsTab extends ConsumerWidget {
  const _InstallmentsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plansAsync = ref.watch(installmentPlansProvider);

    return AsyncValueView<List<InstallmentPlan>>(
      value: plansAsync,
      loading: const SkeletonList(itemCount: 4, itemHeight: 120),
      onRetry: () => ref.invalidate(installmentPlansProvider),
      data: (plans) {
        if (plans.isEmpty) {
          return EmptyStateView(
            icon: Icons.splitscreen_rounded,
            title: 'Taksit planı yok',
            message: 'Taksitli alışverişlerinizi ekleyin; her ay ilgili ekstreye otomatik yazılsın, kalan borcunuzu görün.',
            actionLabel: 'Taksit planı ekle',
            actionIcon: Icons.playlist_add_rounded,
            onAction: () => context.push('/installments/new'),
          );
        }
        final active = plans.where((p) => p.isActive).toList();
        final other = plans.where((p) => !p.isActive).toList();
        final remaining = active.fold<int>(
          0,
          (s, p) => s + p.remainingAmountInCents,
        );
        final monthly = active.fold<int>(
          0,
          (s, p) => s + (p.nextInstallment?.amountInCents ?? 0),
        );

        return PageListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            96,
          ),
          children: [
            if (active.isNotEmpty)
              Row(
                children: [
                  Expanded(
                    child: _MiniStat(
                      label: 'Kalan taksit borcu',
                      value: MoneyFormatter.formatCents(remaining),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _MiniStat(
                      label: 'Sonraki ay yükü',
                      value: MoneyFormatter.formatCents(monthly),
                    ),
                  ),
                ],
              ),
            if (active.isNotEmpty) const SectionHeader(title: 'Devam eden'),
            for (final p in active) ...[
              _PlanCard(plan: p),
              const SizedBox(height: AppSpacing.sm),
            ],
            if (other.isNotEmpty)
              const SectionHeader(title: 'Tamamlanan ve iptal edilen'),
            for (final p in other) ...[
              _PlanCard(plan: p),
              const SizedBox(height: AppSpacing.sm),
            ],
          ],
        );
      },
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.sm + 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: context.textStyles.labelMedium?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: context.textStyles.titleMedium),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final InstallmentPlan plan;
  const _PlanCard({required this.plan});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final next = plan.nextInstallment;
    final progress = plan.totalInstallments == 0
        ? 0.0
        : plan.postedCount / plan.totalInstallments;
    final (String statusLabel, Color statusColor) = switch (plan.status) {
      'active' => ('Devam ediyor', scheme.primary),
      'completed' => ('Tamamlandı', context.semantic.success),
      _ => ('İptal edildi', scheme.onSurfaceVariant),
    };

    return AppCard(
      onTap: () => context.push('/installments/${plan.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CategoryIcon(categoryId: plan.category, size: 36),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textStyles.titleSmall,
                    ),
                    Text(
                      '•••• ${plan.cardLast4} · ${plan.totalInstallments} taksit',
                      style: context.textStyles.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                MoneyFormatter.formatCents(plan.totalAmountInCents),
                style: context.textStyles.titleSmall,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          UsageBar(
            ratio: progress,
            color: statusColor,
            height: 6,
            semanticsLabel: 'Ödenen taksit oranı',
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Expanded(
                child: Text(
                  next != null && plan.isActive
                      ? '${plan.postedCount}/${plan.totalInstallments} · sıradaki ${MoneyFormatter.formatCents(next.amountInCents)} (${DateFormats.periodShort(next.statementPeriod)})'
                      : '${plan.postedCount}/${plan.totalInstallments} taksit işlendi',
                  style: context.textStyles.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              Pill(label: statusLabel, color: statusColor),
            ],
          ),
        ],
      ),
    );
  }
}
