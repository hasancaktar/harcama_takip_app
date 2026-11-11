import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../application/providers/auth_providers.dart';
import '../../../application/providers/budget_providers.dart';
import '../../../application/providers/expense_providers.dart';
import '../../../application/providers/repository_providers.dart';
import '../../../application/providers/team_providers.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../domain/entities/budget.dart';
import '../../widgets/app_card.dart';
import '../../widgets/category_badge.dart';
import '../../widgets/period_selector_widget.dart';
import '../../widgets/team_selector_widget.dart';

class BudgetsScreen extends ConsumerStatefulWidget {
  const BudgetsScreen({super.key});

  @override
  ConsumerState<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends ConsumerState<BudgetsScreen> {
  final _budgetController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _budgetController.dispose();
    super.dispose();
  }

  Future<void> _handleSaveBudget() async {
    final cents = MoneyFormatter.parseToCents(_budgetController.text);
    if (cents <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Geçerli bir bütçe tutarı giriniz.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final uid = ref.read(currentUserIdProvider)!;
      final activeTeam = ref.read(activeTeamProvider);
      final period = ref.read(selectedPeriodProvider);
      final budgetRepo = ref.read(budgetRepositoryProvider);

      final budget = Budget(
        id: const Uuid().v4(),
        ownerUid: uid,
        teamId: activeTeam?.id,
        visibility: activeTeam != null ? 'team' : 'personal',
        period: period,
        totalBudgetInCents: cents,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await budgetRepo.saveBudget(budget);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aylık bütçe başarıyla güncellendi.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final budget = ref.watch(currentBudgetProvider).value;
    final stats = ref.watch(monthlyStatsProvider);

    final totalBudget = budget?.totalBudgetInCents ?? 0;
    final spent = stats.totalCents;
    final remaining = totalBudget - spent;
    final progress = totalBudget > 0 ? (spent / totalBudget).clamp(0.0, 1.0) : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bütçe Yönetimi'),
        actions: const [
          TeamSelectorWidget(),
          SizedBox(width: 8),
          PeriodSelectorWidget(),
          SizedBox(width: 12),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Ana Bütçe Durum Kartı
          AppCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Aylık Bütçe Hedefi', style: TextStyle(color: theme.hintColor, fontSize: 13)),
                    Text(
                      totalBudget > 0 ? MoneyFormatter.formatCents(totalBudget) : 'Belirlenmedi',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: progress,
                  minHeight: 12,
                  borderRadius: BorderRadius.circular(6),
                  backgroundColor: theme.colorScheme.surfaceVariant,
                  valueColor: AlwaysStoppedAnimation(
                    spent > totalBudget && totalBudget > 0 ? Colors.red : theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Harcanan', style: TextStyle(fontSize: 11, color: theme.hintColor)),
                        const SizedBox(height: 2),
                        Text(MoneyFormatter.formatCents(spent), style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Kalan Bütçe', style: TextStyle(fontSize: 11, color: theme.hintColor)),
                        const SizedBox(height: 2),
                        Text(
                          MoneyFormatter.formatCents(remaining),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: remaining >= 0 ? theme.colorScheme.primary : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Bütçe Tanımlama / Güncelleme Formu
          Text(
            'Bu Ay İçin Bütçe Belirle',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextFormField(
                  controller: _budgetController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Aylık Toplam Bütçe Tutarı (TL)',
                    prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                    hintText: 'Örn: 25000',
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _isSaving ? null : _handleSaveBudget,
                  child: _isSaving
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Bütçeyi Kaydet'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Kategori Bazlı Harcama Dağılımı ve Eşikleri
          Text(
            'Kategori Harcamaları',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ...stats.categoryTotalsCents.entries.map((entry) {
            final cat = AppConstants.getCategoryById(entry.key);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    CategoryBadge(categoryId: entry.key, showLabel: false),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(cat.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    Text(
                      MoneyFormatter.formatCents(entry.value),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
