import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers/auth_providers.dart';
import '../../../application/providers/card_providers.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_formats.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/utils/statement_calculator.dart';
import '../../../domain/entities/credit_card.dart';
import '../../widgets/app_card.dart';
import '../../widgets/common.dart';
import '../../widgets/credit_card_visual.dart';
import '../../widgets/expense_tile.dart';
import '../../widgets/state_views.dart';

/// Kartın ekstre dönemleri arasında gezinilebilen ekstre detayı.
class CardStatementDetailScreen extends ConsumerStatefulWidget {
  final String cardId;
  const CardStatementDetailScreen({super.key, required this.cardId});

  @override
  ConsumerState<CardStatementDetailScreen> createState() =>
      _CardStatementDetailScreenState();
}

class _CardStatementDetailScreenState
    extends ConsumerState<CardStatementDetailScreen> {
  String? _period;

  @override
  Widget build(BuildContext context) {
    final cardAsync = ref.watch(cardByIdProvider(widget.cardId));
    final uid = ref.watch(currentUserIdProvider);
    final card = cardAsync.valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: Text(card?.name ?? 'Kart'),
        actions: [
          if (card != null && card.ownerUid == uid && card.isActive)
            IconButton(
              tooltip: 'Kartı düzenle',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => context.push('/cards/${card.id}/edit'),
            ),
        ],
      ),
      body: AsyncValueView<CreditCard?>(
        value: cardAsync,
        onRetry: () => ref.invalidate(cardByIdProvider(widget.cardId)),
        data: (card) {
          if (card == null) {
            return const EmptyStateView(
              icon: Icons.credit_card_off_rounded,
              title: 'Kart bulunamadı',
              message: 'Kart kaldırılmış veya görüntüleme yetkiniz yok.',
            );
          }
          // Varsayılan: içinde bulunulan (henüz kesilmemiş) ekstre dönemi.
          final period =
              _period ??
              StatementCalculator.resolveStatementPeriod(
                DateTime.now(),
                card.cutoffDay,
              );
          return _StatementBody(
            card: card,
            period: period,
            onPeriodChanged: (p) => setState(() => _period = p),
          );
        },
      ),
    );
  }
}

class _StatementBody extends ConsumerWidget {
  final CreditCard card;
  final String period;
  final ValueChanged<String> onPeriodChanged;

  const _StatementBody({
    required this.card,
    required this.period,
    required this.onPeriodChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(
      cardStatementExpensesProvider((cardId: card.id, period: period)),
    );
    final scheme = context.colors;
    final start = StatementCalculator.periodStart(period);
    final cutoff = StatementCalculator.getCutoffDateTime(
      start.year,
      start.month,
      card.cutoffDay,
    );
    final due = StatementCalculator.calculateDueDate(
      statementPeriod: period,
      cutoffDay: card.cutoffDay,
      paymentDueDaysAfterCutoff: card.paymentDueDaysAfterCutoff,
    );
    final isOpen = DateTime.now().isBefore(cutoff);
    final total = (expensesAsync.valueOrNull ?? const []).fold<int>(
      0,
      (s, e) => s + e.amountInCents,
    );

    return PageListView(
      children: [
        CreditCardVisual(card: card),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: 'Önceki ekstre',
                    onPressed: () => onPeriodChanged(
                      StatementCalculator.shiftPeriod(period, -1),
                    ),
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          '${DateFormats.period(period)} ekstresi',
                          style: context.textStyles.titleMedium,
                        ),
                        const SizedBox(height: 2),
                        Pill(
                          label: isOpen ? 'Açık dönem' : 'Kesildi',
                          color: isOpen
                              ? scheme.primary
                              : scheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Sonraki ekstre',
                    onPressed: () => onPeriodChanged(
                      StatementCalculator.shiftPeriod(period, 1),
                    ),
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ),
              const Divider(height: AppSpacing.lg),
              Text(
                'Dönem borcu',
                textAlign: TextAlign.center,
                style: context.textStyles.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              Text(
                MoneyFormatter.formatCents(total),
                textAlign: TextAlign.center,
                style: context.textStyles.headlineMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: _DateInfo(
                      label: 'Kesim tarihi',
                      value: DateFormats.day(cutoff),
                    ),
                  ),
                  Expanded(
                    child: _DateInfo(
                      label: 'Son ödeme',
                      value: DateFormats.day(due),
                    ),
                  ),
                ],
              ),
              if (card.limitInCents > 0) ...[
                const SizedBox(height: AppSpacing.md),
                UsageBar(
                  ratio: total / card.limitInCents,
                  semanticsLabel: 'Limit kullanımı',
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  'Limitin %${(total / card.limitInCents * 100).round()} kadarı bu ekstrede · Limit ${MoneyFormatter.formatCents(card.limitInCents)}',
                  style: context.textStyles.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SectionHeader(title: 'Ekstredeki harcamalar'),
        expensesAsync.when(
          skipLoadingOnReload: false,
          loading: () => const SizedBox(
            height: 200,
            child: SkeletonList(itemCount: 3, padding: EdgeInsets.zero),
          ),
          error: (e, _) => ErrorStateView(error: e, compact: true),
          data: (expenses) => expenses.isEmpty
              ? const AppCard(
                  child: EmptyStateView(
                    compact: true,
                    icon: Icons.receipt_long_outlined,
                    title: 'Bu ekstrede harcama yok',
                    message: 'Bu karta ve döneme ait kayıt bulunmuyor.',
                  ),
                )
              : AppCard(
                  padding: const EdgeInsets.all(AppSpacing.xxs),
                  child: Column(
                    children: [
                      for (final e in expenses)
                        ExpenseTile(
                          expense: e,
                          showDate: true,
                          onTap: () => context.push('/expenses/${e.id}'),
                        ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

class _DateInfo extends StatelessWidget {
  final String label;
  final String value;
  const _DateInfo({required this.label, required this.value});

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
        const SizedBox(height: 2),
        Text(
          value,
          style: context.textStyles.titleSmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
