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
import '../../widgets/amount_field.dart';
import '../../widgets/common.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/state_views.dart';

/// Harcama ekleme ve düzenleme ekranı.
class AddEditExpenseScreen extends ConsumerWidget {
  final String? expenseId;

  const AddEditExpenseScreen({super.key, this.expenseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (expenseId == null) return const _ExpenseForm(existing: null);

    final expenseAsync = ref.watch(expenseByIdProvider(expenseId!));
    final uid = ref.watch(currentUserIdProvider);
    return expenseAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Harcamayı düzenle')),
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
            body: const EmptyStateView(
              icon: Icons.search_off_rounded,
              title: 'Harcama bulunamadı',
              message: 'Bu kayıt silinmiş veya erişiminiz yok.',
            ),
          );
        }
        if (expense.ownerUid != uid || expense.isInstallment) {
          return Scaffold(
            appBar: AppBar(title: const Text('Harcamayı düzenle')),
            body: EmptyStateView(
              icon: Icons.lock_outline_rounded,
              title: 'Bu harcama düzenlenemez',
              message: expense.isInstallment
                  ? 'Taksit harcamaları taksit planından otomatik oluşturulur. Değişiklik için taksit planını yönetin.'
                  : 'Yalnızca harcamayı ekleyen kişi düzenleyebilir.',
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
  const _ExpenseForm({required this.existing});

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
  late String _visibility;
  late DateTime _date;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

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
      _paymentMethod = 'credit_card';
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

  CreditCard? _selectedCard(List<CreditCard> cards) {
    for (final c in cards) {
      if (c.id == _cardId) return c;
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
      helpText: 'Harcama tarihi',
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
      helpText: 'Harcama saati',
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
        'Lütfen bir kredi kartı seçin veya farklı bir ödeme yöntemi kullanın.',
      );
      return;
    }
    if (_visibility == 'team' && _teamIdForSave == null) {
      context.showInfo('Takım harcaması için önce bir takım seçin.');
      return;
    }

    final uid = ref.read(currentUserIdProvider);
    if (uid == null) return;
    setState(() => _saving = true);

    final now = DateTime.now();
    final existing = widget.existing;
    final isCredit = _paymentMethod == 'credit_card';
    final expense = Expense(
      id: existing?.id ?? const Uuid().v4(),
      teamId: _teamIdForSave,
      ownerUid: existing?.ownerUid ?? uid,
      visibility: _visibility,
      title: _titleController.text.trim(),
      amountInCents: MoneyFormatter.parseToCents(_amountController.text),
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

    try {
      final repo = ref.read(expenseRepositoryProvider);
      if (_isEdit) {
        await repo.updateExpense(expense);
      } else {
        await repo.createExpense(expense);
      }
      if (!mounted) return;
      final selected = ref.read(selectedPeriodProvider);
      final note = expense.statementPeriod != selected
          ? ' (${DateFormats.period(expense.statementPeriod)} dönemine eklendi)'
          : '';
      context.showSuccess(
        _isEdit ? 'Harcama güncellendi.' : 'Harcama kaydedildi.$note',
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
    final period = _resolvePeriod(cards);
    final teamAvailable = (widget.existing?.teamId ?? activeTeam?.id) != null;
    final teamName = activeTeam?.name ?? 'Takım';

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Harcamayı düzenle' : 'Yeni harcama'),
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
              validator: Validators.requiredText(
                'Açıklama',
                maxLength: AppConstants.maxTitleLength,
              ),
              decoration: const InputDecoration(
                labelText: 'Açıklama',
                hintText: 'Örn. Haftalık market alışverişi',
                prefixIcon: Icon(Icons.edit_note_rounded),
                counterText: '',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _FieldLabel('Kategori'),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final c in AppConstants.defaultCategories)
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
            _FieldLabel('Ödeme yöntemi'),
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
            if (_paymentMethod == 'credit_card') ...[
              const SizedBox(height: AppSpacing.md),
              if (cards.isEmpty && _cardId == null)
                InlineMessage(
                  tone: MessageTone.warning,
                  message: 'Kayıtlı kredi kartınız yok. Kart ekleyerek ekstre dönemlerini otomatik hesaplatın.',
                  action: TextButton.icon(
                    onPressed: () => context.push('/cards/new'),
                    icon: const Icon(Icons.add_card_rounded),
                    label: const Text('Kart ekle'),
                  ),
                )
              else ...[
                DropdownButtonFormField<String>(
                  key: ValueKey('card-${cards.length}-$_cardId'),
                  initialValue: _cardId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Kredi kartı',
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
                          '•••• ${widget.existing?.cardLast4 ?? ''} (kaldırılmış kart)',
                        ),
                      ),
                  ],
                  onChanged: (v) => setState(() => _cardId = v),
                ),
                const SizedBox(height: AppSpacing.xs),
                InlineMessage(
                  tone: MessageTone.info,
                  message: _selectedCard(cards) != null
                      ? 'Kesim günü ${_selectedCard(cards)!.cutoffDay} olduğu için bu harcama ${DateFormats.period(period)} ekstresine yazılacak.'
                      : 'Bu harcama ${DateFormats.period(period)} dönemine yazılacak.',
                ),
              ],
            ],
            const SizedBox(height: AppSpacing.md),
            _FieldLabel('Tarih ve saat'),
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
              _FieldLabel('Kime ait?'),
              SegmentedButton<String>(
                showSelectedIcon: false,
                segments: [
                  const ButtonSegment(
                    value: 'personal',
                    icon: Icon(Icons.person_rounded),
                    label: Text('Bireysel'),
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
                    ? 'Takım üyeleri bu harcamayı görebilir.'
                    : 'Bu harcamayı yalnızca siz görebilirsiniz.',
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
                'Not',
                maxLength: AppConstants.maxNotesLength,
              ),
              decoration: const InputDecoration(
                labelText: 'Not (isteğe bağlı)',
                prefixIcon: Icon(Icons.notes_rounded),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: _isEdit ? 'Değişiklikleri kaydet' : 'Harcamayı kaydet',
              icon: Icons.check_rounded,
              onPressed: () => _save(),
              isLoading: _saving,
            ),
            if (!_isEdit) ...[
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: 'Kaydet ve yenisini ekle',
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
