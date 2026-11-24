import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers/fuel_providers.dart';
import '../../../core/l10n/app_locale.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../domain/entities/fuel.dart';
import '../../../domain/entities/fuel_prices.dart';
import '../../widgets/app_card.dart';

/// Seçili ilin güncel benzin, motorin ve LPG fiyatları ve il seçimi.
/// Varsayılan il İstanbul. Fiyatlar alınamazsa yalnızca il seçimi görünür;
/// hata gösterilmez.
class FuelPriceCard extends ConsumerWidget {
  const FuelPriceCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cityCode = ref.watch(fuelPriceCityProvider);
    final prices = ref.watch(selectedCityFuelPricesProvider);
    final scheme = context.colors;
    final cityName = cityCode == null
        ? null
        : TurkishProvinces.nameOf(cityCode);
    final muted = context.textStyles.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );

    return AppCard(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.xs,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Güncel pompa fiyatları'.tr,
                  style: context.textStyles.titleSmall,
                ),
              ),
              TextButton.icon(
                key: const ValueKey('fuel-price-city'),
                onPressed: () => _pickCity(context, ref, cityCode),
                icon: const Icon(Icons.place_outlined, size: 18),
                label: Text(cityName ?? 'İl seçin'.tr),
              ),
            ],
          ),
          if (prices != null) ...[
            Row(
              children: [
                for (final type in FuelTypes.all)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(FuelTypes.label(type), style: muted),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            prices.priceOf(type) == null
                                ? '—'
                                : MoneyFormatter.formatCents(
                                    prices.priceOf(type)!,
                                  ),
                            style: context.textStyles.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _pickCity(
    BuildContext context,
    WidgetRef ref,
    String? current,
  ) async {
    final controller = ref.read(fuelPriceCityProvider.notifier);
    final code = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _CityPicker(current: current),
    );
    if (code != null) await controller.set(code);
  }
}

class _CityPicker extends StatefulWidget {
  final String? current;
  const _CityPicker({required this.current});

  @override
  State<_CityPicker> createState() => _CityPickerState();
}

class _CityPickerState extends State<_CityPicker> {
  String _query = '';

  static const _alphabet = 'abcçdefgğhıijklmnoöprsştuüvyz';

  /// Türkçe küçük harf ("İ" → "i", "I" → "ı").
  static String _lower(String s) =>
      s.replaceAll('İ', 'i').replaceAll('I', 'ı').toLowerCase();

  /// Arama için harf farklarını yok sayar ("istanbul" → "İstanbul").
  static String _plain(String s) =>
      _lower(s)
          .replaceAll('ç', 'c')
          .replaceAll('ğ', 'g')
          .replaceAll('ı', 'i')
          .replaceAll('ö', 'o')
          .replaceAll('ş', 's')
          .replaceAll('ü', 'u')
          .replaceAll('â', 'a');

  static int _compare(String a, String b) {
    final x = _lower(a).replaceAll('â', 'a');
    final y = _lower(b).replaceAll('â', 'a');
    for (var i = 0; i < x.length && i < y.length; i++) {
      final d = _alphabet.indexOf(x[i]).compareTo(_alphabet.indexOf(y[i]));
      if (d != 0) return d;
    }
    return x.length.compareTo(y.length);
  }

  @override
  Widget build(BuildContext context) {
    final provinces = [
      for (var i = 0; i < TurkishProvinces.names.length; i++)
        ('${i + 1}', TurkishProvinces.names[i]),
    ]..sort((a, b) => _compare(a.$2, b.$2));
    final q = _plain(_query.trim());
    final visible = q.isEmpty
        ? provinces
        : provinces.where((p) => _plain(p.$2).contains(q)).toList();

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.75,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.xs,
            ),
            child: TextField(
              autofocus: false,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'İl ara'.tr,
                prefixIcon: const Icon(Icons.search_rounded),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: visible.length,
              itemBuilder: (context, i) {
                final (code, name) = visible[i];
                return ListTile(
                  title: Text(name),
                  trailing: code == widget.current
                      ? Icon(Icons.check_rounded, color: context.colors.primary)
                      : null,
                  onTap: () => Navigator.pop(context, code),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
