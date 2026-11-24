import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/l10n/app_locale.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_formats.dart';
import '../../core/utils/money_formatter.dart';
import '../../core/utils/statement_calculator.dart';
import '../../domain/entities/expense.dart';
import '../../domain/entities/fuel.dart';
import 'common.dart';

/// Tüm listelerde kullanılan tutarlı harcama satırı.
class ExpenseTile extends StatelessWidget {
  final Expense expense;
  final VoidCallback? onTap;
  final String? memberName;
  final bool showDate;

  const ExpenseTile({
    super.key,
    required this.expense,
    this.onTap,
    this.memberName,
    this.showDate = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final payment = AppConstants.getPaymentMethod(expense.paymentMethod);
    final dateLabel = showDate
        ? DateFormats.dayShort(expense.date)
        : DateFormats.time(expense.date);
    final periodDiffers =
        expense.statementPeriod.isNotEmpty &&
        expense.statementPeriod != StatementCalculator.periodOf(expense.date);

    final fuel = expense.fuel;
    final meta = <String>[
      dateLabel,
      if (fuel != null && fuel.hasVolume)
        FuelMath.formatLiters(fuel.litersX100),
      if (expense.cardLast4 != null &&
          (expense.isCreditCard || expense.paymentMethod == 'debit_card'))
        '•••• ${expense.cardLast4}'
      else
        payment.name,
      ?memberName,
    ].join(' · ');

    final amount = MoneyFormatter.formatCents(
      expense.amountInCents,
      currency: expense.currency,
    );

    return Semantics(
      button: onTap != null,
      label: '${expense.title}, $amount, $meta',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: 10,
          ),
          child: Row(
            children: [
              CategoryIcon(categoryId: expense.category),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      expense.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textStyles.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textStyles.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width * 0.42,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        amount,
                        style: context.textStyles.titleSmall?.copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    if (expense.isInstallment)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Pill(
                          label: '{0}/{1} taksit'.trArgs([
                            expense.installmentNumber,
                            expense.totalInstallments,
                          ]),
                          color: scheme.primary,
                        ),
                      )
                    else if (expense.isRecurring)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Pill(
                          icon: Icons.autorenew_rounded,
                          label: 'Otomatik'.tr,
                          color: scheme.tertiary,
                        ),
                      )
                    else if (periodDiffers)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Pill(
                          label: '{0} ekstresi'.trArgs([
                            DateFormats.periodShort(expense.statementPeriod),
                          ]),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
