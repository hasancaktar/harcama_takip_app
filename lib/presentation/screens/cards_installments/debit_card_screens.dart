import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../application/providers/auth_providers.dart';
import '../../../application/providers/card_providers.dart';
import '../../../application/providers/repository_providers.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/l10n/app_locale.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_formats.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/utils/statement_calculator.dart';
import '../../../core/utils/validators.dart';
import '../../../domain/entities/debit_card.dart';
import '../../../domain/entities/expense.dart';
import '../../widgets/app_card.dart';
import '../../widgets/common.dart';
import '../../widgets/credit_card_visual.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/expense_tile.dart';
import '../../widgets/state_views.dart';

/// "Kart ekle": önce kart türü sorulur.
Future<void> showAddCardChooser(BuildContext context) async {
  final route = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.credit_card_rounded),
            title: Text('Kredi kartı'.tr),
            subtitle: Text('Kesim gününe göre ekstre ve son ödeme takibi'.tr),
            onTap: () => Navigator.pop(ctx, '/cards/new'),
          ),
          ListTile(
            leading: const Icon(Icons.account_balance_wallet_rounded),
            title: Text('Banka kartı'.tr),
            subtitle: Text(
              'Banka hesabınızdan ödenen harcamalar; aylık toplam'.tr,
            ),
            onTap: () => Navigator.pop(ctx, '/debit-cards/new'),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    ),
  );
  if (route != null && context.mounted) await context.push(route);
}

// ------------------------------------------------------------------ Ekle / düzenle

class AddEditDebitCardScreen extends ConsumerWidget {
  final String? cardId;
  const AddEditDebitCardScreen({super.key, this.cardId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (cardId == null) return const _DebitCardForm(existing: null);
    final uid = ref.watch(currentUserIdProvider);
    return ref
        .watch(debitCardByIdProvider(cardId!))
        .when(
          loading: () => Scaffold(
            appBar: AppBar(title: Text('Kartı düzenle'.tr)),
            body: const LoadingView(),
          ),
          error: (e, _) => Scaffold(
            appBar: AppBar(),
            body: ErrorStateView(error: e),
          ),
          data: (card) => card == null || !card.isActive || card.ownerUid != uid
              ? Scaffold(
                  appBar: AppBar(),
                  body: EmptyStateView(
                    icon: Icons.credit_card_off_rounded,
                    title: 'Kart düzenlenemez'.tr,
                    message: 'Kart bulunamadı ya da yalnızca kart sahibi düzenleyebilir.'
                        .tr,
                  ),
                )
              : _DebitCardForm(existing: card),
        );
  }
}

class _DebitCardForm extends ConsumerStatefulWidget {
  final DebitCard? existing;
  const _DebitCardForm({required this.existing});

  @override
  ConsumerState<_DebitCardForm> createState() => _DebitCardFormState();
}

class _DebitCardFormState extends ConsumerState<_DebitCardForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _bank = TextEditingController(
    text: widget.existing?.bankName ?? '',
  );
  late final _last4 = TextEditingController(
    text: widget.existing?.last4Digits ?? '',
  );
  late String _colorHex =
      widget.existing?.colorHex ?? AppColors.pickerHexColors[1];
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    for (final c in [_name, _bank, _last4]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _bank.dispose();
    _last4.dispose();
    super.dispose();
  }

  DebitCard _build(String uid) {
    final now = DateTime.now();
    final e = widget.existing;
    return DebitCard(
      id: e?.id ?? const Uuid().v4(),
      ownerUid: e?.ownerUid ?? uid,
      name: _name.text.trim().isEmpty ? 'Banka kartım'.tr : _name.text.trim(),
      bankName: _bank.text.trim().isEmpty ? 'Banka'.tr : _bank.text.trim(),
      last4Digits: _last4.text.trim().padLeft(4, '•'),
      colorHex: _colorHex,
      createdAt: e?.createdAt ?? now,
      updatedAt: now,
    );
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final uid = ref.read(currentUserIdProvider);
    if (uid == null) return;
    final repo = ref.read(debitCardRepositoryProvider);
    setState(() => _saving = true);
    try {
      await repo.saveCard(_build(uid));
      if (!mounted) return;
      context.showSuccess(
        _isEdit ? 'Kart güncellendi.'.tr : 'Banka kartı eklendi.'.tr,
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
    final repo = ref.read(debitCardRepositoryProvider);
    final ok = await showConfirmDialog(
      context,
      title: 'Kart kaldırılsın mı?'.tr,
      message: '"{0}" listeden kaldırılacak. Bu kartla yapılan geçmiş harcamalar silinmez.'
          .trArgs([card.name]),
      confirmLabel: 'Kartı kaldır'.tr,
      destructive: true,
    );
    if (!ok || !mounted) return;
    try {
      await repo.deactivateCard(card.id);
      if (!mounted) return;
      context.showSuccess('Kart kaldırıldı.'.tr);
      context.go('/cards');
    } catch (e) {
      if (mounted) context.showError(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(currentUserIdProvider) ?? '';
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Kartı düzenle'.tr : 'Yeni banka kartı'.tr),
        actions: [
          if (_isEdit)
            IconButton(
              tooltip: 'Kartı kaldır'.tr,
              icon: Icon(
                Icons.delete_outline_rounded,
                color: context.colors.error,
              ),
              onPressed: _deactivate,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: PageListView(
          maxWidth: AppSpacing.maxFormWidth,
          children: [
            ExcludeSemantics(child: DebitCardVisual(card: _build(uid))),
            const SizedBox(height: AppSpacing.md),
            InlineMessage(
              tone: MessageTone.info,
              message: 'Güvenliğiniz için yalnızca kart adı, banka ve son 4 hane saklanır. Kart numarası, son kullanma tarihi ve CVV asla istenmez.'
                  .tr,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              validator: Validators.requiredText(
                'Kart adı'.tr,
                maxLength: AppConstants.maxNameLength,
              ),
              decoration: InputDecoration(
                labelText: 'Kart adı'.tr,
                hintText: 'Örn. Bankkart'.tr,
                prefixIcon: const Icon(Icons.account_balance_wallet_rounded),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _bank,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              validator: Validators.requiredText(
                'Banka adı'.tr,
                maxLength: AppConstants.maxNameLength,
              ),
              decoration: InputDecoration(
                labelText: 'Banka'.tr,
                hintText: 'Örn. Ziraat Bankası'.tr,
                prefixIcon: const Icon(Icons.account_balance_rounded),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _last4,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(4),
              ],
              validator: Validators.last4Digits,
              decoration: InputDecoration(
                labelText: 'Son 4 hane'.tr,
                hintText: '1234',
                prefixIcon: const Icon(Icons.pin_outlined),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text('Kart rengi'.tr, style: context.textStyles.titleSmall),
            const SizedBox(height: AppSpacing.xs),
            ColorPickerRow(
              selectedHex: _colorHex,
              onSelected: (hex) => setState(() => _colorHex = hex),
            ),
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

// ------------------------------------------------------------------ Ayrıntı

/// Banka kartından ay ay yapılan harcamalar.
class DebitCardDetailScreen extends ConsumerStatefulWidget {
  final String cardId;
  const DebitCardDetailScreen({super.key, required this.cardId});

  @override
  ConsumerState<DebitCardDetailScreen> createState() =>
      _DebitCardDetailScreenState();
}

class _DebitCardDetailScreenState extends ConsumerState<DebitCardDetailScreen> {
  String _period = StatementCalculator.periodOf(DateTime.now());

  void _shift(int months) {
    final start = StatementCalculator.periodStart(_period);
    setState(
      () => _period = StatementCalculator.periodOf(
        DateTime(start.year, start.month + months),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cardAsync = ref.watch(debitCardByIdProvider(widget.cardId));
    final uid = ref.watch(currentUserIdProvider);
    final card = cardAsync.valueOrNull;
    final canEdit = card != null && card.isActive && card.ownerUid == uid;

    return Scaffold(
      appBar: AppBar(
        title: Text(card?.name ?? 'Banka kartı'.tr),
        actions: [
          if (canEdit)
            IconButton(
              tooltip: 'Düzenle'.tr,
              icon: const Icon(Icons.edit_outlined),
              onPressed: () =>
                  context.push('/debit-cards/${widget.cardId}/edit'),
            ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: AsyncValueView<DebitCard?>(
        value: cardAsync,
        onRetry: () => ref.invalidate(debitCardByIdProvider(widget.cardId)),
        data: (card) {
          if (card == null || card.ownerUid != uid) {
            return EmptyStateView(
              icon: Icons.credit_card_off_rounded,
              title: 'Kart bulunamadı'.tr,
              message: 'Bu kart kaldırılmış veya erişiminiz yok.'.tr,
            );
          }
          final expensesAsync = ref.watch(
            debitCardExpensesProvider((cardId: card.id, period: _period)),
          );
          final expenses = expensesAsync.valueOrNull ?? const <Expense>[];
          final total = expenses.fold<int>(0, (s, e) => s + e.amountInCents);
          return PageListView(
            children: [
              DebitCardVisual(card: card),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  IconButton(
                    tooltip: 'Önceki ay'.tr,
                    onPressed: () => _shift(-1),
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  Expanded(
                    child: Text(
                      DateFormats.period(_period),
                      textAlign: TextAlign.center,
                      style: context.textStyles.titleMedium,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Sonraki ay'.tr,
                    onPressed: () => _shift(1),
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              AppCard(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bu ayki harcama'.tr,
                            style: context.textStyles.labelMedium?.copyWith(
                              color: context.colors.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            MoneyFormatter.formatCents(total),
                            style: context.textStyles.headlineSmall,
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '{0} işlem'.trArgs([expenses.length]),
                      style: context.textStyles.bodyMedium?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              if (expensesAsync.isLoading && expenses.isEmpty)
                const SizedBox(
                  height: 200,
                  child: SkeletonList(itemCount: 3, padding: EdgeInsets.zero),
                )
              else if (expenses.isEmpty)
                AppCard(
                  child: EmptyStateView(
                    compact: true,
                    icon: Icons.receipt_long_outlined,
                    title: 'Bu ay bu kartla harcama yok'.tr,
                    message: 'Harcama eklerken ödeme yöntemi olarak "Banka Kartı"nı ve bu kartı seçin.'
                        .tr,
                  ),
                )
              else
                AppCard(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
                  child: Column(
                    children: [
                      for (final e in expenses)
                        ExpenseTile(
                          expense: e,
                          showDate: true,
                          onTap: () => context.push('/expenses/${e.id}'),
                        ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
