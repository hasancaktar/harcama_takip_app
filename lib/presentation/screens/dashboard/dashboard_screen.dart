import 'package:harcama_takip/core/l10n/app_locale.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers/auth_providers.dart';
import '../../../application/providers/budget_providers.dart';
import '../../../application/providers/card_providers.dart';
import '../../../application/providers/expense_providers.dart';
import '../../../application/providers/installment_providers.dart';
import '../../../application/providers/team_providers.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/color_utils.dart';
import '../../../core/utils/date_formats.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/utils/statement_calculator.dart';
import '../../../domain/entities/credit_card.dart';
import '../../widgets/app_card.dart';
import '../../widgets/common.dart';
import '../../widgets/expense_tile.dart';
import '../../widgets/state_views.dart';
import '../../widgets/workspace_selector.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(installmentSyncProvider);
    await ref.read(installmentSyncProvider.future);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final expensesAsync = ref.watch(visibleExpensesProvider);
    final isTeam = ref.watch(activeTeamProvider) != null;
    final invites = ref.watch(myPendingInvitesProvider).valueOrNull ?? const [];
    final firstName = (user?.displayName ?? '').split(' ').first;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          firstName.isEmpty ? 'Özet'.tr : 'Merhaba, {0}'.trArgs([firstName]),
        ),
        actions: [
          IconButton(
            tooltip: 'Bütçe'.tr,
            icon: const Icon(Icons.savings_outlined),
            onPressed: () => context.push('/budgets'),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab-dashboard',
        onPressed: () => context.push('/expenses/new'),
        icon: const Icon(Icons.add_rounded),
        label: Text('Harcama ekle'.tr),
      ),
      body: RefreshIndicator(
        onRefresh: () => _refresh(ref),
        child: PageListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.xs,
            AppSpacing.md,
            96,
          ),
          children: [
            const ContextBar(),
            if (invites.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              InlineMessage(
                tone: MessageTone.info,
                title: 'Takım davetiniz var'.tr,
                message: invites.length == 1
                    ? '"{0}" takımına davet edildiniz.'.trArgs([
                        invites.first.teamName,
                      ])
                    : '{0} takım davetiniz bekliyor.'.trArgs([invites.length]),
                action: TextButton(
                  onPressed: () => context.push('/teams'),
                  child: Text('Davetleri görüntüle'.tr),
                ),
              ),
            ],
            if (isTeam) ...[
              const SizedBox(height: AppSpacing.md),
              const _TeamFilterChips(),
            ],
            const SizedBox(height: AppSpacing.md),
            expensesAsync.when(
              skipLoadingOnReload: false,
              loading: () => const SizedBox(
                height: 320,
                child: SkeletonList(
                  itemCount: 4,
                  padding: EdgeInsets.zero,
                  itemHeight: 72,
                ),
              ),
              error: (e, _) => ErrorStateView(
                error: e,
                onRetry: () => ref.invalidate(periodExpensesProvider),
              ),
              data: (expenses) =>
                  _DashboardContent(hasExpenses: expenses.isNotEmpty),
            ),
          ],
        ),
      ),
    );
  }
}

class _TeamFilterChips extends ConsumerWidget {
  const _TeamFilterChips();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(teamExpenseFilterProvider);
    return Wrap(
      spacing: AppSpacing.xs,
      children: [
        ChoiceChip(
          label: Text('Tüm takım'.tr),
          selected: filter == TeamExpenseFilter.all,
          onSelected: (_) =>
              ref.read(teamExpenseFilterProvider.notifier).state =
                  TeamExpenseFilter.all,
        ),
        ChoiceChip(
          label: Text('Benim eklediklerim'.tr),
          selected: filter == TeamExpenseFilter.mine,
          onSelected: (_) =>
              ref.read(teamExpenseFilterProvider.notifier).state =
                  TeamExpenseFilter.mine,
        ),
      ],
    );
  }
}

class _DashboardContent extends ConsumerWidget {
  final bool hasExpenses;
  const _DashboardContent({required this.hasExpenses});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(visibleStatsProvider);
    final expenses = ref.watch(visibleExpensesProvider).valueOrNull ?? const [];
    final cards = ref.watch(availableCardsProvider).valueOrNull ?? const [];
    final memberNames = ref.watch(memberNamesProvider);
    final isTeam = ref.watch(activeTeamProvider) != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SummaryHeroCard(),
        const SizedBox(height: AppSpacing.md),
        _QuickStats(stats: stats),
        if (cards.isNotEmpty) ...[
          SectionHeader(
            title: 'Yaklaşan kart tarihleri'.tr,
            actionLabel: 'Kartlar'.tr,
            onAction: () => context.go('/cards'),
          ),
          _UpcomingCardDates(cards: cards),
        ],
        if (stats.byCategory.isNotEmpty) ...[
          SectionHeader(
            title: 'Kategoriler'.tr,
            actionLabel: 'Raporlar'.tr,
            onAction: () => context.go('/reports'),
          ),
          AppCard(
            child: Column(
              children: [
                for (final share in stats.byCategory.take(5))
                  _CategoryRow(share: share, total: stats.totalCents),
              ],
            ),
          ),
        ],
        SectionHeader(
          title: 'Son harcamalar'.tr,
          actionLabel: hasExpenses ? 'Tümünü gör'.tr : null,
          onAction: hasExpenses ? () => context.go('/expenses') : null,
        ),
        if (!hasExpenses)
          AppCard(
            child: EmptyStateView(
              compact: true,
              icon: Icons.receipt_long_outlined,
              title: 'Bu dönem harcama yok'.tr,
              message:
                  'İlk harcamanızı ekleyerek bütçenizi takip etmeye başlayın.'
                      .tr,
              actionLabel: 'Harcama ekle'.tr,
              onAction: () => context.push('/expenses/new'),
            ),
          )
        else
          AppCard(
            padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.xs,
              horizontal: AppSpacing.xxs,
            ),
            child: Column(
              children: [
                for (final e in expenses.take(5))
                  ExpenseTile(
                    expense: e,
                    showDate: true,
                    memberName: isTeam ? memberNames[e.ownerUid] : null,
                    onTap: () => context.push('/expenses/${e.id}'),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _SummaryHeroCard extends ConsumerWidget {
  const _SummaryHeroCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(visibleStatsProvider);
    final period = ref.watch(selectedPeriodProvider);
    final budget = ref.watch(budgetStatusProvider);
    final filter = ref.watch(teamExpenseFilterProvider);
    final isTeam = ref.watch(activeTeamProvider) != null;
    final scheme = context.colors;
    final onHero = scheme.onPrimary;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          scheme.primary,
          Color.lerp(scheme.primary, scheme.secondary, 0.45)!,
        ],
      ),
      semanticLabel: '{0} toplam harcama {1}'.trArgs([
        DateFormats.period(period),
        MoneyFormatter.formatCents(stats.totalCents),
      ]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isTeam && filter == TeamExpenseFilter.mine
                ? '{0} · eklediklerim'.trArgs([DateFormats.period(period)])
                : '{0} toplamı'.trArgs([DateFormats.period(period)]),
            style: context.textStyles.titleSmall?.copyWith(
              color: onHero.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              MoneyFormatter.formatCents(stats.totalCents),
              style: context.textStyles.displaySmall?.copyWith(color: onHero),
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            stats.count == 0
                ? 'Henüz harcama yok'.tr
                : '{0} harcama · ortalama {1}'.trArgs([
                    stats.count,
                    MoneyFormatter.formatCents(stats.averageCents),
                  ]),
            style: context.textStyles.bodySmall?.copyWith(
              color: onHero.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (budget != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: budget.ratio.clamp(0.0, 1.0),
                minHeight: 8,
                color: budget.level == BudgetLevel.exceeded
                    ? const Color(0xFFFFB4AB)
                    : budget.level == BudgetLevel.safe
                    ? onHero
                    : const Color(0xFFFDE68A),
                backgroundColor: onHero.withValues(alpha: 0.25),
                semanticsLabel: 'Bütçe kullanımı'.tr,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              budget.remainingCents >= 0
                  ? 'Bütçenin %{0} kullanıldı · {1} kaldı'.trArgs([
                      (budget.ratio * 100).round(),
                      MoneyFormatter.formatCents(budget.remainingCents),
                    ])
                  : 'Bütçe {0} aşıldı'.trArgs([
                      MoneyFormatter.formatCents(-budget.remainingCents),
                    ]),
              style: context.textStyles.bodySmall?.copyWith(
                color: onHero,
                fontWeight: FontWeight.w600,
              ),
            ),
          ] else
            TextButton.icon(
              onPressed: () => context.push('/budgets'),
              style: TextButton.styleFrom(
                foregroundColor: onHero,
                backgroundColor: onHero.withValues(alpha: 0.15),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              ),
              icon: const Icon(Icons.savings_outlined, size: 18),
              label: Text('Aylık bütçe belirle'.tr),
            ),
        ],
      ),
    );
  }
}

class _QuickStats extends StatelessWidget {
  final ExpenseStats stats;
  const _QuickStats({required this.stats});

  @override
  Widget build(BuildContext context) {
    final topCategory = stats.byCategory.isNotEmpty
        ? AppConstants.getCategoryById(stats.byCategory.first.key)
        : null;
    final items = [
      _StatItem(
        Icons.credit_card_rounded,
        'Kredi kartı'.tr,
        MoneyFormatter.formatCents(stats.creditCardCents),
      ),
      _StatItem(
        Icons.splitscreen_rounded,
        'Taksitler'.tr,
        MoneyFormatter.formatCents(stats.installmentCents),
      ),
      _StatItem(
        Icons.local_fire_department_outlined,
        'En çok'.tr,
        topCategory?.name ?? '—',
      ),
      _StatItem(
        Icons.arrow_upward_rounded,
        'En büyük'.tr,
        stats.largest != null
            ? MoneyFormatter.formatCents(stats.largest!.amountInCents)
            : '—',
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 560 ? 4 : 2;
        final itemWidth =
            (constraints.maxWidth - (columns - 1) * AppSpacing.sm) / columns;
        return Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final item in items)
              SizedBox(
                width: itemWidth,
                child: _StatTile(item: item),
              ),
          ],
        );
      },
    );
  }
}

class _StatItem {
  final IconData icon;
  final String label;
  final String value;
  const _StatItem(this.icon, this.label, this.value);
}

class _StatTile extends StatelessWidget {
  final _StatItem item;
  const _StatTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.sm + 2),
      child: Row(
        children: [
          Icon(item.icon, size: 20, color: scheme.primary),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label,
                  style: context.textStyles.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  item.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textStyles.titleSmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UpcomingCardDates extends StatelessWidget {
  final List<CreditCard> cards;
  const _UpcomingCardDates({required this.cards});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final entries = cards.map((card) {
      final cutoff = StatementCalculator.nextCutoffDate(now, card.cutoffDay);
      final due = StatementCalculator.calculateDueDate(
        statementPeriod: StatementCalculator.periodOf(cutoff),
        cutoffDay: card.cutoffDay,
        paymentDueDaysAfterCutoff: card.paymentDueDaysAfterCutoff,
      );
      return (card: card, cutoff: cutoff, due: due);
    }).toList()..sort((a, b) => a.cutoff.compareTo(b.cutoff));

    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        children: [
          for (final e in entries.take(4))
            ListTile(
              onTap: () => context.push('/cards/${e.card.id}'),
              leading: Container(
                width: 40,
                height: 28,
                decoration: BoxDecoration(
                  color: ColorUtils.fromHex(e.card.colorHex),
                  borderRadius: BorderRadius.circular(6),
                ),
                alignment: Alignment.center,
                child: Text(
                  e.card.last4Digits,
                  style: TextStyle(
                    color: ColorUtils.onColor(
                      ColorUtils.fromHex(e.card.colorHex),
                    ),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              title: Text(
                e.card.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                'Kesim {0} · Son ödeme {1}'.trArgs([
                  DateFormats.dayShort(e.cutoff),
                  DateFormats.dayShort(e.due),
                ]),
              ),
              trailing: Text(
                DateFormats.daysUntil(e.cutoff, now: now),
                style: context.textStyles.labelLarge?.copyWith(
                  color: context.colors.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  final AmountShare share;
  final int total;
  const _CategoryRow({required this.share, required this.total});

  @override
  Widget build(BuildContext context) {
    final category = AppConstants.getCategoryById(share.key);
    final ratio = share.ratioOf(total);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          CategoryIcon(categoryId: share.key, size: 36),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        category.name,
                        style: context.textStyles.titleSmall,
                      ),
                    ),
                    Text(
                      MoneyFormatter.formatCents(share.cents),
                      style: context.textStyles.titleSmall,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: UsageBar(
                        ratio: ratio,
                        color: category.color,
                        height: 6,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    SizedBox(
                      width: 40,
                      child: Text(
                        '%${(ratio * 100).round()}',
                        textAlign: TextAlign.end,
                        style: context.textStyles.labelSmall?.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
