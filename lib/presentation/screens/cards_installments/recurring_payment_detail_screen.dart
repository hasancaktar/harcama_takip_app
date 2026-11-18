import 'package:harcama_takip/core/l10n/app_locale.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers/auth_providers.dart';
import '../../../application/providers/card_providers.dart';
import '../../../application/providers/recurring_payment_providers.dart';
import '../../../application/providers/repository_providers.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_formats.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/utils/validators.dart';
import '../../../domain/entities/credit_card.dart';
import '../../../domain/entities/recurring_payment.dart';
import '../../widgets/amount_field.dart';
import '../../widgets/app_card.dart';
import '../../widgets/common.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/state_views.dart';

/// Otomatik ödemenin ayrıntısı: düzenleme ve sonlandırma.
class RecurringPaymentDetailScreen extends ConsumerWidget {
  final String paymentId;

  const RecurringPaymentDetailScreen({super.key, required this.paymentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(recurringPaymentByIdProvider(paymentId));
    return Scaffold(
      appBar: AppBar(title: Text('Otomatik ödeme'.tr)),
      body: AsyncValueView<RecurringPayment?>(
        value: async,
        onRetry: () => ref.invalidate(recurringPaymentByIdProvider(paymentId)),
        data: (payment) => payment == null
            ? EmptyStateView(
                icon: Icons.search_off_rounded,
                title: 'Otomatik ödeme bulunamadı'.tr,
                message: 'Bu kayıt silinmiş veya erişiminiz yok.'.tr,
              )
            // Kayıt sonrası (ör. sonlandırma) form yeni değerlerle kurulur.
            : _RecurringBody(
                key: ValueKey('${payment.id}-${payment.status}'),
                payment: payment,
              ),
      ),
    );
  }
}

class _RecurringBody extends ConsumerStatefulWidget {
  final RecurringPayment payment;
  const _RecurringBody({super.key, required this.payment});

  @override
  ConsumerState<_RecurringBody> createState() => _RecurringBodyState();
}

class _RecurringBodyState extends ConsumerState<_RecurringBody> {
  static const _noCard = '__none__';

  final _formKey = GlobalKey<FormState>();
  late final _amountController = TextEditingController(
    text: MoneyFormatter.formatForInput(widget.payment.amountInCents),
  );
  late final _titleController = TextEditingController(
    text: widget.payment.title,
  );
  late String _category = widget.payment.category;
  late String _source = widget.payment.cardId ?? _noCard;
  late int _day = widget.payment.dayOfMonth;
  bool _saving = false;

  @override
  void dispose() {
    _amountController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  static CreditCard? _cardById(List<CreditCard> cards, String id) {
    for (final c in cards) {
      if (c.id == id) return c;
    }
    return null;
  }

  Future<void> _save(List<CreditCard> cards) async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final uid = ref.read(currentUserIdProvider);
    if (uid == null) return;
    final service = ref.read(recurringPaymentServiceProvider);
    final previous = widget.payment;
    final title = _titleController.text.trim();

    RecurringPayment updated = previous.copyWith(
      title: title.isEmpty
          ? AppConstants.getCategoryById(_category).name
          : title,
      amountInCents: MoneyFormatter.parseToCents(_amountController.text),
      category: _category,
      dayOfMonth: _day,
    );
    if (_source == _noCard) {
      updated = updated.copyWith(clearCard: true);
    } else if (_source != previous.cardId) {
      final card = _cardById(cards, _source);
      if (card != null) {
        updated = updated.copyWith(
          cardId: card.id,
          cardLast4: card.last4Digits,
          cardCutoffDay: card.cutoffDay,
        );
      }
    }

    setState(() => _saving = true);
    try {
      await service.update(previous, updated, actorUid: uid);
      if (mounted) context.showSuccess('Otomatik ödeme güncellendi.'.tr);
    } catch (e) {
      if (mounted) context.showError(e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _cancel() async {
    final ok = await showConfirmDialog(
      context,
      title: 'Otomatik ödeme sonlandırılsın mı?'.tr,
      message: 'Geçmiş aylardaki kayıtlar kalır. Tarihi henüz gelmemiş kayıtlar silinir ve yeni ay eklenmez.'
          .tr,
      confirmLabel: 'Sonlandır'.tr,
      destructive: true,
    );
    if (!ok || !mounted) return;
    final uid = ref.read(currentUserIdProvider);
    if (uid == null) return;
    final service = ref.read(recurringPaymentServiceProvider);
    try {
      await service.cancel(widget.payment, actorUid: uid);
      if (mounted) context.showSuccess('Otomatik ödeme sonlandırıldı.'.tr);
    } catch (e) {
      if (mounted) context.showError(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final payment = widget.payment;
    final uid = ref.watch(currentUserIdProvider);
    final cards = ref.watch(availableCardsProvider).valueOrNull ?? const [];
    final scheme = context.colors;
    final canEdit = payment.isActive && payment.ownerUid == uid;
    final next = payment.nextOccurrenceAfter(DateTime.now());

    // Ödemenin kartı artık listede yoksa (kaldırılmış) seçenek olarak korunur.
    final sourceItems = <DropdownMenuItem<String>>[
      for (final c in cards)
        DropdownMenuItem(
          value: c.id,
          child: Text(
            '${c.name} •••• ${c.last4Digits}',
            overflow: TextOverflow.ellipsis,
          ),
        ),
      if (payment.cardId != null && _cardById(cards, payment.cardId!) == null)
        DropdownMenuItem(
          value: payment.cardId,
          child: Text(
            '•••• {0} (kaldırılmış kart)'.trArgs([payment.cardLast4 ?? '']),
          ),
        ),
      DropdownMenuItem(
        value: _noCard,
        child: Text('Kartsız (banka hesabından)'.tr),
      ),
    ];

    return Form(
      key: _formKey,
      child: PageListView(
        maxWidth: AppSpacing.maxFormWidth,
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CategoryIcon(categoryId: payment.category, size: 40),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            payment.title,
                            style: context.textStyles.titleMedium,
                          ),
                          Text(
                            recurringScheduleLabel(payment),
                            style: context.textStyles.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      MoneyFormatter.formatCents(payment.amountInCents),
                      style: context.textStyles.titleMedium,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    Pill(
                      label: payment.isActive ? 'Aktif'.tr : 'Sonlandırıldı'.tr,
                      color: payment.isActive
                          ? scheme.primary
                          : scheme.onSurfaceVariant,
                    ),
                    if (next != null)
                      Pill(
                        icon: Icons.event_rounded,
                        label: 'Sıradaki: {0}'.trArgs([DateFormats.day(next)]),
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (!payment.isActive) ...[
            const SizedBox(height: AppSpacing.md),
            InlineMessage(
              tone: MessageTone.info,
              message: '{0} tarihinde sonlandırıldı. Geçmiş aylardaki kayıtlar harcamalarınızda duruyor.'
                  .trArgs([
                    DateFormats.day(payment.endDate ?? payment.updatedAt),
                  ]),
            ),
          ] else if (!canEdit) ...[
            const SizedBox(height: AppSpacing.md),
            InlineMessage(
              tone: MessageTone.info,
              message:
                  'Bu otomatik ödemeyi yalnızca ekleyen kişi değiştirebilir.'
                      .tr,
            ),
          ],
          if (canEdit) ...[
            SectionHeader(title: 'Düzenle'.tr),
            AmountField(controller: _amountController),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _titleController,
              textCapitalization: TextCapitalization.sentences,
              maxLength: AppConstants.maxTitleLength,
              inputFormatters: [
                LengthLimitingTextInputFormatter(AppConstants.maxTitleLength),
              ],
              validator: Validators.optionalText(
                'Açıklama'.tr,
                maxLength: AppConstants.maxTitleLength,
              ),
              decoration: InputDecoration(
                labelText: 'Açıklama (isteğe bağlı)'.tr,
                prefixIcon: const Icon(Icons.edit_note_rounded),
                counterText: '',
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final c in AppConstants.categories)
                  ChoiceChip(
                    avatar: Icon(
                      c.icon,
                      size: 18,
                      color: _category == c.id
                          ? scheme.onPrimaryContainer
                          : c.color,
                    ),
                    label: Text(c.name),
                    selected: _category == c.id,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _category = c.id),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<String>(
              initialValue: _source,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Hangi karttan ödeniyor?'.tr,
                prefixIcon: const Icon(Icons.autorenew_rounded),
              ),
              items: sourceItems,
              onChanged: (v) => setState(() => _source = v ?? _noCard),
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<int>(
              initialValue: _day,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Ayın günü'.tr,
                prefixIcon: const Icon(Icons.calendar_month_rounded),
                helperText: 'Kısa aylarda ayın son günü kullanılır.'.tr,
              ),
              items: [
                for (var d = 1; d <= 31; d++)
                  DropdownMenuItem(value: d, child: Text('$d')),
              ],
              onChanged: (v) => setState(() => _day = v ?? _day),
            ),
            const SizedBox(height: AppSpacing.md),
            InlineMessage(
              tone: MessageTone.info,
              message: 'Değişiklikler bu ayın henüz gerçekleşmemiş kaydına ve sonraki aylara uygulanır; geçmiş kayıtlar değişmez.'
                  .tr,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: 'Değişiklikleri kaydet'.tr,
              icon: Icons.check_rounded,
              onPressed: () => _save(cards),
              isLoading: _saving,
            ),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'Otomatik ödemeyi sonlandır'.tr,
              icon: Icons.stop_circle_outlined,
              outlined: true,
              destructive: true,
              onPressed: _saving ? null : _cancel,
            ),
          ],
        ],
      ),
    );
  }
}

/// "Her ayın 15. günü · •••• 4821" / "Kartsız".
String recurringScheduleLabel(RecurringPayment p) =>
    'Her ayın {0}. günü · {1}'.trArgs([
      p.dayOfMonth,
      p.cardLast4 != null ? '•••• ${p.cardLast4}' : 'Kartsız'.tr,
    ]);
