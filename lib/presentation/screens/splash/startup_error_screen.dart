import 'package:harcama_takip/core/l10n/app_locale.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';

/// Firebase başlatılamadığında gösterilen kullanıcı dostu ekran.
/// Teknik ayrıntılar yalnızca geliştirme (debug) modunda gösterilir.
class StartupErrorScreen extends StatelessWidget {
  final String? technicalDetails;

  const StartupErrorScreen({super.key, this.technicalDetails});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppSpacing.maxAuthWidth,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cloud_off_rounded, size: 56, color: scheme.error),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Uygulama başlatılamadı'.tr,
                    style: context.textStyles.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Sunucu bağlantısı kurulamadı. İnternet bağlantınızı kontrol edip uygulamayı yeniden başlatın.'
                        .tr,
                    style: context.textStyles.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (technicalDetails != null) ...[
                    const SizedBox(height: AppSpacing.lg),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusSm,
                        ),
                      ),
                      child: SelectableText(
                        'Geliştirici ayrıntısı:\n{0}'.trArgs([
                          technicalDetails,
                        ]),
                        style: context.textStyles.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
