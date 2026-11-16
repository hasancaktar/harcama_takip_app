import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../application/providers/auth_providers.dart';
import '../../../application/providers/card_providers.dart';
import '../../../application/providers/repository_providers.dart';
import '../../../application/providers/team_providers.dart';
import '../../../application/services/installment_posting_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_formats.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/utils/statement_calculator.dart';
import '../../../core/utils/validators.dart';
import '../../../domain/entities/credit_card.dart';
import '../../../domain/entities/installment_plan.dart';
import '../../widgets/amount_field.dart';
import '../../widgets/app_card.dart';
import '../../widgets/common.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/state_views.dart';

class AddInstallmentPlanScreen extends ConsumerStatefulWidget {
  const AddInstallmentPlanScreen({super.key});

  @override
  ConsumerState<AddInstallmentPlanScreen> createState() =>
      _AddInstallmentPlanScreenState();
}

class _AddInstallmentPlanScreenState
    extends ConsumerState<AddInstallmentPlanScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _titleController = TextEditingController();

  int _count = 6;
  String? _cardId;
  String _category = 'shopping';
  late String _visibility = ref.read(activeTeamProvider) != null
      ? 'team'
      : 'personal';
  DateTime _startDate = DateTime.now();
  bool _saving = false;

  static const _countOptions = [2, 3, 4, 5, 6, 8, 9, 10, 12, 15, 18, 24, 36];

  @override
  void dispose() {
    _amountController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  CreditCard? _card(List<CreditCard> cards) {
    for (final c in cards) {
      if (c.id == _cardId) return c;
    }
    return null;
  }

  InstallmentPlan? _buildPlan(List<CreditCard> cards, {String? id}) {
    final card = _card(cards);
    final total = MoneyFormatter.parseToCents(_amountController.text);
    final uid = ref.read(currentUserIdProvider);
    if (card == null || total <= 0 || uid == null) return null;
    final team = ref.read(activeTeamProvider);
    final schedule = StatementCalculator.generateSchedule(
      startDate: _startDate,
      cutoffDay: card.cutoffDay,
      totalInstallments: _count,
      installmentCentsList: MoneyFormatter.divideInstallmentCents(
        total,
        _count,
      ),
      paymentDueDaysAfterCutoff: card.paymentDueDaysAfterCutoff,
    );
    final now = DateTime.now();
    final isTeam = _visibility == 'team' && team != null;
    return InstallmentPlan(
      id: id ?? 'preview',
      ownerUid: uid,
      teamId: isTeam ? team.id : null,
      visibility: isTeam ? 'team' : 'personal',
      title: _titleController.text.trim(),
      totalAmountInCents: total,
      totalInstallments: _count,
      cardId: card.id,
      cardLast4: card.last4Digits,
      category: _category,
      startDate: _startDate,
      installmentSchedule: schedule,
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(now.year - 3),
      lastDate: now.add(const Duration(days: 365)),
      helpText: 'Alışveriş tarihi',
    );
    if (picked != null && mounted) {
      setState(
        () => _startDate = DateTime(picked.year, picked.month, picked.day, 12),
      );
    }
  }

  Future<void> _save(List<CreditCard> cards) async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final uid = ref.read(currentUserIdProvider);
    final plan = _buildPlan(cards, id: const Uuid().v4());
    if (plan == null || uid == null) {
      context.showInfo('Lütfen bir kredi kartı seçin.');
      return;
    }
    setState(() => _saving = true);
    try {
      final result = InstallmentPostingService.applyDuePostings(
        plan,
        now: DateTime.now(),
        actorUid: uid,
      );
      await ref
          .read(installmentRepositoryProvider)
          .savePlanWithPostings(result.plan, result.postings);
      if (!mounted) return;
      context.showSuccess(
        result.postings.isEmpty
            ? 'Taksit planı oluşturuldu.'
            : 'Taksit planı oluşturuldu; ${result.postings.length} taksit harcamalara eklendi.',
      );
      context.pop();
    } catch (e) {
      if (mounted) {
        context.showError(e);
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cardsAsync = ref.watch(availableCardsProvider);
    final cards = cardsAsync.valueOrNull ?? const [];
    final team = ref.watch(activeTeamProvider);
    final scheme = context.colors;

    if (_cardId == null && cards.isNotEmpty) _cardId = cards.first.id;
    final preview = _buildPlan(cards);
    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(title: const Text('Yeni taksit planı')),
      body: cardsAsync.isLoading && cards.isEmpty
          ? const LoadingView()
          : cards.isEmpty
          ? EmptyStateView(
              icon: Icons.credit_card_off_rounded,
              title: 'Önce bir kart ekleyin',
              message:
                  'Taksitler kartın kesim gününe göre ekstrelere dağıtılır.',
              actionLabel: 'Kart ekle',
              actionIcon: Icons.add_card_rounded,
              onAction: () => context.push('/cards/new'),
            )
          : Form(
              key: _formKey,
              child: PageListView(
                maxWidth: AppSpacing.maxFormWidth,
                children: [
                  AmountField(
                    controller: _amountController,
                    label: 'Toplam alışveriş tutarı',
                    autofocus: true,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _titleController,
                    textCapitalization: TextCapitalization.sentences,
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(
                        AppConstants.maxTitleLength,
                      ),
                    ],
                    validator: Validators.requiredText(
                      'Ürün / açıklama',
                      maxLength: AppConstants.maxTitleLength,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Ürün / açıklama',
                      hintText: 'Örn. Buzdolabı',
                      prefixIcon: Icon(Icons.shopping_bag_outlined),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  DropdownButtonFormField<String>(
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
                            '${c.name} •••• ${c.last4Digits} (kesim ${c.cutoffDay})',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (v) => setState(() => _cardId = v),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: _count,
                          decoration: const InputDecoration(
                            labelText: 'Taksit sayısı',
                          ),
                          items: [
                            for (final c in _countOptions)
                              DropdownMenuItem(
                                value: c,
                                child: Text('$c taksit'),
                              ),
                          ],
                          onChanged: (v) =>
                              setState(() => _count = v ?? _count),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickDate,
                          icon: const Icon(
                            Icons.calendar_today_rounded,
                            size: 18,
                          ),
                          label: Text(DateFormats.dayShort(_startDate)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  DropdownButtonFormField<String>(
                    initialValue: _category,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Kategori',
                      prefixIcon: Icon(Icons.category_outlined),
                    ),
                    items: [
                      for (final c in AppConstants.defaultCategories)
                        DropdownMenuItem(
                          value: c.id,
                          child: Row(
                            children: [
                              Icon(c.icon, size: 18, color: c.color),
                              const SizedBox(width: AppSpacing.xs),
                              Text(c.name),
                            ],
                          ),
                        ),
                    ],
                    onChanged: (v) =>
                        setState(() => _category = v ?? _category),
                  ),
                  if (team != null) ...[
                    const SizedBox(height: AppSpacing.md),
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
                          label: Text(
                            team.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      selected: {_visibility},
                      onSelectionChanged: (v) =>
                          setState(() => _visibility = v.first),
                    ),
                  ],
                  if (preview != null) ...[
                    const SectionHeader(title: 'Ödeme planı önizlemesi'),
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final item in preview.installmentSchedule.take(
                            4,
                          ))
                            _ScheduleRow(
                              label: '${item.installmentNumber}. taksit',
                              period: DateFormats.period(item.statementPeriod),
                              amount: MoneyFormatter.formatCents(
                                item.amountInCents,
                              ),
                              willPost: InstallmentPostingPolicy.isDue(
                                item,
                                now,
                              ),
                            ),
                          if (preview.installmentSchedule.length > 4) ...[
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Text(
                                '…',
                                textAlign: TextAlign.center,
                                style: context.textStyles.bodyMedium,
                              ),
                            ),
                            _ScheduleRow(
                              label:
                                  '${preview.installmentSchedule.last.installmentNumber}. taksit',
                              period: DateFormats.period(
                                preview
                                    .installmentSchedule
                                    .last
                                    .statementPeriod,
                              ),
                              amount: MoneyFormatter.formatCents(
                                preview.installmentSchedule.last.amountInCents,
                              ),
                              willPost: false,
                            ),
                          ],
                          const Divider(height: AppSpacing.lg),
                          Text(
                            'Her taksit, ait olduğu ekstre ayı geldiğinde harcamalarınıza otomatik eklenir. '
                            'Kuruş farkı ilk taksite yansıtılır.',
                            style: context.textStyles.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  AppButton(
                    label: 'Taksit planını oluştur',
                    icon: Icons.check_rounded,
                    onPressed: () => _save(cards),
                    isLoading: _saving,
                  ),
                ],
              ),
            ),
    );
  }
}

class _ScheduleRow extends StatelessWidget {
  final String label;
  final String period;
  final String amount;
  final bool willPost;

  const _ScheduleRow({
    required this.label,
    required this.period,
    required this.amount,
    required this.willPost,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: context.textStyles.titleSmall),
                Text(
                  willPost ? '$period · hemen eklenecek' : period,
                  style: context.textStyles.bodySmall?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(amount, style: context.textStyles.titleSmall),
        ],
      ),
    );
  }
}
