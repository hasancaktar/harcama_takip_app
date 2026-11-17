import 'package:harcama_takip/core/l10n/app_locale.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers/auth_providers.dart';
import '../../../application/providers/budget_providers.dart';
import '../../../application/providers/expense_providers.dart';
import '../../../application/providers/team_providers.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_formats.dart';
import '../../../core/utils/money_formatter.dart';
import '../../widgets/app_card.dart';
import '../../widgets/common.dart';
import '../../widgets/expense_tile.dart';
import '../../widgets/state_views.dart';
import '../../widgets/workspace_selector.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(periodExpensesProvider);

    return Scaffold(
      appBar: AppBar(title: Text('Raporlar'.tr)),
      body: PageListView(
        children: [
          const ContextBar(),
          const SizedBox(height: AppSpacing.md),
          expensesAsync.when(
            skipLoadingOnReload: false,
            loading: () => const SizedBox(
              height: 400,
              child: SkeletonList(
                itemCount: 4,
                padding: EdgeInsets.zero,
                itemHeight: 90,
              ),
            ),
            error: (e, _) => ErrorStateView(
              error: e,
              onRetry: () => ref.invalidate(periodExpensesProvider),
            ),
            data: (expenses) => expenses.isEmpty
                ? Column(
                    children: [
                      _TrendCard(),
                      SizedBox(height: AppSpacing.md),
                      AppCard(
                        child: EmptyStateView(
                          compact: true,
                          icon: Icons.insights_outlined,
                          title: 'Bu dönem için veri yok'.tr,
                          message: 'Harcama ekledikçe kategori dağılımı ve analizler burada görünür.'
                              .tr,
                        ),
                      ),
                    ],
                  )
                : const _ReportContent(),
          ),
        ],
      ),
    );
  }
}

class _ReportContent extends ConsumerWidget {
  const _ReportContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(workspaceStatsProvider);
    final expenses = ref.watch(periodExpensesProvider).valueOrNull ?? const [];
    final budget = ref.watch(budgetStatusProvider);
    final isTeam = ref.watch(activeTeamProvider) != null;
    final memberNames = ref.watch(memberNamesProvider);
    final uid = ref.watch(currentUserIdProvider);
    final top = [...expenses]
      ..sort((a, b) => b.amountInCents.compareTo(a.amountInCents));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, c) {
            final cols = c.maxWidth >= 560 ? 4 : 2;
            final w = (c.maxWidth - (cols - 1) * AppSpacing.sm) / cols;
            final tiles = [
              ('Toplam gider'.tr, MoneyFormatter.formatCents(stats.totalCents)),
              ('İşlem sayısı'.tr, '${stats.count}'),
              ('Ortalama'.tr, MoneyFormatter.formatCents(stats.averageCents)),
              (
                'Bütçe kullanımı'.tr,
                budget != null ? '%${(budget.ratio * 100).round()}' : '—',
              ),
            ];
            return Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final t in tiles)
                  SizedBox(
                    width: w,
                    child: AppCard(
                      padding: const EdgeInsets.all(AppSpacing.sm + 2),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t.$1,
                            style: context.textStyles.labelMedium?.copyWith(
                              color: context.colors.onSurfaceVariant,
                            ),
                          ),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              t.$2,
                              style: context.textStyles.titleMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: AppSpacing.md),
        const _TrendCard(),
        SectionHeader(title: 'Kategori dağılımı'.tr),
        _CategoryPieCard(stats: stats),
        if (isTeam && stats.byMember.length > 1) ...[
          SectionHeader(title: 'Üyelere göre'.tr),
          AppCard(
            child: Column(
              children: [
                for (final m in stats.byMember)
                  _ShareRow(
                    leading: UserAvatar(
                      name: memberNames[m.key] ?? '?',
                      radius: 16,
                    ),
                    label: m.key == uid
                        ? 'Siz'.tr
                        : (memberNames[m.key] ?? 'Eski üye'.tr),
                    cents: m.cents,
                    ratio: m.ratioOf(stats.totalCents),
                  ),
              ],
            ),
          ),
        ],
        SectionHeader(title: 'Ödeme yöntemleri'.tr),
        AppCard(
          child: Column(
            children: [
              for (final m in stats.byPaymentMethod)
                _ShareRow(
                  leading: Icon(
                    AppConstants.getPaymentMethod(m.key).icon,
                    color: context.colors.primary,
                  ),
                  label: AppConstants.getPaymentMethod(m.key).name,
                  cents: m.cents,
                  ratio: m.ratioOf(stats.totalCents),
                ),
            ],
          ),
        ),
        SectionHeader(title: 'En yüksek harcamalar'.tr),
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.xxs),
          child: Column(
            children: [
              for (final e in top.take(5))
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

class _TrendCard extends ConsumerWidget {
  const _TrendCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trendAsync = ref.watch(expenseTrendProvider);
    final scheme = context.colors;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Son 6 ay'.tr, style: context.textStyles.titleMedium),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 180,
            child: trendAsync.when(
              skipLoadingOnReload: false,
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ErrorStateView(error: e, compact: true),
              data: (points) {
                final maxValue = points.fold<int>(
                  0,
                  (m, p) => p.totalCents > m ? p.totalCents : m,
                );
                if (maxValue == 0) {
                  return Center(
                    child: Text(
                      'Henüz karşılaştırılacak veri yok'.tr,
                      style: context.textStyles.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  );
                }
                return Semantics(
                  label: 'Son 6 ay harcama grafiği: {0}'.trArgs([
                    points
                        .map(
                          (p) =>
                              '${DateFormats.period(p.period)} ${MoneyFormatter.formatCents(p.totalCents)}',
                        )
                        .join(', '),
                  ]),
                  child: ExcludeSemantics(
                    child: BarChart(
                      BarChartData(
                        maxY: maxValue * 1.15,
                        alignment: BarChartAlignment.spaceAround,
                        gridData: FlGridData(
                          drawVerticalLine: false,
                          horizontalInterval: maxValue / 3,
                          getDrawingHorizontalLine: (_) => FlLine(
                            color: scheme.outlineVariant,
                            strokeWidth: 1,
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        titlesData: FlTitlesData(
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          leftTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 28,
                              getTitlesWidget: (value, meta) {
                                final i = value.toInt();
                                if (i < 0 || i >= points.length) {
                                  return const SizedBox.shrink();
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    DateFormats.periodShort(points[i].period),
                                    style: context.textStyles.labelSmall
                                        ?.copyWith(
                                          color: scheme.onSurfaceVariant,
                                        ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        barTouchData: BarTouchData(
                          touchTooltipData: BarTouchTooltipData(
                            getTooltipColor: (_) => scheme.inverseSurface,
                            getTooltipItem: (group, _, rod, __) =>
                                BarTooltipItem(
                                  MoneyFormatter.formatCents(
                                    points[group.x].totalCents,
                                  ),
                                  TextStyle(
                                    color: scheme.onInverseSurface,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                          ),
                        ),
                        barGroups: [
                          for (var i = 0; i < points.length; i++)
                            BarChartGroupData(
                              x: i,
                              barRods: [
                                BarChartRodData(
                                  toY: points[i].totalCents.toDouble(),
                                  width: 22,
                                  color: i == points.length - 1
                                      ? scheme.primary
                                      : scheme.primary.withValues(alpha: 0.35),
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(6),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryPieCard extends StatefulWidget {
  final ExpenseStats stats;
  const _CategoryPieCard({required this.stats});

  @override
  State<_CategoryPieCard> createState() => _CategoryPieCardState();
}

class _CategoryPieCardState extends State<_CategoryPieCard> {
  int _touched = -1;

  @override
  Widget build(BuildContext context) {
    final stats = widget.stats;
    final scheme = context.colors;
    return AppCard(
      child: LayoutBuilder(
        builder: (context, c) {
          final wide = c.maxWidth >= 520;
          final chart = SizedBox(
            height: 200,
            width: wide ? 220 : double.infinity,
            child: ExcludeSemantics(
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 48,
                  pieTouchData: PieTouchData(
                    touchCallback: (event, response) {
                      setState(() {
                        _touched =
                            (!event.isInterestedForInteractions ||
                                response?.touchedSection == null)
                            ? -1
                            : response!.touchedSection!.touchedSectionIndex;
                      });
                    },
                  ),
                  sections: [
                    for (var i = 0; i < stats.byCategory.length; i++)
                      PieChartSectionData(
                        color: AppConstants.getCategoryById(
                          stats.byCategory[i].key,
                        ).color,
                        value: stats.byCategory[i].cents.toDouble(),
                        radius: i == _touched ? 58 : 50,
                        showTitle:
                            stats.byCategory[i].ratioOf(stats.totalCents) >=
                            0.08,
                        title:
                            '%${(stats.byCategory[i].ratioOf(stats.totalCents) * 100).round()}',
                        titleStyle: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
          final legend = Column(
            children: [
              for (final s in stats.byCategory)
                _ShareRow(
                  leading: CategoryIcon(categoryId: s.key, size: 32),
                  label: AppConstants.getCategoryById(s.key).name,
                  cents: s.cents,
                  ratio: s.ratioOf(stats.totalCents),
                  barColor: AppConstants.getCategoryById(s.key).color,
                ),
            ],
          );
          if (wide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                chart,
                const SizedBox(width: AppSpacing.lg),
                Expanded(child: legend),
              ],
            );
          }
          return Column(
            children: [
              chart,
              Divider(height: AppSpacing.lg, color: scheme.outlineVariant),
              legend,
            ],
          );
        },
      ),
    );
  }
}

class _ShareRow extends StatelessWidget {
  final Widget leading;
  final String label;
  final int cents;
  final double ratio;
  final Color? barColor;

  const _ShareRow({
    required this.leading,
    required this.label,
    required this.cents,
    required this.ratio,
    this.barColor,
  });

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            leading,
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          label,
                          style: context.textStyles.titleSmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        MoneyFormatter.formatCents(cents),
                        style: context.textStyles.titleSmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: UsageBar(
                          ratio: ratio,
                          height: 5,
                          color: barColor ?? context.colors.primary,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      SizedBox(
                        width: 36,
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
      ),
    );
  }
}
