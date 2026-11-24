import 'package:harcama_takip/core/l10n/app_locale.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/color_utils.dart';
import '../../domain/entities/credit_card.dart';
import '../../domain/entities/debit_card.dart';
import 'app_card.dart';

/// Kredi kartı görünümünde kart özeti.
class CreditCardVisual extends StatelessWidget {
  final CreditCard card;
  final VoidCallback? onTap;
  final Widget? footer;
  final bool showOwnerBadge;

  const CreditCardVisual({
    super.key,
    required this.card,
    this.onTap,
    this.footer,
    this.showOwnerBadge = false,
  });

  @override
  Widget build(BuildContext context) => _CardFace(
    bankName: card.bankName,
    name: card.name,
    last4: card.last4Digits,
    colorHex: card.colorHex,
    shared: card.isSharedWithTeam,
    corner: 'Kesim: {0}'.trArgs([card.cutoffDay]),
    semanticLabel: '{0} {1}, son dört hane {2}, kesim günü {3}'.trArgs([
      card.bankName,
      card.name,
      card.last4Digits,
      card.cutoffDay,
    ]),
    onTap: onTap,
    footer: footer,
  );
}

/// Banka kartı görünümü (kesim günü yerine "Banka kartı" yazar).
class DebitCardVisual extends StatelessWidget {
  final DebitCard card;
  final VoidCallback? onTap;
  final Widget? footer;

  const DebitCardVisual({
    super.key,
    required this.card,
    this.onTap,
    this.footer,
  });

  @override
  Widget build(BuildContext context) => _CardFace(
    bankName: card.bankName,
    name: card.name,
    last4: card.last4Digits,
    colorHex: card.colorHex,
    shared: false,
    corner: 'Banka kartı'.tr,
    semanticLabel: '{0} {1}, banka kartı, son dört hane {2}'.trArgs([
      card.bankName,
      card.name,
      card.last4Digits,
    ]),
    onTap: onTap,
    footer: footer,
  );
}

class _CardFace extends StatelessWidget {
  final String bankName;
  final String name;
  final String last4;
  final String colorHex;
  final bool shared;
  final String corner;
  final String semanticLabel;
  final VoidCallback? onTap;
  final Widget? footer;

  const _CardFace({
    required this.bankName,
    required this.name,
    required this.last4,
    required this.colorHex,
    required this.shared,
    required this.corner,
    required this.semanticLabel,
    this.onTap,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final base = ColorUtils.fromHex(colorHex);
    final fg = ColorUtils.onColor(base);
    final muted = fg.withValues(alpha: 0.78);

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.lg - 4),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [base, Color.lerp(base, Colors.black, 0.35)!],
      ),
      semanticLabel: semanticLabel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  bankName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textStyles.titleMedium?.copyWith(color: fg),
                ),
              ),
              if (shared)
                Padding(
                  padding: const EdgeInsets.only(left: AppSpacing.xs),
                  child: Icon(Icons.groups_rounded, color: muted, size: 20),
                ),
              Padding(
                padding: const EdgeInsets.only(left: AppSpacing.xs),
                child: Icon(Icons.contactless_rounded, color: muted),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            '••••  ••••  ••••  $last4',
            style: context.textStyles.titleLarge?.copyWith(
              color: fg,
              letterSpacing: 1.5,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textStyles.bodyMedium?.copyWith(color: muted),
                ),
              ),
              Text(
                corner,
                style: context.textStyles.labelLarge?.copyWith(color: fg),
              ),
            ],
          ),
          if (footer != null) ...[
            const SizedBox(height: AppSpacing.sm),
            DefaultTextStyle.merge(
              style: TextStyle(color: fg),
              child: footer!,
            ),
          ],
        ],
      ),
    );
  }
}
