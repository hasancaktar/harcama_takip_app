import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers/expense_providers.dart';
import '../../../application/providers/team_providers.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_formats.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../domain/entities/expense.dart';
import '../../widgets/app_card.dart';
import '../../widgets/common.dart';
import '../../widgets/expense_tile.dart';
import '../../widgets/state_views.dart';
import '../../widgets/workspace_selector.dart';

class ExpenseListScreen extends ConsumerStatefulWidget {
  const ExpenseListScreen({super.key});

  @override
  ConsumerState<ExpenseListScreen> createState() => _ExpenseListScreenState();
}

class _ExpenseListScreenState extends ConsumerState<ExpenseListScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  String? _category;
  String? _paymentMethod;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Türkçe karakterleri sadeleştirerek büyük/küçük harf duyarsız arama yapar.
  static String _normalize(String s) => s
      .toLowerCase()
      .replaceAll('ı', 'i')
      .replaceAll('İ', 'i')
      .replaceAll('ş', 's')
      .replaceAll('ğ', 'g')
      .replaceAll('ü', 'u')
      .replaceAll('ö', 'o')
      .replaceAll('ç', 'c');

  List<Expense> _apply(List<Expense> list) {
    final q = _normalize(_query.trim());
    return list.where((e) {
      if (_category != null && e.category != _category) return false;
      if (_paymentMethod != null && e.paymentMethod != _paymentMethod) {
        return false;
      }
      if (q.isEmpty) return true;
      return _normalize(e.title).contains(q) ||
          _normalize(e.notes ?? '').contains(q) ||
          _normalize(AppConstants.getCategoryById(e.category).name).contains(q);
    }).toList();
  }

  bool get _hasFilters =>
      _category != null || _paymentMethod != null || _query.isNotEmpty;

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _query = '';
      _category = null;
      _paymentMethod = null;
    });
  }

  Future<void> _openFilterSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          void update(VoidCallback fn) {
            setState(fn);
            setSheetState(() {});
          }

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Filtrele', style: ctx.textStyles.titleLarge),
                  const SizedBox(height: AppSpacing.md),
                  Text('Kategori', style: ctx.textStyles.titleSmall),
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      for (final c in AppConstants.defaultCategories)
                        FilterChip(
                          avatar: Icon(c.icon, size: 18, color: c.color),
                          label: Text(c.name),
                          selected: _category == c.id,
                          onSelected: (s) =>
                              update(() => _category = s ? c.id : null),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text('Ödeme yöntemi', style: ctx.textStyles.titleSmall),
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      for (final m in AppConstants.paymentMethodItems)
                        FilterChip(
                          avatar: Icon(m.icon, size: 18),
                          label: Text(m.name),
                          selected: _paymentMethod == m.id,
                          onSelected: (s) =>
                              update(() => _paymentMethod = s ? m.id : null),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      Expanded(
                        child: AppButton(
                          label: 'Temizle',
                          outlined: true,
                          onPressed: () => update(() {
                            _category = null;
                            _paymentMethod = null;
                          }),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: AppButton(
                          label: 'Uygula',
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final expensesAsync = ref.watch(visibleExpensesProvider);
    final isTeam = ref.watch(activeTeamProvider) != null;
    final memberNames = ref.watch(memberNamesProvider);
    final filterCount =
        (_category != null ? 1 : 0) + (_paymentMethod != null ? 1 : 0);

    return Scaffold(
      appBar: AppBar(title: const Text('Harcamalar')),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Harcama ekle',
        onPressed: () => context.push('/expenses/new'),
        child: const Icon(Icons.add_rounded),
      ),
      body: Column(
        children: [
          ResponsiveCenter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.xs,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: Column(
                children: [
                  const ContextBar(),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          textInputAction: TextInputAction.search,
                          onChanged: (v) => setState(() => _query = v),
                          decoration: InputDecoration(
                            hintText: 'Başlık, not veya kategori ara',
                            prefixIcon: const Icon(Icons.search_rounded),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 12,
                            ),
                            suffixIcon: _query.isEmpty
                                ? null
                                : IconButton(
                                    tooltip: 'Aramayı temizle',
                                    icon: const Icon(Icons.close_rounded),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _query = '');
                                    },
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Badge(
                        isLabelVisible: filterCount > 0,
                        label: Text('$filterCount'),
                        child: IconButton.filledTonal(
                          tooltip: 'Filtrele',
                          onPressed: _openFilterSheet,
                          icon: const Icon(Icons.tune_rounded),
                        ),
                      ),
                    ],
                  ),
                  if (isTeam) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Consumer(
                        builder: (context, ref, _) {
                          final filter = ref.watch(teamExpenseFilterProvider);
                          return SegmentedButton<TeamExpenseFilter>(
                            showSelectedIcon: false,
                            segments: const [
                              ButtonSegment(
                                value: TeamExpenseFilter.all,
                                label: Text('Tüm takım'),
                              ),
                              ButtonSegment(
                                value: TeamExpenseFilter.mine,
                                label: Text('Benimkiler'),
                              ),
                            ],
                            selected: {filter},
                            onSelectionChanged: (s) =>
                                ref
                                    .read(teamExpenseFilterProvider.notifier)
                                    .state = s
                                    .first,
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Expanded(
            child: expensesAsync.when(
              skipLoadingOnReload: false,
              loading: () => const SkeletonList(),
              error: (e, _) => ErrorStateView(
                error: e,
                onRetry: () => ref.invalidate(periodExpensesProvider),
              ),
              data: (all) {
                if (all.isEmpty) {
                  return EmptyStateView(
                    icon: Icons.receipt_long_outlined,
                    title: 'Bu dönemde harcama yok',
                    message: 'Harcama ekledikçe burada gün gün listelenecek.',
                    actionLabel: 'Harcama ekle',
                    onAction: () => context.push('/expenses/new'),
                  );
                }
                final filtered = _apply(all);
                if (filtered.isEmpty) {
                  return EmptyStateView(
                    icon: Icons.search_off_rounded,
                    title: 'Sonuç bulunamadı',
                    message: 'Arama veya filtrelere uyan harcama yok.',
                    actionLabel: _hasFilters ? 'Filtreleri temizle' : null,
                    actionIcon: Icons.filter_alt_off_outlined,
                    onAction: _hasFilters ? _clearFilters : null,
                  );
                }
                return _GroupedExpenseList(
                  expenses: filtered,
                  memberNames: isTeam ? memberNames : const {},
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupedExpenseList extends StatelessWidget {
  final List<Expense> expenses;
  final Map<String, String> memberNames;

  const _GroupedExpenseList({
    required this.expenses,
    required this.memberNames,
  });

  @override
  Widget build(BuildContext context) {
    final groups = <DateTime, List<Expense>>{};
    for (final e in expenses) {
      final day = DateTime(e.date.year, e.date.month, e.date.day);
      groups.putIfAbsent(day, () => []).add(e);
    }
    final days = groups.keys.toList()..sort((a, b) => b.compareTo(a));
    final total = expenses.fold<int>(0, (s, e) => s + e.amountInCents);

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, 96),
      itemCount: days.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return ResponsiveCenter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Text(
                '${expenses.length} harcama · ${MoneyFormatter.formatCents(total)}',
                style: context.textStyles.bodyMedium?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            ),
          );
        }
        final day = days[index - 1];
        final items = groups[day]!;
        final dayTotal = items.fold<int>(0, (s, e) => s + e.amountInCents);
        return ResponsiveCenter(
          child: Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xxs,
                    AppSpacing.sm,
                    AppSpacing.xxs,
                    AppSpacing.xs,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          DateFormats.relativeDay(day),
                          style: context.textStyles.titleSmall?.copyWith(
                            color: context.colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                      Text(
                        MoneyFormatter.formatCents(dayTotal),
                        style: context.textStyles.labelLarge?.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                AppCard(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.xxs,
                    horizontal: AppSpacing.xxs,
                  ),
                  child: Column(
                    children: [
                      for (final e in items)
                        ExpenseTile(
                          expense: e,
                          memberName: memberNames[e.ownerUid],
                          onTap: () => context.push('/expenses/${e.id}'),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
