import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../application/providers/expense_providers.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/money_formatter.dart';
import '../../widgets/app_card.dart';
import '../../widgets/category_badge.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/period_selector_widget.dart';
import '../../widgets/team_selector_widget.dart';

class ExpenseListScreen extends ConsumerStatefulWidget {
  const ExpenseListScreen({super.key});

  @override
  ConsumerState<ExpenseListScreen> createState() => _ExpenseListScreenState();
}

class _ExpenseListScreenState extends ConsumerState<ExpenseListScreen> {
  String _searchQuery = '';
  String? _selectedCategory;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final expenses = ref.watch(expensesStreamProvider).value ?? [];

    final filtered = expenses.where((exp) {
      if (_searchQuery.isNotEmpty &&
          !exp.title.toLowerCase().contains(_searchQuery.toLowerCase())) {
        return false;
      }
      if (_selectedCategory != null && exp.category != _selectedCategory) {
        return false;
      }
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Harcamalar'),
        actions: const [
          TeamSelectorWidget(),
          SizedBox(width: 8),
          PeriodSelectorWidget(),
          SizedBox(width: 12),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Harcama ara...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () => setState(() => _searchQuery = ''),
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Tüm Kategoriler'),
                  selected: _selectedCategory == null,
                  onSelected: (_) => setState(() => _selectedCategory = null),
                ),
                const SizedBox(width: 8),
                ...AppConstants.defaultCategories.map((cat) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(cat.name),
                      selected: _selectedCategory == cat.id,
                      onSelected: (selected) {
                        setState(() => _selectedCategory = selected ? cat.id : null);
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: filtered.isEmpty
                ? const EmptyStateWidget(
                    icon: Icons.receipt_long_outlined,
                    title: 'Harcama Bulunamadı',
                    message: 'Bu dönem veya filtre için harcama kaydı yok.',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final exp = filtered[index];
                      final dateFormatted = DateFormat('d MMMM, HH:mm', 'tr_TR').format(exp.date);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: AppCard(
                          padding: const EdgeInsets.all(14),
                          onTap: () => context.push('/expenses/detail/${exp.id}'),
                          child: Row(
                            children: [
                              CategoryBadge(categoryId: exp.category, showLabel: false),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      exp.title,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: theme.colorScheme.surfaceVariant,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            exp.visibility == 'team' ? 'Takım' : 'Bireysel',
                                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          dateFormatted,
                                          style: TextStyle(fontSize: 11, color: theme.hintColor),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    MoneyFormatter.formatCents(exp.amountInCents, currency: exp.currency),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                  if (exp.isInstallment)
                                    Text(
                                      'Taksit ${exp.installmentNumber}/${exp.totalInstallments}',
                                      style: TextStyle(fontSize: 11, color: theme.colorScheme.primary),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/expenses/add'),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}
