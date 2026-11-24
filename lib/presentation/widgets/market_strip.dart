import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../application/providers/market_providers.dart';
import '../../core/l10n/app_locale.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_formats.dart';
import '../../domain/entities/market_rates.dart';
import 'app_card.dart';

/// Özet ekranının altındaki sade piyasa şeridi: dolar, euro, ons altın, bitcoin.
/// Ayarlardan kapatılabilir; veri yoksa veya servis hata verirse hiç görünmez.
class MarketStrip extends ConsumerWidget {
  const MarketStrip({super.key});

  static String label(String symbol) => switch (symbol) {
    'USD' => 'Dolar'.tr,
    'EUR' => 'Euro'.tr,
    'XAUUSD' => 'Ons altın'.tr,
    'BTC' => 'Bitcoin'.tr,
    _ => symbol,
  };

  static String formatPrice(MarketQuote q) => NumberFormat.currency(
    locale: 'tr_TR',
    symbol: q.currency == 'USD' ? r'$' : '₺',
    decimalDigits: q.symbol == 'BTC' ? 0 : 2,
  ).format(q.price);

  static String formatChange(double percent) =>
      '%${NumberFormat.decimalPatternDigits(locale: 'tr_TR', decimalDigits: 2).format(percent.abs())}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(showMarketRatesProvider)) return const SizedBox.shrink();
    final rates = ref.watch(marketRatesProvider).valueOrNull;
    final quotes = rates?.ordered ?? const <MarketQuote>[];
    if (rates == null || quotes.isEmpty) return const SizedBox.shrink();

    final scheme = context.colors;
    final muted = context.textStyles.labelSmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: AppCard(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.show_chart_rounded,
                  size: 16,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.xxs),
                Expanded(child: Text('Piyasalar'.tr, style: muted)),
                Text(DateFormats.time(rates.fetchedAt), style: muted),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                for (final q in quotes) Expanded(child: _QuoteCell(quote: q)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QuoteCell extends StatelessWidget {
  final MarketQuote quote;
  const _QuoteCell({required this.quote});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final change = quote.changePercent;
    final color = change > 0
        ? context.semantic.success
        : change < 0
        ? scheme.error
        : scheme.onSurfaceVariant;
    final icon = change > 0
        ? Icons.arrow_drop_up_rounded
        : change < 0
        ? Icons.arrow_drop_down_rounded
        : Icons.remove_rounded;
    final price = MarketStrip.formatPrice(quote);
    final changeText = MarketStrip.formatChange(change);

    return Semantics(
      label: '${MarketStrip.label(quote.symbol)} $price, $changeText',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(right: AppSpacing.xxs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              MarketStrip.label(quote.symbol),
              maxLines: 1,
              style: context.textStyles.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                price,
                style: context.textStyles.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 16, color: color),
                  Text(
                    changeText,
                    style: context.textStyles.labelSmall?.copyWith(
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
