import 'package:harcama_takip/core/l10n/app_locale.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/entities/admin_models.dart';

/// "Yenilikler" penceresi: sürümde eklenen, kaldırılan ve düzeltilenler.
Future<void> showReleaseNotesDialog(BuildContext context, ReleaseNotes notes) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => ReleaseNotesDialog(notes: notes),
  );
}

class ReleaseNotesDialog extends StatelessWidget {
  final ReleaseNotes notes;
  const ReleaseNotesDialog({super.key, required this.notes});

  @override
  Widget build(BuildContext context) {
    final code = AppLocale.code;
    final scheme = context.colors;
    final sections = [
      (
        Icons.add_circle_outline_rounded,
        'Yeni'.tr,
        notes.added(code),
        scheme.primary,
      ),
      (
        Icons.build_circle_outlined,
        'Düzeltilenler'.tr,
        notes.fixed(code),
        context.semantic.success,
      ),
      (
        Icons.remove_circle_outline_rounded,
        'Kaldırılanlar'.tr,
        notes.removed(code),
        scheme.onSurfaceVariant,
      ),
    ];
    return AlertDialog(
      icon: Icon(Icons.auto_awesome_rounded, color: scheme.primary),
      title: Text('Yenilikler · {0}'.trArgs([notes.version])),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (icon, title, items, color) in sections)
                if (items.isNotEmpty) ...[
                  Row(
                    children: [
                      Icon(icon, size: 20, color: color),
                      const SizedBox(width: AppSpacing.xs),
                      Text(title, style: context.textStyles.titleSmall),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  for (final item in items)
                    Padding(
                      padding: const EdgeInsets.only(left: 28, bottom: 4),
                      child: Text('• $item'),
                    ),
                  const SizedBox(height: AppSpacing.sm),
                ],
            ],
          ),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Harika'.tr),
        ),
      ],
    );
  }
}
