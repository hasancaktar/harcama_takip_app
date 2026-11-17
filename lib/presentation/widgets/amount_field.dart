import 'package:flutter/material.dart';
import 'package:harcama_takip/core/l10n/app_locale.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/thousands_separator_input_formatter.dart';
import '../../core/utils/validators.dart';

/// Büyük ve hızlı tutar girişi. Yalnızca rakam, virgül ve nokta kabul eder.
class AmountField extends StatelessWidget {
  final TextEditingController controller;
  final String? label;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final FocusNode? focusNode;
  final TextInputAction textInputAction;

  const AmountField({
    super.key,
    required this.controller,
    this.label,
    this.autofocus = false,
    this.onChanged,
    this.focusNode,
    this.textInputAction = TextInputAction.next,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label ?? 'Tutar'.tr,
            style: context.textStyles.labelLarge?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          TextFormField(
            controller: controller,
            focusNode: focusNode,
            autofocus: autofocus,
            onChanged: onChanged,
            textInputAction: textInputAction,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: const [
              ThousandsSeparatorInputFormatter(),
            ],
            validator: Validators.amount,
            style: context.textStyles.displaySmall?.copyWith(
              color: scheme.onSurface,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
            decoration: InputDecoration(
              hintText: '0,00',
              prefixText: '₺ ',
              prefixStyle: context.textStyles.displaySmall?.copyWith(
                color: scheme.primary,
              ),
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                vertical: AppSpacing.xs,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
