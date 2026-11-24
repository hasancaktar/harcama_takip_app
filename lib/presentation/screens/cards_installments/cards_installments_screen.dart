import 'package:harcama_takip/core/l10n/app_locale.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers/auth_providers.dart';
import '../../../application/providers/card_providers.dart';
import '../../../application/providers/installment_providers.dart';
import '../../../application/providers/recurring_payment_providers.dart';
import '../../../application/providers/team_providers.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_formats.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/utils/statement_calculator.dart';
import '../../../domain/entities/credit_card.dart';
import '../../../domain/entities/installment_plan.dart';
import '../../../domain/entities/recurring_payment.dart';
import 'recurring_payment_detail_screen.dart' show recurringScheduleLabel;
import '../../widgets/app_card.dart';
import '../../widgets/common.dart';
import '../../widgets/credit_card_visual.dart';
import '../../widgets/state_views.dart';
import 'debit_card_screens.dart';
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
    length: 3,
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
    final (
      String route,
      IconData icon,
      String label,
    ) = switch (_tabController.index) {
      0 => ('/cards/new', Icons.add_card_rounded, 'Kart ekle'.tr),
      1 => ('/installments/new', Icons.playlist_add_rounded, 'Taksit ekle'.tr),
      _ => (
        '/expenses/new?method=auto_payment',
        Icons.autorenew_rounded,
        'Otomatik ödeme ekle'.tr,
      ),
    };
    return Scaffold(
      appBar: AppBar(
        title: Text('Kartlar ve ödemeler'.tr),
        bottom: TabBar(
          controller: _tabController,
          // Üç sekme dar ekranlarda sığmayabilir; kaydırılabilir.
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            Tab(text: 'Kartlar'.tr),
            Tab(text: 'Taksit planları'.tr),
            Tab(text: 'Otomatik ödemeler'.tr),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab-cards',
        onPressed: () => _tabController.index == 0
            ? showAddCardChooser(context)
            : context.push(route),
        icon: Icon(icon),
        label: Text(label),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [_CardsTab(), _InstallmentsTab(), _RecurringTab()],
      ),
    );
  }
}

class _CardsTab extends ConsumerWidget {
  const _CardsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardsAsync = ref.watch(availableCardsProvider);
    final debitCards = ref.watch(debitCardsProvider).valueOrNull ?? const [];
    final uid = ref.watch(currentUserIdProvider);
    final isTeam = ref.watch(activeTeamProvider) != null;

    return AsyncValueView<List<CreditCard>>(
      value: cardsAsync,
      loading: const SkeletonList(itemCount: 3, itemHeight: 180),
      onRetry: () => ref.invalidate(availableCardsProvider),
      data: (cards) {
        if (cards.isEmpty && debitCards.isEmpty) {
          return EmptyStateView(
            icon: Icons.credit_card_off_rounded,
            title: 'Henüz kart eklemediniz'.tr,
            message: 'Kredi kartında kesim gününü girin; harcamalar doğru ekstreye yazılsın, son ödeme tarihini kaçırmayın. Banka kartlarınızı ekleyip harcamaları kart kart ayırın. Kart numarası istenmez.'
                .tr,
            actionLabel: 'Kart ekle'.tr,
            actionIcon: Icons.add_card_rounded,
            onAction: () => showAddCardChooser(context),
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
            if (cards.isNotEmpty && debitCards.isNotEmpty)
              SectionHeader(
                title: 'Kredi kartları'.tr,
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              ),
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
                    // Renk kartın içindeki yazı renginden alınır (Builder);
                    // dıştaki bağlam sayfanın koyu yazı rengini verirdi.
                    footer: Builder(
                      builder: (inner) => Text(
                        [
                          'Sonraki kesim {0} ({1})'.trArgs([
                            DateFormats.dayShort(cutoff),
                            DateFormats.daysUntil(cutoff, now: now),
                          ]),
                          'Son ödeme {0}'.trArgs([DateFormats.dayShort(due)]),
                          if (card.ownerUid != uid) 'Takım kartı'.tr,
                        ].join(' · '),
                        style: inner.textStyles.bodySmall?.copyWith(
                          color: DefaultTextStyle.of(inner).style.color
                              ?.withValues(alpha: 0.85),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            if (debitCards.isNotEmpty) ...[
              SectionHeader(
                title: 'Banka kartları'.tr,
                padding: EdgeInsets.only(
                  top: cards.isEmpty ? 0 : AppSpacing.xs,
                  bottom: AppSpacing.xs,
                ),
              ),
              for (final card in debitCards) ...[
                DebitCardVisual(
                  card: card,
                  onTap: () => context.push('/debit-cards/${card.id}'),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
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
            title: 'Taksit planı yok'.tr,
            message: 'Taksitli alışverişlerinizi ekleyin; her ay ilgili ekstreye otomatik yazılsın, kalan borcunuzu görün.'
                .tr,
            actionLabel: 'Taksit planı ekle'.tr,
            actionIcon: Icons.playlist_add_rounded,
            onAction: () => context.push('/installments/new'),
          );
        }
        // Taksitler plan oluşturulurken gelecek aylara yazılır; ilerleme ve
        // kalan borç bugünün ekstre dönemine göre hesaplanır.
        final now = DateTime.now();
        final active = plans
            .where((p) => p.displayStatusAt(now) == 'active')
            .toList();
        final other = plans
            .where((p) => p.displayStatusAt(now) != 'active')
            .toList();
        final remaining = active.fold<int>(
          0,
          (s, p) => s + p.remainingAmountAt(now),
        );
        final monthly = active.fold<int>(
          0,
          (s, p) => s + (p.nextInstallmentAt(now)?.amountInCents ?? 0),
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
                      label: 'Kalan taksit borcu'.tr,
                      value: MoneyFormatter.formatCents(remaining),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _MiniStat(
                      label: 'Sonraki ay yükü'.tr,
                      value: MoneyFormatter.formatCents(monthly),
                    ),
                  ),
                ],
              ),
            if (active.isNotEmpty) SectionHeader(title: 'Devam eden'.tr),
            for (final p in active) ...[
              _PlanCard(plan: p),
              const SizedBox(height: AppSpacing.sm),
            ],
            if (other.isNotEmpty)
              SectionHeader(title: 'Tamamlanan ve iptal edilen'.tr),
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

class _RecurringTab extends ConsumerWidget {
  const _RecurringTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paymentsAsync = ref.watch(recurringPaymentsProvider);

    return AsyncValueView<List<RecurringPayment>>(
      value: paymentsAsync,
      loading: const SkeletonList(itemCount: 4, itemHeight: 88),
      onRetry: () => ref.invalidate(recurringPaymentsProvider),
      data: (payments) {
        if (payments.isEmpty) {
          return EmptyStateView(
            icon: Icons.autorenew_rounded,
            title: 'Otomatik ödeme yok'.tr,
            message: 'Kira, fatura, abonelik gibi her ay tekrarlanan ödemelerinizi ekleyin; her ay aynı gün harcamalarınıza otomatik eklensin.'
                .tr,
            actionLabel: 'Otomatik ödeme ekle'.tr,
            actionIcon: Icons.autorenew_rounded,
            onAction: () => context.push('/expenses/new?method=auto_payment'),
          );
        }
        final active = payments.where((p) => p.isActive).toList()
          ..sort((a, b) => a.dayOfMonth.compareTo(b.dayOfMonth));
        final ended = payments.where((p) => !p.isActive).toList();
        final monthly = active.fold<int>(0, (s, p) => s + p.amountInCents);

        return PageListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            96,
          ),
          children: [
            if (active.isNotEmpty)
              _MiniStat(
                label: 'Aylık otomatik ödeme toplamı'.tr,
                value: MoneyFormatter.formatCents(monthly),
              ),
            if (active.isNotEmpty) SectionHeader(title: 'Aktif'.tr),
            for (final p in active) ...[
              _RecurringCard(payment: p),
              const SizedBox(height: AppSpacing.sm),
            ],
            if (ended.isNotEmpty) SectionHeader(title: 'Sonlandırılan'.tr),
            for (final p in ended) ...[
              _RecurringCard(payment: p),
              const SizedBox(height: AppSpacing.sm),
            ],
          ],
        );
      },
    );
  }
}

class _RecurringCard extends StatelessWidget {
  final RecurringPayment payment;
  const _RecurringCard({required this.payment});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final next = payment.nextOccurrenceAfter(DateTime.now());
    return AppCard(
      onTap: () => context.push('/recurring/${payment.id}'),
      child: Row(
        children: [
          CategoryIcon(categoryId: payment.category, size: 36),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  payment.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textStyles.titleSmall,
                ),
                Text(
                  recurringScheduleLabel(payment),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textStyles.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                if (next != null)
                  Text(
                    'Sıradaki: {0}'.trArgs([DateFormats.day(next)]),
                    style: context.textStyles.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                MoneyFormatter.formatCents(payment.amountInCents),
                style: context.textStyles.titleSmall,
              ),
              if (!payment.isActive) ...[
                const SizedBox(height: 3),
                Pill(label: 'Sonlandırıldı'.tr, color: scheme.onSurfaceVariant),
              ],
            ],
          ),
        ],
      ),
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
    final now = DateTime.now();
    final status = plan.displayStatusAt(now);
    final next = plan.nextInstallmentAt(now);
    final billed = plan.billedCountAt(now);
    final progress = plan.totalInstallments == 0
        ? 0.0
        : billed / plan.totalInstallments;
    final (String statusLabel, Color statusColor) = switch (status) {
      'active' => ('Devam ediyor'.tr, scheme.primary),
      'completed' => ('Tamamlandı'.tr, context.semantic.success),
      _ => ('İptal edildi'.tr, scheme.onSurfaceVariant),
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
                      '•••• {0} · {1} taksit'.trArgs([
                        plan.cardLast4,
                        plan.totalInstallments,
                      ]),
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
            semanticsLabel: 'Ödenen taksit oranı'.tr,
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Expanded(
                child: Text(
                  next != null && status == 'active'
                      ? '{0}/{1} · sıradaki {2} ({3})'.trArgs([
                          billed,
                          plan.totalInstallments,
                          MoneyFormatter.formatCents(next.amountInCents),
                          DateFormats.periodShort(next.statementPeriod),
                        ])
                      : '{0}/{1} taksit işlendi'.trArgs([
                          billed,
                          plan.totalInstallments,
                        ]),
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
