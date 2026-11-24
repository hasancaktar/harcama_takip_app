import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers/fuel_providers.dart';
import '../../../application/services/fuel_stats.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/l10n/app_locale.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_formats.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../domain/entities/expense.dart';
import '../../../domain/entities/fuel.dart';
import '../../widgets/app_card.dart';
import '../../widgets/common.dart';
import '../../widgets/state_views.dart';
import 'fuel_price_card.dart';

const _newFuelRoute = '/expenses/new?category=${AppConstants.fuelCategoryId}';

/// Yakıt takibi: maliyet, hacim, ortalama litre fiyatı ve 100 km tüketimi.
class FuelScreen extends ConsumerWidget {
  const FuelScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(fuelExpensesProvider);
    final hasEntries = expensesAsync.valueOrNull?.isNotEmpty ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text('Yakıt takibi'.tr),
        actions: [
          IconButton(
            tooltip: 'Araçlarım'.tr,
            icon: const Icon(Icons.directions_car_rounded),
            onPressed: () => context.push('/fuel/vehicles'),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      floatingActionButton: hasEntries
          ? FloatingActionButton.extended(
              heroTag: 'fuel-add',
              onPressed: () => context.push(_newFuelRoute),
              icon: const Icon(Icons.local_gas_station_rounded),
              label: Text('Yakıt ekle'.tr),
            )
          : null,
      body: AsyncValueView<List<Expense>>(
        value: expensesAsync,
        onRetry: () => ref.invalidate(fuelExpensesProvider),
        data: (expenses) => expenses.isEmpty
            ? PageListView(
                children: [
                  const FuelPriceCard(),
                  EmptyStateView(
                    compact: true,
                    icon: Icons.local_gas_station_rounded,
                    title: 'Henüz yakıt kaydı yok'.tr,
                    message: 'Yakıt aldığınızda tutarı veya litreyi girin. Ortalama litre fiyatınız, harcamanız ve aracınızın 100 km tüketimi burada hesaplanır.'
                        .tr,
                    actionLabel: 'Yakıt ekle'.tr,
                    actionIcon: Icons.local_gas_station_rounded,
                    onAction: () => context.push(_newFuelRoute),
                  ),
                ],
              )
            : const _FuelSummary(),
      ),
    );
  }
}

class _FuelSummary extends ConsumerWidget {
  const _FuelSummary();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(fuelStatsProvider);
    final range = ref.watch(fuelRangeProvider);
    final vehicleKey = ref.watch(fuelVehicleFilterProvider);
    final options = ref.watch(fuelVehicleOptionsProvider);
    final scheme = context.colors;

    String vehicleLabel(String key) =>
        options[key] ??
        (key == FuelVehicleKey.none
            ? 'Araçsız kayıtlar'.tr
            : 'Silinmiş araç'.tr);

    return PageListView(
      padding: AppSpacing.screenPadding.copyWith(bottom: 96),
      children: [
        const FuelPriceCard(),
        const SizedBox(height: AppSpacing.sm),
        if (options.length > 1) ...[
          DropdownButtonFormField<String>(
            key: ValueKey('fuel-vehicle-$vehicleKey-${options.length}'),
            initialValue: options.containsKey(vehicleKey) ? vehicleKey : '',
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Araç'.tr,
              prefixIcon: const Icon(Icons.directions_car_rounded),
            ),
            items: [
              DropdownMenuItem(value: '', child: Text('Tüm araçlar'.tr)),
              for (final key in options.keys)
                DropdownMenuItem(
                  value: key,
                  child: Text(
                    vehicleLabel(key),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (v) =>
                ref.read(fuelVehicleFilterProvider.notifier).state =
                    v == null || v.isEmpty ? null : v,
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final r in FuelRange.values)
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.xs),
                  child: ChoiceChip(
                    label: Text(r.label),
                    selected: range == r,
                    showCheckmark: false,
                    onSelected: (_) =>
                        ref.read(fuelRangeProvider.notifier).state = r,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (stats.isEmpty)
          AppCard(
            child: EmptyStateView(
              compact: true,
              icon: Icons.event_busy_rounded,
              title: 'Bu aralıkta yakıt kaydı yok'.tr,
              message: 'Farklı bir tarih aralığı veya araç seçin.'.tr,
            ),
          )
        else ...[
          Text(
            '{0} dolum · {1} – {2}'.trArgs([
              stats.fillCount,
              DateFormats.day(stats.spanStart!),
              DateFormats.day(stats.spanEnd!),
            ]),
            style: context.textStyles.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _StatGrid(stats: stats),
          if (stats.averageConsumption == null) ...[
            const SizedBox(height: AppSpacing.sm),
            InlineMessage(
              tone: MessageTone.info,
              message: '100 km tüketimi için aynı araçta en az iki dolumda kilometreyi girip "Depoyu fulledim"i seçin.'
                  .tr,
            ),
          ],
          SectionHeader(title: 'Dolumlar'.tr),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
            child: Column(
              children: [
                for (var i = 0; i < stats.entries.length; i++) ...[
                  if (i > 0) const Divider(height: 1, indent: 64),
                  _FillTile(expense: stats.entries[i]),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _StatGrid extends StatelessWidget {
  final FuelStats stats;
  const _StatGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    String money(int? cents) =>
        cents == null ? '—' : MoneyFormatter.formatCents(cents);
    String liters(int? x100) =>
        x100 == null ? '—' : FuelMath.formatLiters(x100);
    String consumption(double? v) =>
        v == null ? '—' : FuelMath.formatConsumption(v);

    final cards = [
      _StatCard(
        icon: Icons.payments_rounded,
        title: 'Maliyet'.tr,
        caption: 'Toplam'.tr,
        value: money(stats.totalCostCents),
        left: ('Günlük'.tr, money(stats.dailyCostCents)),
        right: ('Km başına'.tr, money(stats.costPerKmCents)),
      ),
      _StatCard(
        icon: Icons.local_gas_station_rounded,
        title: 'Hacim'.tr,
        caption: 'Toplam'.tr,
        value: stats.volumeCount == 0 ? '—' : liters(stats.litersX100),
        left: ('Dolum başına'.tr, liters(stats.averageLitersPerFillX100)),
        right: ('Günlük'.tr, liters(stats.dailyLitersX100)),
      ),
      _StatCard(
        icon: Icons.sell_rounded,
        title: 'Ortalama fiyat'.tr,
        caption: 'Litre başına'.tr,
        value: money(stats.averagePriceCents),
        left: ('En düşük'.tr, money(stats.minPriceCents)),
        right: ('En yüksek'.tr, money(stats.maxPriceCents)),
      ),
      _StatCard(
        icon: Icons.speed_rounded,
        title: 'Yakıt tüketimi'.tr,
        caption: '100 km ortalaması'.tr,
        value: consumption(stats.averageConsumption),
        left: ('En iyi'.tr, consumption(stats.bestConsumption)),
        right: ('En kötü'.tr, consumption(stats.worstConsumption)),
      ),
    ];

    return LayoutBuilder(
      builder: (context, c) {
        // 360 dp telefonlarda iki sütun; çok dar ekranda tek sütun.
        final cols = c.maxWidth >= 1000 ? 4 : (c.maxWidth >= 300 ? 2 : 1);
        final width = (c.maxWidth - (cols - 1) * AppSpacing.sm) / cols;
        return Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final card in cards) SizedBox(width: width, child: card),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String caption;
  final String value;
  final (String, String) left;
  final (String, String) right;

  const _StatCard({
    required this.icon,
    required this.title,
    required this.caption,
    required this.value,
    required this.left,
    required this.right,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final accent = AppConstants.getCategoryById(AppConstants.fuelCategoryId)
        .color;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final valueColor = isDark
        ? Color.lerp(accent, Colors.white, 0.35)!
        : accent;
    final muted = context.textStyles.labelSmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );

    Widget sub((String, String) item, CrossAxisAlignment align) => Expanded(
      child: Column(
        crossAxisAlignment: align,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(item.$1, style: muted),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              item.$2,
              style: context.textStyles.labelLarge?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.sm + 2),
      semanticLabel:
          '$title: $value. ${left.$1} ${left.$2}, ${right.$1} ${right.$2}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: isDark ? 0.24 : 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: valueColor),
              ),
              const SizedBox(width: AppSpacing.xs),
              // Dar ekranda kesilmek yerine sığacak kadar küçülür.
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(title, style: context.textStyles.titleSmall),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(caption, style: muted),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: context.textStyles.headlineSmall?.copyWith(
                color: valueColor,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const Divider(height: AppSpacing.md),
          Row(
            children: [
              sub(left, CrossAxisAlignment.start),
              const SizedBox(width: AppSpacing.xs),
              sub(right, CrossAxisAlignment.end),
            ],
          ),
        ],
      ),
    );
  }
}

class _FillTile extends StatelessWidget {
  final Expense expense;
  const _FillTile({required this.expense});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final fuel = expense.fuel;
    final meta = <String>[
      if (fuel != null && fuel.hasVolume)
        '${FuelMath.formatLiters(fuel.litersX100)} × ${MoneyFormatter.formatCents(fuel.pricePerLiterCents)}',
      if (fuel?.odometerKm != null) FuelMath.formatKm(fuel!.odometerKm!),
      if (fuel?.vehicleName != null) fuel!.vehicleName!,
    ].join(' · ');
    final amount = MoneyFormatter.formatCents(expense.amountInCents);

    return InkWell(
      onTap: () => context.push('/expenses/${expense.id}'),
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
                    DateFormats.day(expense.date),
                    style: context.textStyles.titleSmall,
                  ),
                  if (meta.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      meta,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.textStyles.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  amount,
                  style: context.textStyles.titleSmall?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                if (fuel != null && !fuel.fullTank)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Pill(label: 'Kısmi dolum'.tr),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
