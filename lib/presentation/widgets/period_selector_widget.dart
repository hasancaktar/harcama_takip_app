import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../application/providers/expense_providers.dart';

class PeriodSelectorWidget extends ConsumerWidget {
  const PeriodSelectorWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentPeriod = ref.watch(selectedPeriodProvider);
    final theme = Theme.of(context);

    // YYYY-MM çözümle
    final parts = currentPeriod.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final currentDate = DateTime(year, month, 1);

    final String monthName = DateFormat('MMMM yyyy', 'tr_TR').format(currentDate);

    void changeMonth(int offset) {
      final newDate = DateTime(year, month + offset, 1);
      final newPeriod = '${newDate.year}-${newDate.month.toString().padLeft(2, '0')}';
      ref.read(selectedPeriodProvider.notifier).state = newPeriod;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded, size: 22),
            onPressed: () => changeMonth(-1),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 8),
          Text(
            monthName,
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded, size: 22),
            onPressed: () => changeMonth(1),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}
