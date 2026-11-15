import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/expense_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_formats.dart';
import '../../core/utils/statement_calculator.dart';

/// Ay/dönem seçici: önceki-sonraki ay okları; etikete dokununca içinde bulunulan aya döner.
class PeriodSelector extends ConsumerWidget {
  const PeriodSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(selectedPeriodProvider);
    final current = StatementCalculator.periodOf(DateTime.now());
    final scheme = context.colors;

    void shift(int months) {
      ref.read(selectedPeriodProvider.notifier).state =
          StatementCalculator.shiftPeriod(period, months);
    }

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Önceki ay',
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: () => shift(-1),
          ),
          Semantics(
            label: 'Seçili dönem ${DateFormats.period(period)}',
            button: period != current,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: period == current
                  ? null
                  : () => ref.read(selectedPeriodProvider.notifier).state =
                        current,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Text(
                  DateFormats.period(period),
                  style: context.textStyles.titleSmall,
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Sonraki ay',
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed: () => shift(1),
          ),
        ],
      ),
    );
  }
}
