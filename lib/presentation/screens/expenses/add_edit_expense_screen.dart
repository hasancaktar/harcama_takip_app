import 'package:harcama_takip/core/l10n/app_locale.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../application/providers/auth_providers.dart';
import '../../../application/providers/card_providers.dart';
import '../../../application/providers/expense_providers.dart';
import '../../../application/providers/repository_providers.dart';
import '../../../application/providers/team_providers.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_formats.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/utils/statement_calculator.dart';
import '../../../core/utils/validators.dart';
import '../../../domain/entities/credit_card.dart';
import '../../../domain/entities/expense.dart';
import '../../../domain/entities/installment_plan.dart';
import '../../../domain/entities/recurring_payment.dart';
import '../../widgets/amount_field.dart';
import '../../widgets/common.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/state_views.dart';

/// Harcama ekleme ve düzenleme ekranı.
class AddEditExpenseScreen extends ConsumerWidget {
  final String? expenseId;

  /// Yeni harcamada önceden seçili ödeme yöntemi (ör. `auto_payment`).
  final String? initialPaymentMethod;

  const AddEditExpenseScreen({
    super.key,
    this.expenseId,
    this.initialPaymentMethod,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (expenseId == null) {
      return _ExpenseForm(
        existing: null,
        initialPaymentMethod: initialPaymentMethod,
      );
    }

    final expenseAsync = ref.watch(expenseByIdProvider(expenseId!));
    final uid = ref.watch(currentUserIdProvider);
    return expenseAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: Text('Harcamayı düzenle'.tr)),
        body: const LoadingView(),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: ErrorStateView(error: e),
      ),
      data: (expense) {
        if (expense == null) {
          return Scaffold(
            appBar: AppBar(),
            body: EmptyStateView(
              icon: Icons.search_off_rounded,
              title: 'Harcama bulunamadı'.tr,
              message: 'Bu kayıt silinmiş veya erişiminiz yok.'.tr,
            ),
          );
        }
        if (expense.ownerUid != uid || expense.isInstallment) {
          return Scaffold(
            appBar: AppBar(title: Text('Harcamayı düzenle'.tr)),
            body: EmptyStateView(
              icon: Icons.lock_outline_rounded,
              title: 'Bu harcama düzenlenemez'.tr,
              message: expense.isInstallment
                  ? 'Taksit harcamaları taksit planından otomatik oluşturulur. Değişiklik için taksit planını yönetin.'
                        .tr
                  : 'Yalnızca harcamayı ekleyen kişi düzenleyebilir.'.tr,
            ),
          );
        }
        return _ExpenseForm(existing: expense);
      },
    );
  }
}

class _ExpenseForm extends ConsumerStatefulWidget {
  final Expense? existing;
  final String? initialPaymentMethod;
  const _ExpenseForm({required this.existing, this.initialPaymentMethod});

  @override
  ConsumerState<_ExpenseForm> createState() => _ExpenseFormState();
}

class _ExpenseFormState extends ConsumerState<_ExpenseForm> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();
  final _titleFocus = FocusNode();

  late String _category;
  late String _paymentMethod;
  String? _cardId;
  int _installments = 1;

  /// Otomatik ödemenin kaynağı: kart kimliği ya da [_noCard] (banka hesabı).
  String? _autoSource;
  static const _noCard = '__none__';
  late String _visibility;
  late DateTime _date;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  /// Yeni bir otomatik ödeme mi oluşturuluyor (her ay tekrarlanır)?
  bool get _isNewRecurring => !_isEdit && _paymentMethod == 'auto_payment';

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _amountController.text = MoneyFormatter.formatForInput(e.amountInCents);
      _titleController.text = e.title;
      _notesController.text = e.notes ?? '';
      _category = e.category;
      _paymentMethod = e.paymentMethod;
      _cardId = e.cardId;
      _visibility = e.visibility;
      _date = e.date;
    } else {
      _category = 'market';
      final initial = widget.initialPaymentMethod;
      _paymentMethod =
          initial != null &&
              AppConstants.paymentMethodItems.any((m) => m.id == initial)
          ? initial
          : 'credit_card';
      _visibility = ref.read(activeTeamProvider) != null ? 'team' : 'personal';
      _date = DateTime.now();
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _titleController.dispose();
    _notesController.dispose();
    _titleFocus.dispose();
    super.dispose();
  }

  String? get _teamIdForSave => _visibility == 'team'
      ? (widget.existing?.teamId ?? ref.read(activeTeamProvider)?.id)
      : null;

  CreditCard? _selectedCard(List<CreditCard> cards) =>
      _cardId == null ? null : _selectedCardById(cards, _cardId!);

  static CreditCard? _selectedCardById(List<CreditCard> cards, String id) {
    for (final c in cards) {
      if (c.id == id) return c;
    }
    return null;
  }

  String _resolvePeriod(List<CreditCard> cards) {
    final card = _selectedCard(cards);
    if (_paymentMethod == 'credit_card' && card != null) {
      return StatementCalculator.resolveStatementPeriod(_date, card.cutoffDay);
    }
    final e = widget.existing;
    if (_paymentMethod == 'credit_card' &&
        e != null &&
        e.cardId == _cardId &&
        e.date == _date) {
      return e.statementPeriod; // Kart pasifleştirilmiş olabilir; mevcut dönemi koru.
    }
    return StatementCalculator.periodOf(_date);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 1, 12, 31),
      helpText: 'Harcama tarihi'.tr,
    );
    if (picked == null || !mounted) return;
    setState(
      () => _date = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _date.hour,
        _date.minute,
      ),
    );
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_date),
      helpText: 'Harcama saati'.tr,
    );
    if (picked == null || !mounted) return;
    setState(
      () => _date = DateTime(
        _date.year,
        _date.month,
        _date.day,
        picked.hour,
        picked.minute,
      ),
    );
  }

  Future<void> _save({bool addAnother = false}) async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final cards = ref.read(availableCardsProvider).valueOrNull ?? const [];
    final card = _selectedCard(cards);
    if (_paymentMethod == 'credit_card' && _cardId == null) {
      context.showInfo(
        'Lütfen bir kredi kartı seçin veya farklı bir ödeme yöntemi kullanın.'
            .tr,
      );
      return;
    }
    if (_visibility == 'team' && _teamIdForSave == null) {
      context.showInfo('Takım harcaması için önce bir takım seçin.'.tr);
      return;
    }

    final uid = ref.read(currentUserIdProvider);
    if (uid == null) return;
    setState(() => _saving = true);

    final now = DateTime.now();
    final existing = widget.existing;
    final isCredit = _paymentMethod == 'credit_card';
    final rawTitle = _titleController.text.trim();
    final categoryMeta = AppConstants.categories.firstWhere(
      (c) => c.id == _category,
      orElse: () => AppConstants.categories.first,
    );
    final title = rawTitle.isEmpty ? categoryMeta.name : rawTitle;
    final totalAmount = MoneyFormatter.parseToCents(_amountController.text);

    try {
      if (_isNewRecurring) {
        final autoCard = _autoSource == null || _autoSource == _noCard
            ? null
            : _selectedCardById(cards, _autoSource!);
        final notes = _notesController.text.trim();
        final payment = RecurringPayment(
          id: const Uuid().v4(),
          ownerUid: uid,
          teamId: _teamIdForSave,
          visibility: _visibility,
          title: title,
          amountInCents: totalAmount,
          currency: AppConstants.defaultCurrency,
          category: _category,
          cardId: autoCard?.id,
          cardLast4: autoCard?.last4Digits,
          cardCutoffDay: autoCard?.cutoffDay,
          dayOfMonth: _date.day,
          startDate: _date,
          notes: notes.isEmpty ? null : notes,
          createdAt: now,
          updatedAt: now,
        );
        await ref
            .read(recurringPaymentServiceProvider)
            .create(payment, actorUid: uid, now: now);
        if (!mounted) return;
        context.showSuccess(
          'Otomatik ödeme oluşturuldu. Her ayın {0}. günü otomatik eklenecek.'
              .trArgs([_date.day]),
        );
        if (addAnother) {
          _amountController.clear();
          _titleController.clear();
          _notesController.clear();
          _formKey.currentState!.reset();
          setState(() => _saving = false);
        } else {
          context.pop();
        }
        return;
      }

      if (!_isEdit && isCredit && _installments > 1 && card != null) {
        final planId = const Uuid().v4();
        final schedule = StatementCalculator.generateSchedule(
          startDate: _date,
          cutoffDay: card.cutoffDay,
          totalInstallments: _installments,
          installmentCentsList: MoneyFormatter.divideInstallmentCents(
            totalAmount,
            _installments,
          ),
          paymentDueDaysAfterCutoff: card.paymentDueDaysAfterCutoff,
        );

        final postings = <Expense>[];
        final updatedSchedule = <StatementInstallmentScheduleItem>[];
        for (final item in schedule) {
          final postDate = item.installmentNumber == 1
              ? _date
              : item.statementCutoffDate;
          final exp = Expense(
            id: InstallmentPostingPolicy.expenseIdFor(planId, item),
            teamId: _teamIdForSave,
            ownerUid: uid,
            visibility: _visibility,
            title: '$title - ${item.installmentNumber}. Taksit', // l10n-ignore
            amountInCents: item.amountInCents,
            currency: AppConstants.defaultCurrency,
            category: _category,
            date: postDate,
            paymentMethod: 'credit_card',
            cardId: card.id,
            cardLast4: card.last4Digits,
            isInstallment: true,
            installmentPlanId: planId,
            installmentNumber: item.installmentNumber,
            totalInstallments: _installments,
            statementPeriod: item.statementPeriod,
            notes: _notesController.text.trim().isEmpty
                ? null
                : _notesController.text.trim(),
            tags: const [],
            createdBy: uid,
            createdAt: now,
            updatedAt: now,
          );
          postings.add(exp);
          updatedSchedule.add(item.copyWith(status: 'posted'));
        }

        final plan = InstallmentPlan(
          id: planId,
          ownerUid: uid,
          teamId: _teamIdForSave,
          visibility: _visibility,
          title: title,
          totalAmountInCents: totalAmount,
          totalInstallments: _installments,
          cardId: card.id,
          cardLast4: card.last4Digits,
          category: _category,
          startDate: _date,
          installmentSchedule: updatedSchedule,
          status: 'active',
          createdAt: now,
          updatedAt: now,
        );

        await ref
            .read(installmentRepositoryProvider)
            .savePlanWithPostings(plan, postings);

        if (!mounted) return;
        context.showSuccess(
          '{0} taksitli harcama planı oluşturuldu ve taksitler ilgili aylara eklendi.'
              .trArgs([_installments]),
        );
        if (addAnother) {
          _amountController.clear();
          _titleController.clear();
          _notesController.clear();
          _installments = 1;
          _formKey.currentState!.reset();
          setState(() => _saving = false);
        } else {
          context.pop();
        }
        return;
      }

      final expense = Expense(
        id: existing?.id ?? const Uuid().v4(),
        teamId: _teamIdForSave,
        ownerUid: existing?.ownerUid ?? uid,
        visibility: _visibility,
        title: title,
        amountInCents: totalAmount,
        currency: AppConstants.defaultCurrency,
        category: _category,
        date: _date,
        paymentMethod: _paymentMethod,
        cardId: isCredit ? _cardId : null,
        cardLast4: isCredit ? (card?.last4Digits ?? existing?.cardLast4) : null,
        statementPeriod: _resolvePeriod(cards),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        tags: existing?.tags ?? const [],
        createdBy: existing?.createdBy ?? uid,
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
      );

      final repo = ref.read(expenseRepositoryProvider);
      if (_isEdit) {
        await repo.updateExpense(expense);
      } else {
        await repo.createExpense(expense);
      }
      if (!mounted) return;
      final selected = ref.read(selectedPeriodProvider);
      final note = expense.statementPeriod != selected
          ? ' ({0} dönemine eklendi)'.trArgs([
              DateFormats.period(expense.statementPeriod),
            ])
          : '';
      context.showSuccess(
        _isEdit
            ? 'Harcama güncellendi.'.tr
            : 'Harcama kaydedildi.{0}'.trArgs([note]),
      );
      if (addAnother) {
        _amountController.clear();
        _titleController.clear();
        _notesController.clear();
        _installments = 1;
        _formKey.currentState!.reset();
        setState(() => _saving = false);
      } else {
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        context.showError(e);
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cards = ref.watch(availableCardsProvider).valueOrNull ?? const [];
    final activeTeam = ref.watch(activeTeamProvider);
    final scheme = context.colors;

    if (_paymentMethod == 'credit_card' &&
        _cardId == null &&
        cards.isNotEmpty) {
      _cardId = cards.first.id;
    }
    if (_autoSource == null ||
        (_autoSource != _noCard &&
            _selectedCardById(cards, _autoSource!) == null)) {
      _autoSource = cards.isNotEmpty ? cards.first.id : _noCard;
    }
    final period = _resolvePeriod(cards);
    final teamAvailable = (widget.existing?.teamId ?? activeTeam?.id) != null;
    final teamName = activeTeam?.name ?? 'Takım'.tr;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Harcamayı düzenle'.tr : 'Yeni harcama'.tr),
      ),
      body: Form(
        key: _formKey,
        child: PageListView(
          maxWidth: AppSpacing.maxFormWidth,
          children: [
            AmountField(
              controller: _amountController,
              autofocus: !_isEdit,
              onChanged: (_) {},
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _titleController,
              focusNode: _titleFocus,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
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
                hintText: 'Örn. Haftalık market alışverişi'.tr,
                prefixIcon: const Icon(Icons.edit_note_rounded),
                counterText: '',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _FieldLabel('Kategori'.tr),
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
            _FieldLabel('Ödeme yöntemi'.tr),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final m in AppConstants.paymentMethodItems)
                  ChoiceChip(
                    avatar: Icon(m.icon, size: 18),
                    label: Text(m.name),
                    selected: _paymentMethod == m.id,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _paymentMethod = m.id),
                  ),
              ],
            ),
            if (_isNewRecurring) ...[
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<String>(
                key: ValueKey('auto-source-${cards.length}-$_autoSource'),
                initialValue: _autoSource,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Hangi karttan ödeniyor?'.tr,
                  prefixIcon: const Icon(Icons.autorenew_rounded),
                ),
                items: [
                  for (final c in cards)
                    DropdownMenuItem(
                      value: c.id,
                      child: Text(
                        '${c.name} •••• ${c.last4Digits}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  DropdownMenuItem(
                    value: _noCard,
                    child: Text('Kartsız (banka hesabından)'.tr),
                  ),
                ],
                onChanged: (v) => setState(() => _autoSource = v),
              ),
              const SizedBox(height: AppSpacing.xs),
              InlineMessage(
                tone: MessageTone.info,
                message: 'Bu ödeme her ayın {0}. günü otomatik olarak eklenir. Kartlar > Otomatik ödemeler bölümünden düzenleyebilir veya sonlandırabilirsiniz.'
                    .trArgs([_date.day]),
              ),
            ],
            if (_isEdit && widget.existing!.isRecurring) ...[
              const SizedBox(height: AppSpacing.md),
              InlineMessage(
                tone: MessageTone.info,
                message: 'Bu kayıt bir otomatik ödemeden geldi. Burada yaptığınız değişiklik yalnızca bu ayı etkiler.'
                    .tr,
                action: TextButton(
                  onPressed: () => context.push(
                    '/recurring/${widget.existing!.recurringPaymentId}',
                  ),
                  child: Text('Otomatik ödemeyi aç'.tr),
                ),
              ),
            ],
            if (_paymentMethod == 'credit_card') ...[
              const SizedBox(height: AppSpacing.md),
              if (cards.isEmpty && _cardId == null)
                InlineMessage(
                  tone: MessageTone.warning,
                  message: 'Kayıtlı kredi kartınız yok. Kart ekleyerek ekstre dönemlerini otomatik hesaplatın.'
                      .tr,
                  action: TextButton.icon(
                    onPressed: () => context.push('/cards/new'),
                    icon: const Icon(Icons.add_card_rounded),
                    label: Text('Kart ekle'.tr),
                  ),
                )
              else ...[
                DropdownButtonFormField<String>(
                  key: ValueKey('card-${cards.length}-$_cardId'),
                  initialValue: _cardId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Kredi kartı'.tr,
                    prefixIcon: Icon(Icons.credit_card_rounded),
                  ),
                  items: [
                    for (final c in cards)
                      DropdownMenuItem(
                        value: c.id,
                        child: Text(
                          '${c.name} •••• ${c.last4Digits}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    if (_cardId != null && _selectedCard(cards) == null)
                      DropdownMenuItem(
                        value: _cardId,
                        child: Text(
                          '•••• {0} (kaldırılmış kart)'.trArgs([
                            widget.existing?.cardLast4 ?? '',
                          ]),
                        ),
                      ),
                  ],
                  onChanged: (v) => setState(() => _cardId = v),
                ),
                const SizedBox(height: AppSpacing.xs),
                InlineMessage(
                  tone: MessageTone.info,
                  message: _selectedCard(cards) != null
                      ? 'Kesim günü {0} olduğu için bu harcama {1} ekstresine yazılacak.'
                            .trArgs([
                              _selectedCard(cards)!.cutoffDay,
                              DateFormats.period(period),
                            ])
                      : 'Bu harcama {0} dönemine yazılacak.'.trArgs([
                          DateFormats.period(period),
                        ]),
                ),
                if (!_isEdit) ...[
                  const SizedBox(height: AppSpacing.md),
                  _FieldLabel('Taksit sayısı'.tr),
                  DropdownButtonFormField<int>(
                    key: ValueKey('installments-$_installments'),
                    initialValue: _installments,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Taksit sayısı'.tr,
                      prefixIcon: const Icon(Icons.splitscreen_rounded),
                    ),
                    items: [
                      DropdownMenuItem(value: 1, child: Text('Tek çekim'.tr)),
                      for (final n in [2, 3, 4, 5, 6, 8, 9, 10, 12, 18, 24, 36])
                        DropdownMenuItem(
                          value: n,
                          child: Text('{0} taksit'.trArgs([n])),
                        ),
                    ],
                    onChanged: (v) => setState(() => _installments = v ?? 1),
                  ),
                  if (_installments > 1) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Builder(
                      builder: (context) {
                        final total = MoneyFormatter.parseToCents(
                          _amountController.text,
                        );
                        final perMonth = total > 0
                            ? (total / _installments).round()
                            : 0;
                        return InlineMessage(
                          tone: MessageTone.info,
                          message: total > 0
                              ? 'Aylık yaklaşık {0} olarak {1} ay boyunca ekstrenize yansıtılacak.'
                                    .trArgs([
                                      MoneyFormatter.formatCents(perMonth),
                                      _installments,
                                    ])
                              : 'Toplam tutar {0} aya eşit şekilde paylaştırılacak.'
                                    .trArgs([_installments]),
                        );
                      },
                    ),
                  ],
                ],
              ],
            ],
            const SizedBox(height: AppSpacing.md),
            _FieldLabel('Tarih ve saat'.tr),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today_rounded, size: 18),
                    label: Text(
                      DateFormats.day(_date),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  flex: 2,
                  child: OutlinedButton.icon(
                    onPressed: _pickTime,
                    icon: const Icon(Icons.schedule_rounded, size: 18),
                    label: Text(DateFormats.time(_date)),
                  ),
                ),
              ],
            ),
            if (teamAvailable) ...[
              const SizedBox(height: AppSpacing.md),
              _FieldLabel('Kime ait?'.tr),
              SegmentedButton<String>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: 'personal',
                    icon: Icon(Icons.person_rounded),
                    label: Text('Bireysel'.tr),
                  ),
                  ButtonSegment(
                    value: 'team',
                    icon: const Icon(Icons.groups_rounded),
                    label: Text(teamName, overflow: TextOverflow.ellipsis),
                  ),
                ],
                selected: {_visibility},
                onSelectionChanged: (v) =>
                    setState(() => _visibility = v.first),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                _visibility == 'team'
                    ? 'Takım üyeleri bu harcamayı görebilir.'.tr
                    : 'Bu harcamayı yalnızca siz görebilirsiniz.'.tr,
                style: context.textStyles.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _notesController,
              maxLines: 3,
              minLines: 1,
              maxLength: AppConstants.maxNotesLength,
              textCapitalization: TextCapitalization.sentences,
              validator: Validators.optionalText(
                'Not'.tr,
                maxLength: AppConstants.maxNotesLength,
              ),
              decoration: InputDecoration(
                labelText: 'Not (isteğe bağlı)'.tr,
                prefixIcon: Icon(Icons.notes_rounded),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: _isEdit
                  ? 'Değişiklikleri kaydet'.tr
                  : _isNewRecurring
                  ? 'Otomatik ödemeyi kaydet'.tr
                  : 'Harcamayı kaydet'.tr,
              icon: Icons.check_rounded,
              onPressed: () => _save(),
              isLoading: _saving,
            ),
            if (!_isEdit) ...[
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: 'Kaydet ve yenisini ekle'.tr,
                outlined: true,
                onPressed: _saving ? null : () => _save(addAnother: true),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Text(text, style: context.textStyles.titleSmall),
    );
  }
}
