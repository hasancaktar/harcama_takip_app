import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../application/providers/auth_providers.dart';
import '../../../application/providers/repository_providers.dart';
import '../../../core/l10n/app_locale.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/fuel.dart';
import '../../../domain/entities/vehicle.dart';
import '../../widgets/dialogs.dart';

/// Araç ekleme / düzenleme penceresi. Kaydedilen aracı döner, vazgeçilirse `null`.
Future<Vehicle?> showVehicleEditor(
  BuildContext context,
  WidgetRef ref, {
  Vehicle? existing,
}) async {
  final uid = ref.read(currentUserIdProvider);
  if (uid == null) return null;
  final repo = ref.read(vehicleRepositoryProvider);
  final draft = await showDialog<Vehicle>(
    context: context,
    builder: (_) => _VehicleDialog(existing: existing, ownerUid: uid),
  );
  if (draft == null) return null;
  try {
    await repo.saveVehicle(draft);
    if (context.mounted) {
      context.showSuccess(
        existing == null ? 'Araç eklendi.'.tr : 'Araç güncellendi.'.tr,
      );
    }
    return draft;
  } catch (e) {
    if (context.mounted) context.showError(e);
    return null;
  }
}

class _VehicleDialog extends StatefulWidget {
  final Vehicle? existing;
  final String ownerUid;

  const _VehicleDialog({required this.existing, required this.ownerUid});

  @override
  State<_VehicleDialog> createState() => _VehicleDialogState();
}

class _VehicleDialogState extends State<_VehicleDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _brand = TextEditingController(text: widget.existing?.brand ?? '');
  late final _km = TextEditingController(
    text: widget.existing?.odometerKm?.toString() ?? '',
  );
  late String _fuelType = widget.existing?.fuelType ?? FuelTypes.gasoline;

  @override
  void dispose() {
    _name.dispose();
    _brand.dispose();
    _km.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final now = DateTime.now();
    final brand = _brand.text.trim();
    final km = int.tryParse(_km.text.trim());
    final existing = widget.existing;
    final vehicle = Vehicle(
      id: existing?.id ?? const Uuid().v4(),
      ownerUid: existing?.ownerUid ?? widget.ownerUid,
      name: _name.text.trim(),
      brand: brand.isEmpty ? null : brand,
      fuelType: _fuelType,
      odometerKm: km,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    Navigator.pop(context, vehicle);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.existing == null ? 'Araç ekle'.tr : 'Aracı düzenle'.tr,
      ),
      scrollable: true,
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _name,
              autofocus: widget.existing == null,
              textCapitalization: TextCapitalization.words,
              maxLength: Vehicle.maxNameLength,
              inputFormatters: [
                LengthLimitingTextInputFormatter(Vehicle.maxNameLength),
              ],
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Araca bir ad verin.'.tr
                  : null,
              decoration: InputDecoration(
                labelText: 'Araç adı'.tr,
                hintText: 'Örn. Egea Cross'.tr,
                counterText: '',
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              controller: _brand,
              textCapitalization: TextCapitalization.words,
              maxLength: Vehicle.maxBrandLength,
              inputFormatters: [
                LengthLimitingTextInputFormatter(Vehicle.maxBrandLength),
              ],
              decoration: InputDecoration(
                labelText: 'Marka (isteğe bağlı)'.tr,
                hintText: 'Örn. Fiat'.tr,
                counterText: '',
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text('Yakıt türü'.tr, style: context.textStyles.titleSmall),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              children: [
                for (final t in FuelTypes.all)
                  ChoiceChip(
                    label: Text(FuelTypes.label(t)),
                    selected: _fuelType == t,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _fuelType = t),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              controller: _km,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(7),
              ],
              decoration: InputDecoration(
                labelText: 'Güncel kilometre (isteğe bağlı)'.tr,
                suffixText: 'km',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Vazgeç'.tr),
        ),
        FilledButton(onPressed: _submit, child: Text('Kaydet'.tr)),
      ],
    );
  }
}
