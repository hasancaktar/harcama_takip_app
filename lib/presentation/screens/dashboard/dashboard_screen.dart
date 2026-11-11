import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../application/providers/auth_providers.dart';
import '../../../application/providers/budget_providers.dart';
import '../../../application/providers/card_providers.dart';
import '../../../application/providers/expense_providers.dart';
import '../../../application/providers/repository_providers.dart';
import '../../../application/providers/team_providers.dart';
import '../../../application/services/installment_reconciliation_service.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/money_formatter.dart';
import '../../widgets/app_card.dart';
import '../../widgets/category_badge.dart';
import '../../widgets/period_selector_widget.dart';
import '../../widgets/team_selector_widget.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runReconciliation();
    });
  }

  Future<void> _runReconciliation() async {
    final uid = ref.read(currentUserIdProvider);
    if (uid != null) {
      final reconciliationService = InstallmentReconciliationService(
        expenseRepo: ref.read(expenseRepositoryProvider),
        installmentRepo: ref.read(installmentRepositoryProvider),
      );
      final team = ref.read(activeTeamProvider);
      await reconciliationService.reconcileDueInstallments(uid: uid, teamId: team?.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stats = ref.watch(monthlyStatsProvider);
    final budget = ref.watch(currentBudgetProvider).value;
    final expenses = ref.watch(expensesStreamProvider).value ?? [];
    final cards = ref.watch(creditCardsProvider).value ?? [];
    final filter = ref.watch(expenseFilterProvider);

    // Bütçe hesabı
    final budgetCents = budget?.totalBudgetInCents ?? 0;
    final remainingBudgetCents = budgetCents > 0 ? (budgetCents - stats.totalCents) : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Özet'),
        actions: const [
          TeamSelectorWidget(),
          SizedBox(width: 8),
          PeriodSelectorWidget(),
          SizedBox(width: 12),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _runReconciliation,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Filtre Seçici (Tüm Harcamalar, Takım, Benim Harcamalarım)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ChoiceChip(
                    label: const Text('Tüm Harcamalar'),
                    selected: filter == 'all',
                    onSelected: (val) => ref.read(expenseFilterProvider.notifier).state = 'all',
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Takım Toplamı'),
                    selected: filter == 'team',
                    onSelected: (val) => ref.read(expenseFilterProvider.notifier).state = 'team',
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Benim Harcamalarım'),
                    selected: filter == 'personal',
                    onSelected: (val) => ref.read(expenseFilterProvider.notifier).state = 'personal',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Ana Toplam Kartı (Seçili Ay Toplamı)
            AppCard(
              color: theme.colorScheme.primary,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Aylık Toplam Harcama',
                        style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text('TRY', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    MoneyFormatter.formatCents(stats.totalCents),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: Colors.white24),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _StatColumn(
                        label: 'Bireysel',
                        value: MoneyFormatter.formatCents(stats.personalCents),
                      ),
                      _StatColumn(
                        label: 'Takım',
                        value: MoneyFormatter.formatCents(stats.teamCents),
                      ),
                      _StatColumn(
                        label: 'Kredi Kartı',
                        value: MoneyFormatter.formatCents(stats.creditCardCents),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Bütçe Durumu
            if (remainingBudgetCents != null)
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Aylık Bütçe Durumu',
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          MoneyFormatter.formatCents(budgetCents),
                          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: (budgetCents > 0) ? (stats.totalCents / budgetCents).clamp(0.0, 1.0) : 0,
                      backgroundColor: theme.colorScheme.surfaceVariant,
                      valueColor: AlwaysStoppedAnimation(
                        stats.totalCents > budgetCents ? AppColors.error : AppColors.primary,
                      ),
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      remainingBudgetCents >= 0
                          ? 'Kalan Bütçe: ${MoneyFormatter.formatCents(remainingBudgetCents)}'
                          : 'Bütçe Aşımı: ${MoneyFormatter.formatCents(remainingBudgetCents.abs())}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: remainingBudgetCents >= 0 ? AppColors.success : AppColors.error,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 16),

            // Yaklaşan Kart Kesim ve Ödeme Tarihleri
            if (cards.isNotEmpty) ...[
              Text(
                'Yaklaşan Kart Tarihleri',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 100,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: cards.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final card = cards[index];
                    return AppCard(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      color: Color(int.parse(card.colorHex.replaceFirst('#', '0xFF'))).withOpacity(0.1),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(card.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 4),
                          Text(
                            'Kesim Günü: ${card.cutoffDay}. gün',
                            style: TextStyle(fontSize: 12, color: theme.hintColor),
                          ),
                          Text(
                            'Vade: Kesimden ${card.paymentDueDaysAfterCutoff} gün sonra',
                            style: TextStyle(fontSize: 11, color: theme.hintColor),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Kategori Bazlı Dağılım Özeti
            if (stats.categoryTotalsCents.isNotEmpty) ...[
              Text(
                'Kategori Dağılımı',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              AppCard(
                child: Column(
                  children: stats.categoryTotalsCents.entries.map((entry) {
                    final catItem = AppConstants.getCategoryById(entry.key);
                    final percent = stats.totalCents > 0
                        ? ((entry.value / stats.totalCents) * 100).toStringAsFixed(1)
                        : '0';
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          CategoryBadge(categoryId: entry.key, showLabel: false),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(catItem.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                Text('%$percent', style: TextStyle(fontSize: 11, color: theme.hintColor)),
                              ],
                            ),
                          ),
                          Text(
                            MoneyFormatter.formatCents(entry.value),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Son Harcamalar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Son Harcamalar',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () => context.go('/expenses'),
                  child: const Text('Tümünü Gör'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (expenses.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Bu ay henüz harcama kaydı bulunmuyor.'),
                ),
              )
            else
              ...expenses.take(5).map((exp) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AppCard(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    onTap: () => context.push('/expenses/detail/${exp.id}'),
                    child: Row(
                      children: [
                        CategoryBadge(categoryId: exp.category, showLabel: false),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(exp.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                              const SizedBox(height: 2),
                              Text(
                                '${exp.visibility == 'team' ? 'Takım' : 'Bireysel'} • ${exp.paymentMethod == 'credit_card' ? 'Kredi Kartı' : 'Nakit'}',
                                style: TextStyle(fontSize: 11, color: theme.hintColor),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          MoneyFormatter.formatCents(exp.amountInCents, currency: exp.currency),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            const SizedBox(height: 80),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/expenses/add'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Harcama Ekle'),
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String label;
  final String value;

  const _StatColumn({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }
}
