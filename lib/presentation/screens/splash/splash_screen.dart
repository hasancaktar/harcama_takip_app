import 'package:harcama_takip/core/l10n/app_locale.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';

/// Oturum durumu belirlenirken gösterilir. Yönlendirme tamamen router tarafından yapılır;
/// yapay bekleme süresi yoktur.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppLogo(size: 72),
            const SizedBox(height: AppSpacing.lg),
            Text(AppConstants.appName, style: context.textStyles.headlineSmall),
            const SizedBox(height: AppSpacing.xs),
            Text(
              AppConstants.appTagline,
              style: context.textStyles.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                semanticsLabel: 'Yükleniyor'.tr,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Marka logosu (cüzdan simgesi, yuvarlatılmış kare zemin).
class AppLogo extends StatelessWidget {
  final double size;
  const AppLogo({super.key, this.size = 56});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              scheme.primary,
              Color.lerp(scheme.primary, scheme.secondary, 0.55)!,
            ],
          ),
          borderRadius: BorderRadius.circular(size * 0.3),
        ),
        child: Icon(
          Icons.account_balance_wallet_rounded,
          color: scheme.onPrimary,
          size: size * 0.52,
        ),
      ),
    );
  }
}
