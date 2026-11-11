import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../application/providers/budget_providers.dart';
import '../../../application/providers/expense_providers.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/money_formatter.dart';
import '../../widgets/app_card.dart';
import '../../widgets/category_badge.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/period_selector_widget.dart';
import '../../widgets/team_selector_widget.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  int _touchedPieIndex = -1;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stats = ref.watch(monthlyStatsProvider);
    final budget = ref.watch(currentBudgetProvider).value;
    final expenses = ref.watch(expensesStreamProvider).value ?? [];

    final categoryTotals = stats.categoryTotalsCents;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Raporlar & Analiz'),
        actions: const [
          TeamSelectorWidget(),
          SizedBox(width: 8),
          PeriodSelectorWidget(),
          SizedBox(width: 12),
        ],
      ),
      body: expenses.isEmpty
          ? const EmptyStateWidget(
              icon: Icons.pie_chart_outline_rounded,
              title: 'Rapor Verisi Yok',
              message: 'Seçili ay için harcama bulunmuyor. Harcama ekledikçe grafikleriniz burada görünecektir.',
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Aylık Finansal Kartlar Özeti
                Row(
                  children: [
                    Expanded(
                      child: AppCard(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Toplam Gider', style: TextStyle(color: theme.hintColor, fontSize: 12)),
                            const SizedBox(height: 4),
                            Text(
                              MoneyFormatter.formatCents(stats.totalCents),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppCard(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Taksit Yükü', style: TextStyle(color: theme.hintColor, fontSize: 12)),
                            const SizedBox(height: 4),
                            Text(
                              MoneyFormatter.formatCents(stats.installmentCents),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Pasta Grafiği (Kategori Dağılımı)
                if (categoryTotals.isNotEmpty) ...[
                  Text(
                    'Kategori Bazlı Harcama Dağılımı',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  AppCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        SizedBox(
                          height: 220,
                          child: PieChart(
                            PieChartData(
                              pieTouchData: PieTouchData(
                                touchCallback: (FlTouchEvent event, pieTouchResponse) {
                                  setState(() {
                                    if (!event.isInterestedForInteractions ||
                                        pieTouchResponse == null ||
                                        pieTouchResponse.touchedSection == null) {
                                      _touchedPieIndex = -1;
                                      return;
                                    }
                                    _touchedPieIndex = pieTouchResponse
                                        .touchedSection!.touchedSectionIndex;
                                  });
                                },
                              ),
                              borderData: FlBorderData(show: false),
                              sectionsSpace: 2,
                              centerSpaceRadius: 40,
                              sections: categoryTotals.entries.toList().asMap().entries.map((item) {
                                final index = item.key;
                                final entry = item.value;
                                final isTouched = index == _touchedPieIndex;
                                final cat = AppConstants.getCategoryById(entry.key);
                                final double percent = stats.totalCents > 0
                                    ? (entry.value / stats.totalCents) * 100
                                    : 0;

                                return PieChartSectionData(
                                  color: cat.color,
                                  value: entry.value.toDouble(),
                                  title: '${percent.toStringAsFixed(0)}%',
                                  radius: isTouched ? 65 : 55,
                                  titleStyle: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Lejant
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          children: categoryTotals.entries.map((entry) {
                            final cat = AppConstants.getCategoryById(entry.key);
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(color: cat.color, shape: BoxShape.circle),
                                ),
                                const SizedBox(width: 6),
                                Text(cat.name, style: const TextStyle(fontSize: 12)),
                              ],
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Bütçe Gerçekleşme Oranı
                if (budget != null && budget.totalBudgetInCents > 0) ...[
                  Text(
                    'Bütçe Gerçekleşme Oranı',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Harcama / Bütçe',
                              style: theme.textTheme.bodyMedium,
                            ),
                            Text(
                              '%${((stats.totalCents / budget.totalBudgetInCents) * 100).toStringAsFixed(1)}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        LinearProgressIndicator(
                          value: (stats.totalCents / budget.totalBudgetInCents).clamp(0.0, 1.0),
                          minHeight: 10,
                          borderRadius: BorderRadius.circular(5),
                          backgroundColor: theme.colorScheme.surfaceVariant,
                          color: stats.totalCents > budget.totalBudgetInCents
                              ? Colors.red
                              : theme.colorScheme.primary,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // En Yüksek Harcamalar Sıralaması
                Text(
                  'En Yüksek Harcamalar',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ...(List.of(expenses)..sort((a, b) => b.amountInCents.compareTo(a.amountInCents)))
                    .take(5)
                    .map((exp) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: AppCard(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        child: Row(
                          children: [
                            CategoryBadge(categoryId: exp.category, showLabel: false),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(exp.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                            ),
                            Text(
                              MoneyFormatter.formatCents(exp.amountInCents),
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                const SizedBox(height: 40),
              ],
            ),
    );
  }
}
