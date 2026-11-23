import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers/fuel_providers.dart';
import '../../../application/providers/repository_providers.dart';
import '../../../core/l10n/app_locale.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/expense.dart';
import '../../../domain/entities/fuel.dart';
import '../../../domain/entities/vehicle.dart';
import '../../widgets/app_card.dart';
import '../../widgets/common.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/state_views.dart';
import 'vehicle_editor.dart';

/// Kullanıcının araçları: ekleme, düzenleme ve silme.
class VehiclesScreen extends ConsumerWidget {
  const VehiclesScreen({super.key});

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    Vehicle vehicle,
  ) async {
    final repo = ref.read(vehicleRepositoryProvider);
    final confirmed = await showConfirmDialog(
      context,
      title: '{0} silinsin mi?'.trArgs([vehicle.name]),
      message: 'Araç listeden kaldırılır. Geçmiş yakıt kayıtlarınız silinmez ve aracın adıyla görünmeye devam eder.'
          .tr,
      confirmLabel: 'Sil'.tr,
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
    try {
      await repo.deleteVehicle(vehicle.id);
      if (context.mounted) context.showSuccess('Araç silindi.'.tr);
    } catch (e) {
      if (context.mounted) context.showError(e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehiclesAsync = ref.watch(vehiclesProvider);
    final entries = ref.watch(fuelExpensesProvider).valueOrNull ?? const [];
    final hasVehicles = vehiclesAsync.valueOrNull?.isNotEmpty ?? false;

    return Scaffold(
      appBar: AppBar(title: Text('Araçlarım'.tr)),
      floatingActionButton: hasVehicles
          ? FloatingActionButton.extended(
              heroTag: 'vehicle-add',
              onPressed: () => showVehicleEditor(context, ref),
              icon: const Icon(Icons.add_rounded),
              label: Text('Araç ekle'.tr),
            )
          : null,
      body: AsyncValueView<List<Vehicle>>(
        value: vehiclesAsync,
        onRetry: () => ref.invalidate(vehiclesProvider),
        data: (vehicles) => vehicles.isEmpty
            ? EmptyStateView(
                icon: Icons.directions_car_rounded,
                title: 'Henüz araç eklemediniz'.tr,
                message: 'Araç eklerseniz yakıt kayıtlarınız araca göre ayrılır; 100 km tüketimi ve km başına maliyet hesaplanır.'
                    .tr,
                actionLabel: 'Araç ekle'.tr,
                actionIcon: Icons.add_rounded,
                onAction: () => showVehicleEditor(context, ref),
              )
            : PageListView(
                padding: AppSpacing.screenPadding.copyWith(bottom: 96),
                children: [
                  for (final v in vehicles) ...[
                    _VehicleCard(
                      vehicle: v,
                      currentKm: _currentKm(v, entries),
                      onEdit: () =>
                          showVehicleEditor(context, ref, existing: v),
                      onDelete: () => _delete(context, ref, v),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                ],
              ),
      ),
    );
  }

  static int? _currentKm(Vehicle v, List<Expense> entries) {
    final fromEntries = FuelHistory.lastOdometer(entries, v.id);
    final own = v.odometerKm;
    if (fromEntries == null) return own;
    if (own == null) return fromEntries;
    return fromEntries > own ? fromEntries : own;
  }
}

class _VehicleCard extends StatelessWidget {
  final Vehicle vehicle;
  final int? currentKm;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _VehicleCard({
    required this.vehicle,
    required this.currentKm,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final subtitle = [
      ?vehicle.brand,
      FuelTypes.label(vehicle.fuelType),
      if (currentKm != null) FuelMath.formatKm(currentKm!),
    ].join(' · ');
    return AppCard(
      onTap: onEdit,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.xs,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.directions_car_rounded,
              color: scheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  vehicle.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textStyles.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textStyles.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Araç işlemleri'.tr,
            onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
            itemBuilder: (_) => [
              PopupMenuItem(value: 'edit', child: Text('Düzenle'.tr)),
              PopupMenuItem(
                value: 'delete',
                child: Text('Sil'.tr, style: TextStyle(color: scheme.error)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
