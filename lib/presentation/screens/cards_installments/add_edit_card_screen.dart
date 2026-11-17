import 'package:harcama_takip/core/l10n/app_locale.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../application/providers/auth_providers.dart';
import '../../../application/providers/card_providers.dart';
import '../../../application/providers/repository_providers.dart';
import '../../../application/providers/team_providers.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/utils/validators.dart';
import '../../../domain/entities/credit_card.dart';
import '../../widgets/common.dart';
import '../../widgets/credit_card_visual.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/state_views.dart';

class AddEditCardScreen extends ConsumerWidget {
  final String? cardId;
  const AddEditCardScreen({super.key, this.cardId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (cardId == null) return const _CardForm(existing: null);
    final cardAsync = ref.watch(cardByIdProvider(cardId!));
    final uid = ref.watch(currentUserIdProvider);
    return cardAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: Text('Kartı düzenle'.tr)),
        body: const LoadingView(),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: ErrorStateView(error: e),
      ),
      data: (card) {
        if (card == null || !card.isActive || card.ownerUid != uid) {
          return Scaffold(
            appBar: AppBar(),
            body: EmptyStateView(
              icon: Icons.credit_card_off_rounded,
              title: 'Kart düzenlenemez'.tr,
              message:
                  'Kart bulunamadı ya da yalnızca kart sahibi düzenleyebilir.'
                      .tr,
            ),
          );
        }
        return _CardForm(existing: card);
      },
    );
  }
}

class _CardForm extends ConsumerStatefulWidget {
  final CreditCard? existing;
  const _CardForm({required this.existing});

  @override
  ConsumerState<_CardForm> createState() => _CardFormState();
}

class _CardFormState extends ConsumerState<_CardForm> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(
    text: widget.existing?.name ?? '',
  );
  late final _bankController = TextEditingController(
    text: widget.existing?.bankName ?? '',
  );
  late final _last4Controller = TextEditingController(
    text: widget.existing?.last4Digits ?? '',
  );
  late final _limitController = TextEditingController(
    text: MoneyFormatter.formatForInput(widget.existing?.limitInCents ?? 0),
  );
  late int _cutoffDay = widget.existing?.cutoffDay ?? 15;
  late int _dueDays = widget.existing?.paymentDueDaysAfterCutoff ?? 10;
  late String _colorHex =
      widget.existing?.colorHex ?? AppColors.pickerHexColors.first;
  late bool _shared = widget.existing?.isSharedWithTeam ?? false;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    for (final c in [_nameController, _bankController, _last4Controller]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bankController.dispose();
    _last4Controller.dispose();
    _limitController.dispose();
    super.dispose();
  }

  CreditCard _buildCard(String uid, String? teamId) {
    final now = DateTime.now();
    final existing = widget.existing;
    final sharedTeam = _shared ? (existing?.teamId ?? teamId) : null;
    return CreditCard(
      id: existing?.id ?? const Uuid().v4(),
      ownerUid: existing?.ownerUid ?? uid,
      teamId: sharedTeam,
      isSharedWithTeam: _shared && sharedTeam != null,
      name: _nameController.text.trim().isEmpty
          ? 'Kartım'.tr
          : _nameController.text.trim(),
      bankName: _bankController.text.trim().isEmpty
          ? 'Banka'.tr
          : _bankController.text.trim(),
      last4Digits: _last4Controller.text.trim().padLeft(4, '•'),
      colorHex: _colorHex,
      limitInCents: MoneyFormatter.parseToCents(_limitController.text),
      cutoffDay: _cutoffDay,
      paymentDueDaysAfterCutoff: _dueDays,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final uid = ref.read(currentUserIdProvider);
    if (uid == null) return;
    setState(() => _saving = true);
    try {
      final card = _buildCard(uid, ref.read(activeTeamProvider)?.id);
      await ref.read(cardRepositoryProvider).saveCard(card);
      if (!mounted) return;
      context.showSuccess(
        _isEdit ? 'Kart güncellendi.'.tr : 'Kart eklendi.'.tr,
      );
      context.pop();
    } catch (e) {
      if (mounted) {
        context.showError(e);
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _deactivate() async {
    final card = widget.existing!;
    final ok = await showConfirmDialog(
      context,
      title: 'Kart kaldırılsın mı?'.tr,
      message: '"{0}" listeden kaldırılacak. Bu karta ait geçmiş harcamalar ve taksit planları silinmez.'
          .trArgs([card.name]),
      confirmLabel: 'Kartı kaldır'.tr,
      destructive: true,
    );
    if (!ok || !mounted) return;
    try {
      await ref.read(cardRepositoryProvider).deactivateCard(card.id);
      if (!mounted) return;
      context.showSuccess('Kart kaldırıldı.'.tr);
      context.go('/cards');
    } catch (e) {
      if (mounted) context.showError(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeTeam = ref.watch(activeTeamProvider);
    final uid = ref.watch(currentUserIdProvider) ?? '';
    final scheme = context.colors;
    final preview = _buildCard(uid, activeTeam?.id);
    final canShare = activeTeam != null || (widget.existing?.teamId != null);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Kartı düzenle'.tr : 'Yeni kredi kartı'.tr),
        actions: [
          if (_isEdit)
            IconButton(
              tooltip: 'Kartı kaldır'.tr,
              icon: Icon(Icons.delete_outline_rounded, color: scheme.error),
              onPressed: _deactivate,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: PageListView(
          maxWidth: AppSpacing.maxFormWidth,
          children: [
            ExcludeSemantics(child: CreditCardVisual(card: preview)),
            const SizedBox(height: AppSpacing.md),
            InlineMessage(
              tone: MessageTone.info,
              message: 'Güvenliğiniz için yalnızca kart adı ve son 4 hane saklanır. Kart numarası, son kullanma tarihi ve CVV asla istenmez.'
                  .tr,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              validator: Validators.requiredText(
                'Kart adı'.tr,
                maxLength: AppConstants.maxNameLength,
              ),
              decoration: InputDecoration(
                labelText: 'Kart adı'.tr,
                hintText: 'Örn. Bonus Platinum'.tr,
                prefixIcon: Icon(Icons.credit_card_rounded),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _bankController,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              validator: Validators.requiredText(
                'Banka adı'.tr,
                maxLength: AppConstants.maxNameLength,
              ),
              decoration: InputDecoration(
                labelText: 'Banka'.tr,
                hintText: 'Örn. Garanti BBVA'.tr,
                prefixIcon: Icon(Icons.account_balance_rounded),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _last4Controller,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                    ],
                    validator: Validators.last4Digits,
                    decoration: InputDecoration(
                      labelText: 'Son 4 hane'.tr,
                      hintText: '1234',
                      prefixIcon: Icon(Icons.pin_outlined),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: TextFormField(
                    controller: _limitController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                    ],
                    validator: Validators.optionalAmount,
                    decoration: InputDecoration(
                      labelText: 'Limit (isteğe bağlı)'.tr,
                      prefixText: '₺ ',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<int>(
              initialValue: _cutoffDay,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Hesap kesim günü'.tr,
                helperText: 'Ayın 31\'i seçilirse kısa aylarda son gün kesim kabul edilir.'
                    .tr,
                prefixIcon: Icon(Icons.event_repeat_rounded),
              ),
              items: [
                for (var d = 1; d <= 31; d++)
                  DropdownMenuItem(
                    value: d,
                    child: Text('Her ayın {0}. günü'.trArgs([d])),
                  ),
              ],
              onChanged: (v) => setState(() => _cutoffDay = v ?? _cutoffDay),
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<int>(
              initialValue: _dueDays,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Son ödeme günü'.tr,
                prefixIcon: Icon(Icons.event_available_rounded),
              ),
              items: [
                for (final d in const [5, 7, 8, 10, 12, 14, 15, 20])
                  DropdownMenuItem(
                    value: d,
                    child: Text('Kesimden {0} gün sonra'.trArgs([d])),
                  ),
              ],
              onChanged: (v) => setState(() => _dueDays = v ?? _dueDays),
            ),
            const SizedBox(height: AppSpacing.md),
            Text('Kart rengi'.tr, style: context.textStyles.titleSmall),
            const SizedBox(height: AppSpacing.xs),
            ColorPickerRow(
              selectedHex: _colorHex,
              onSelected: (hex) => setState(() => _colorHex = hex),
            ),
            if (canShare) ...[
              const SizedBox(height: AppSpacing.md),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _shared,
                onChanged: (v) => setState(() => _shared = v),
                title: Text(
                  '{0} ile paylaş'.trArgs([activeTeam?.name ?? 'Takım'.tr]),
                ),
                subtitle: Text(
                  'Takım üyeleri bu kartı takım harcamalarında seçebilir ve ekstresini görebilir.'
                      .tr,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: _isEdit ? 'Değişiklikleri kaydet'.tr : 'Kartı kaydet'.tr,
              icon: Icons.check_rounded,
              onPressed: _save,
              isLoading: _saving,
            ),
          ],
        ),
      ),
    );
  }
}
