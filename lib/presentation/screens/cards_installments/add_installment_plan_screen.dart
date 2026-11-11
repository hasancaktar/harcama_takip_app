import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../application/providers/auth_providers.dart';
import '../../../application/providers/card_providers.dart';
import '../../../application/providers/repository_providers.dart';
import '../../../application/providers/team_providers.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/utils/statement_calculator.dart';
import '../../../domain/entities/expense.dart';
import '../../../domain/entities/installment_plan.dart';
import '../../widgets/app_card.dart';

class AddInstallmentPlanScreen extends ConsumerStatefulWidget {
  const AddInstallmentPlanScreen({super.key});

  @override
  ConsumerState<AddInstallmentPlanScreen> createState() => _AddInstallmentPlanScreenState();
}

class _AddInstallmentPlanScreenState extends ConsumerState<AddInstallmentPlanScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _titleController = TextEditingController();

  int _installmentsCount = 6;
  String? _selectedCardId;
  String _selectedCategory = 'home';
  String _visibility = 'personal';
  final DateTime _startDate = DateTime.now();
  bool _isLoading = false;

  @override
  void dispose() {
    _amountController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final totalCents = MoneyFormatter.parseToCents(_amountController.text);
    if (totalCents <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen geçerli bir toplam tutar giriniz.')),
      );
      return;
    }

    if (_selectedCardId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen bir kredi kartı seçiniz.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final uid = ref.read(currentUserIdProvider)!;
      final activeTeam = ref.read(activeTeamProvider);
      final cards = ref.read(creditCardsProvider).value ?? [];
      final selectedCard = cards.firstWhere((c) => c.id == _selectedCardId);

      // Kuruş bölme
      final dividedCents = MoneyFormatter.divideInstallmentCents(totalCents, _installmentsCount);

      // Plan oluştur
      final schedule = StatementCalculator.generateSchedule(
        startDate: _startDate,
        cutoffDay: selectedCard.cutoffDay,
        totalInstallments: _installmentsCount,
        installmentCentsList: dividedCents,
        paymentDueDaysAfterCutoff: selectedCard.paymentDueDaysAfterCutoff,
      );

      final planId = const Uuid().v4();
      final plan = InstallmentPlan(
        id: planId,
        ownerUid: uid,
        teamId: _visibility == 'team' ? activeTeam?.id : null,
        visibility: _visibility,
        title: _titleController.text.trim(),
        totalAmountInCents: totalCents,
        totalInstallments: _installmentsCount,
        cardId: selectedCard.id,
        cardLast4: selectedCard.last4Digits,
        category: _selectedCategory,
        startDate: _startDate,
        installmentSchedule: schedule,
        status: 'active',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final installmentRepo = ref.read(installmentRepositoryProvider);
      final expenseRepo = ref.read(expenseRepositoryProvider);

      await installmentRepo.createInstallmentPlan(plan);

      // İlk taksit hareketini doğrudan bu dönemin harcaması olarak oluştur
      final firstItem = schedule.first;
      final firstExpenseId = '${planId}_1_${firstItem.statementPeriod}';
      final firstExpense = Expense(
        id: firstExpenseId,
        teamId: plan.teamId,
        ownerUid: uid,
        visibility: plan.visibility,
        title: '${plan.title} (Taksit 1/${plan.totalInstallments})',
        amountInCents: firstItem.amountInCents,
        currency: 'TRY',
        category: _selectedCategory,
        date: _startDate,
        paymentMethod: 'credit_card',
        cardId: selectedCard.id,
        cardLast4: selectedCard.last4Digits,
        isInstallment: true,
        installmentPlanId: planId,
        installmentNumber: 1,
        totalInstallments: plan.totalInstallments,
        statementPeriod: firstItem.statementPeriod,
        createdBy: uid,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await expenseRepo.createExpense(firstExpense);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Taksit planı başarıyla oluşturuldu.')),
        );
        context.pop();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cards = ref.watch(creditCardsProvider).value ?? [];
    final activeTeam = ref.watch(activeTeamProvider);

    if (_selectedCardId == null && cards.isNotEmpty) {
      _selectedCardId = cards.first.id;
    }

    // Taksit önizleme hesapları
    final parsedTotal = MoneyFormatter.parseToCents(_amountController.text);
    final dividedPreview = parsedTotal > 0
        ? MoneyFormatter.divideInstallmentCents(parsedTotal, _installmentsCount)
        : <int>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Yeni Taksit Planı'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Toplam Tutar
            AppCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Toplam Alışveriş Tutarı', style: TextStyle(color: theme.hintColor, fontSize: 13)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text('₺', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _amountController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                          decoration: const InputDecoration(
                            hintText: '0,00',
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            fillColor: Colors.transparent,
                            contentPadding: EdgeInsets.zero,
                          ),
                          onChanged: (_) => setState(() {}),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return 'Tutar giriniz';
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Plan Başlığı
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Plan Başlığı / Ürün Adı',
                hintText: 'Örn: Çamaşır Makinesi / Telefon',
                prefixIcon: Icon(Icons.shopping_bag_outlined),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) return 'Plan başlığı giriniz';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Kart Seçimi
            if (cards.isEmpty)
              AppCard(
                color: Colors.amber.withOpacity(0.1),
                child: const Text('Taksit tanımlamak için önce bir kredi kartı eklemelisiniz.'),
              )
            else
              DropdownButtonFormField<String>(
                value: _selectedCardId,
                decoration: const InputDecoration(
                  labelText: 'Kredi Kartı',
                  prefixIcon: Icon(Icons.credit_card_rounded),
                ),
                items: cards.map((c) {
                  return DropdownMenuItem(
                    value: c.id,
                    child: Text('${c.name} (•••• ${c.last4Digits}) - Kesim: ${c.cutoffDay}. gün'),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedCardId = val),
              ),
            const SizedBox(height: 16),

            // Taksit Sayısı Seçimi (2 - 36)
            Text(
              'Taksit Sayısı: $_installmentsCount Taksit',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            Slider(
              value: _installmentsCount.toDouble(),
              min: 2,
              max: 24,
              divisions: 22,
              label: '$_installmentsCount Taksit',
              onChanged: (val) => setState(() => _installmentsCount = val.toInt()),
            ),
            const SizedBox(height: 8),

            // Kategori
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Kategori',
                prefixIcon: Icon(Icons.category_rounded),
              ),
              items: AppConstants.defaultCategories.map((c) {
                return DropdownMenuItem(value: c.id, child: Text(c.name));
              }).toList(),
              onChanged: (val) => setState(() => _selectedCategory = val!),
            ),
            const SizedBox(height: 16),

            // Görünürlük
            if (activeTeam != null) ...[
              SegmentedButton<String>(
                segments: [
                  const ButtonSegment(value: 'personal', label: Text('Bireysel Taksit')),
                  ButtonSegment(value: 'team', label: Text('${activeTeam.name} Takımı')),
                ],
                selected: {_visibility},
                onSelectionChanged: (val) => setState(() => _visibility = val.first),
              ),
              const SizedBox(height: 16),
            ],

            // Taksit Planı Önizleme Tablosu
            if (dividedPreview.isNotEmpty) ...[
              Text(
                'Ödeme Planı Önizlemesi',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              AppCard(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('İlk Taksit:', style: TextStyle(fontWeight: FontWeight.w600)),
                        Text(
                          MoneyFormatter.formatCents(dividedPreview.first),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    if (dividedPreview.length > 1) ...[
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Sonraki ${_installmentsCount - 1} Taksit:', style: const TextStyle(fontWeight: FontWeight.w600)),
                          Text(
                            MoneyFormatter.formatCents(dividedPreview[1]),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                    const Divider(height: 16),
                    Text(
                      'Tüm taksitler kart kesim tarihlerinde otomatik olarak ekstreye eklenecektir.',
                      style: TextStyle(fontSize: 11, color: theme.hintColor),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            ElevatedButton(
              onPressed: _isLoading ? null : _handleSave,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Taksit Planını Başlat'),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
