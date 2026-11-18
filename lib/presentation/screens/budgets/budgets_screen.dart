import 'package:harcama_takip/core/l10n/app_locale.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers/auth_providers.dart';
import '../../../application/providers/budget_providers.dart';
import '../../../application/providers/expense_providers.dart';
import '../../../application/providers/repository_providers.dart';
import '../../../application/providers/team_providers.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_formats.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/utils/thousands_separator_input_formatter.dart';
import '../../../core/utils/validators.dart';
import '../../../domain/entities/budget.dart';
import '../../widgets/app_card.dart';
import '../../widgets/common.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/state_views.dart';
import '../../widgets/workspace_selector.dart';

class BudgetsScreen extends ConsumerWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgetAsync = ref.watch(currentBudgetProvider);
    final period = ref.watch(selectedPeriodProvider);
    final teamId = ref.watch(activeTeamProvider)?.id;

    return Scaffold(
      appBar: AppBar(title: Text('Bütçe'.tr)),
      body: PageListView(
        children: [
          const ContextBar(),
          const SizedBox(height: AppSpacing.md),
          budgetAsync.when(
            skipLoadingOnReload: false,
            loading: () => const SizedBox(
              height: 300,
              child: SkeletonList(itemCount: 3, padding: EdgeInsets.zero),
            ),
            error: (e, _) => ErrorStateView(
              error: e,
              onRetry: () => ref.invalidate(currentBudgetProvider),
            ),
            data: (budget) => _BudgetEditor(
              key: ValueKey('$teamId-$period'),
              budget: budget,
              period: period,
            ),
          ),
        ],
      ),
    );
  }
}

class _BudgetEditor extends ConsumerStatefulWidget {
  final Budget? budget;
  final String period;

  const _BudgetEditor({super.key, required this.budget, required this.period});

  @override
  ConsumerState<_BudgetEditor> createState() => _BudgetEditorState();
}

class _BudgetEditorState extends ConsumerState<_BudgetEditor> {
  final _formKey = GlobalKey<FormState>();
  late final _totalController = TextEditingController(
    text: MoneyFormatter.formatForInput(widget.budget?.totalBudgetInCents ?? 0),
  );
  late final Map<String, TextEditingController> _categoryControllers = {
    for (final c in AppConstants.categories)
      c.id: TextEditingController(
        text: MoneyFormatter.formatForInput(
          widget.budget?.categoryBudgetsInCents[c.id] ?? 0,
        ),
      ),
  };
  bool _saving = false;
  bool _showCategories = false;

  @override
  void initState() {
    super.initState();
    _showCategories = widget.budget?.categoryBudgetsInCents.isNotEmpty ?? false;
  }

  @override
  void dispose() {
    _totalController.dispose();
    for (final c in _categoryControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final uid = ref.read(currentUserIdProvider);
    if (uid == null) return;
    final team = ref.read(activeTeamProvider);
    final total = MoneyFormatter.parseToCents(_totalController.text);
    final categories = <String, int>{};
    _categoryControllers.forEach((id, controller) {
      final cents = MoneyFormatter.parseToCents(controller.text);
      if (cents > 0) categories[id] = cents;
    });

    setState(() => _saving = true);
    final now = DateTime.now();
    try {
      final budget = Budget(
        id: Budget.idFor(
          ownerUid: uid,
          teamId: team?.id,
          period: widget.period,
        ),
        ownerUid: uid,
        teamId: team?.id,
        visibility: team != null ? 'team' : 'personal',
        period: widget.period,
        totalBudgetInCents: total,
        categoryBudgetsInCents: categories,
        // Devredilen bütçe kaydedilince bu ay için yeni bir kayıt oluşur.
        createdAt: _ownBudget?.createdAt ?? now,
        updatedAt: now,
      );
      await ref.read(budgetRepositoryProvider).saveBudget(budget);
      if (mounted) {
        context.showSuccess(
          '{0} bütçesi kaydedildi.'.trArgs([DateFormats.period(widget.period)]),
        );
      }
    } catch (e) {
      if (mounted) context.showError(e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Bu aya ait bütçe (devredilen bütçe değil).
  Budget? get _ownBudget {
    final b = widget.budget;
    return b == null || b.isCarriedOverTo(widget.period) ? null : b;
  }

  Future<void> _delete() async {
    final budget = _ownBudget;
    if (budget == null) return;
    final ok = await showConfirmDialog(
      context,
      title: 'Bütçe kaldırılsın mı?'.tr,
      message:
          '{0} için belirlenen bütçe kaldırılacak. Harcamalarınız etkilenmez.'
              .trArgs([DateFormats.period(widget.period)]),
      confirmLabel: 'Kaldır'.tr,
      destructive: true,
    );
    if (!ok || !mounted) return;
    try {
      await ref.read(budgetRepositoryProvider).deleteBudget(budget.id);
      if (mounted) context.showSuccess('Bütçe kaldırıldı.'.tr);
    } catch (e) {
      if (mounted) context.showError(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stats = ref.watch(workspaceStatsProvider);
    final status = ref.watch(budgetStatusProvider);
    final scheme = context.colors;
    final semantic = context.semantic;
    final budget = widget.budget;
    final carriedFrom = budget != null && budget.isCarriedOverTo(widget.period)
        ? budget.period
        : null;
    final team = ref.watch(activeTeamProvider);
    final uid = ref.watch(currentUserIdProvider);
    // Takım bütçesini yalnızca takımı kuran kişi belirler (Firestore kuralı da aynı).
    final canEdit = team == null || team.ownerUid == uid;

    final (String headline, Color tone) = switch (status?.level) {
      null => ('Bu ay için bütçe belirlenmedi'.tr, scheme.onSurfaceVariant),
      BudgetLevel.safe => ('Bütçe kontrol altında'.tr, semantic.success),
      BudgetLevel.warning => ('Bütçenin %75\'i aşıldı'.tr, semantic.warning),
      BudgetLevel.critical => ('Bütçe dolmak üzere'.tr, semantic.warning),
      BudgetLevel.exceeded => ('Bütçe aşıldı'.tr, scheme.error),
    };

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  headline,
                  style: context.textStyles.titleMedium?.copyWith(color: tone),
                ),
                const SizedBox(height: AppSpacing.sm),
                if (status != null) ...[
                  UsageBar(
                    ratio: status.ratio,
                    height: 12,
                    semanticsLabel: 'Bütçe kullanımı'.tr,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                Row(
                  children: [
                    Expanded(
                      child: _Figure(
                        label: 'Harcanan'.tr,
                        value: MoneyFormatter.formatCents(stats.totalCents),
                      ),
                    ),
                    Expanded(
                      child: _Figure(
                        label: 'Bütçe'.tr,
                        value: status != null
                            ? MoneyFormatter.formatCents(status.limitCents)
                            : '—',
                      ),
                    ),
                    Expanded(
                      child: _Figure(
                        label: (status?.remainingCents ?? 0) < 0
                            ? 'Aşım'.tr
                            : 'Kalan'.tr,
                        value: status != null
                            ? MoneyFormatter.formatCents(
                                status.remainingCents.abs(),
                              )
                            : '—',
                        color: (status?.remainingCents ?? 0) < 0
                            ? scheme.error
                            : null,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (carriedFrom != null) ...[
            const SizedBox(height: AppSpacing.md),
            InlineMessage(
              tone: MessageTone.info,
              message: '{0} bütçesi bu aya devredildi. Değiştirip kaydederseniz yalnızca {1} ve sonrası için geçerli olur.'
                  .trArgs([
                    DateFormats.period(carriedFrom),
                    DateFormats.period(widget.period),
                  ]),
            ),
          ],
          if (!canEdit) ...[
            const SizedBox(height: AppSpacing.md),
            InlineMessage(
              tone: MessageTone.info,
              message:
                  'Takım bütçesini yalnızca takımı kuran kişi belirleyebilir.'
                      .tr,
            ),
          ],
          SectionHeader(title: 'Aylık toplam bütçe'.tr),
          TextFormField(
            enabled: canEdit,
            controller: _totalController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: const [ThousandsSeparatorInputFormatter()],
            validator: Validators.amount,
            decoration: InputDecoration(
              labelText: 'Toplam bütçe'.tr,
              prefixText: '₺ ',
              prefixIcon: Icon(Icons.account_balance_wallet_outlined),
              helperText: 'Seçili ay ve sonraki aylar için geçerlidir; sonraki bir ayda değiştirebilirsiniz.'
                  .tr,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _showCategories,
            onChanged: (v) => setState(() => _showCategories = v),
            title: Text('Kategori limitleri'.tr),
            subtitle: Text(
              'İsteğe bağlı: kategoriler için ayrı üst sınır belirleyin.'.tr,
            ),
          ),
          if (_showCategories)
            AppCard(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              child: Column(
                children: [
                  for (final c in AppConstants.categories)
                    _CategoryLimitRow(
                      categoryId: c.id,
                      spentCents: stats.categoryCents(c.id),
                      limitCents: budget?.categoryBudgetsInCents[c.id] ?? 0,
                      enabled: canEdit,
                      controller: _categoryControllers.putIfAbsent(
                        c.id,
                        TextEditingController.new,
                      ),
                    ),
                ],
              ),
            ),
          if (canEdit) ...[
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: 'Bütçeyi kaydet'.tr,
              icon: Icons.check_rounded,
              onPressed: _save,
              isLoading: _saving,
            ),
          ],
          if (canEdit && _ownBudget != null) ...[
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'Bütçeyi kaldır'.tr,
              outlined: true,
              destructive: true,
              onPressed: _delete,
            ),
          ],
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _Figure({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: context.textStyles.labelMedium?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: context.textStyles.titleMedium?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

class _CategoryLimitRow extends StatelessWidget {
  final String categoryId;
  final int spentCents;
  final int limitCents;
  final bool enabled;
  final TextEditingController controller;

  const _CategoryLimitRow({
    required this.categoryId,
    required this.spentCents,
    required this.limitCents,
    required this.enabled,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final category = AppConstants.getCategoryById(categoryId);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        children: [
          Row(
            children: [
              CategoryIcon(categoryId: categoryId, size: 36),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(category.name, style: context.textStyles.titleSmall),
                    Text(
                      'Harcanan {0}'.trArgs([
                        MoneyFormatter.formatCents(spentCents),
                      ]),
                      style: context.textStyles.bodySmall?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 130,
                child: TextFormField(
                  enabled: enabled,
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: const [ThousandsSeparatorInputFormatter()],
                  validator: Validators.optionalAmount,
                  textAlign: TextAlign.end,
                  decoration: InputDecoration(
                    hintText: 'Limit yok'.tr,
                    prefixText: '₺ ',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (limitCents > 0) ...[
            const SizedBox(height: 6),
            UsageBar(
              ratio: spentCents / limitCents,
              height: 6,
              semanticsLabel: '{0} limit kullanımı'.trArgs([category.name]),
            ),
          ],
        ],
      ),
    );
  }
}
