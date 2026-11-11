import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../application/providers/auth_providers.dart';
import '../../../application/providers/card_providers.dart';
import '../../../application/providers/repository_providers.dart';
import '../../../application/providers/team_providers.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/utils/statement_calculator.dart';
import '../../../domain/entities/expense.dart';
import '../../widgets/app_card.dart';

class AddEditExpenseScreen extends ConsumerStatefulWidget {
  final String? expenseId;

  const AddEditExpenseScreen({super.key, this.expenseId});

  @override
  ConsumerState<AddEditExpenseScreen> createState() => _AddEditExpenseScreenState();
}

class _AddEditExpenseScreenState extends ConsumerState<AddEditExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _titleController = TextEditingController();
  final _noteController = TextEditingController();

  String _selectedCategory = 'market';
  String _paymentMethod = 'credit_card';
  String? _selectedCardId;
  String _visibility = 'personal'; // 'personal' | 'team'
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final activeTeam = ref.read(activeTeamProvider);
    if (activeTeam != null) {
      _visibility = 'team';
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final amountCents = MoneyFormatter.parseToCents(_amountController.text);
    if (amountCents <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen geçerli bir tutar giriniz.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final uid = ref.read(currentUserIdProvider)!;
      final activeTeam = ref.read(activeTeamProvider);
      final cards = ref.read(creditCardsProvider).value ?? [];

      String? cardLast4;
      int cutoffDay = 1;
      if (_paymentMethod == 'credit_card' && _selectedCardId != null) {
        final card = cards.firstWhere((c) => c.id == _selectedCardId);
        cardLast4 = card.last4Digits;
        cutoffDay = card.cutoffDay;
      }

      // Ekstre dönemini kesim gününe göre otomatik hesapla
      final statementPeriod = StatementCalculator.resolveStatementPeriod(
        _selectedDate,
        cutoffDay,
      );

      final expenseId = widget.expenseId ?? const Uuid().v4();
      final newExpense = Expense(
        id: expenseId,
        teamId: _visibility == 'team' ? activeTeam?.id : null,
        ownerUid: uid,
        visibility: _visibility,
        title: _titleController.text.trim(),
        amountInCents: amountCents,
        currency: 'TRY',
        category: _selectedCategory,
        date: _selectedDate,
        paymentMethod: _paymentMethod,
        cardId: _selectedCardId,
        cardLast4: cardLast4,
        statementPeriod: statementPeriod,
        notes: _noteController.text.trim().isNotEmpty ? _noteController.text.trim() : null,
        createdBy: uid,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final expenseRepo = ref.read(expenseRepositoryProvider);
      await expenseRepo.createExpense(newExpense);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Harcama başarıyla kaydedildi.')),
        );
        context.pop();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kayıt hatası: $e')),
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

    // Otomatik ilk kartı seç
    if (_selectedCardId == null && cards.isNotEmpty) {
      _selectedCardId = cards.first.id;
    }

    // Ekstre dönemi önizlemesi
    int effectiveCutoff = 1;
    if (_paymentMethod == 'credit_card' && _selectedCardId != null && cards.isNotEmpty) {
      final card = cards.firstWhere((c) => c.id == _selectedCardId, orElse: () => cards.first);
      effectiveCutoff = card.cutoffDay;
    }
    final calculatedPeriod = StatementCalculator.resolveStatementPeriod(
      _selectedDate,
      effectiveCutoff,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.expenseId == null ? 'Yeni Harcama' : 'Harcama Düzenle'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Büyük Tutar Girişi (10-15 saniyede hızlı giriş için odak)
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tutar', style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        '₺',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _amountController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
                          decoration: const InputDecoration(
                            hintText: '0,00',
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            fillColor: Colors.transparent,
                            contentPadding: EdgeInsets.zero,
                          ),
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

            // Başlık / Açıklama
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Harcama Başlığı / Açıklama',
                hintText: 'Örn: Haftalık Market Alışverişi',
                prefixIcon: Icon(Icons.edit_note_rounded),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) return 'Lütfen bir başlık giriniz';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Kategori Seçimi (Yatay Liste)
            Text(
              'Kategori',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: AppConstants.defaultCategories.map((cat) {
                  final isSelected = _selectedCategory == cat.id;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      avatar: Icon(cat.icon, size: 18, color: isSelected ? Colors.white : cat.color),
                      label: Text(cat.name),
                      selected: isSelected,
                      selectedColor: theme.colorScheme.primary,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : null,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      onSelected: (_) => setState(() => _selectedCategory = cat.id),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),

            // Görünürlük (Bireysel vs Takım)
            Text(
              'Harcama Türü',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: [
                const ButtonSegment(
                  value: 'personal',
                  label: Text('Bireysel Harcamam'),
                  icon: Icon(Icons.person_rounded),
                ),
                ButtonSegment(
                  value: 'team',
                  label: Text(activeTeam != null ? activeTeam.name : 'Takım Harcaması'),
                  icon: const Icon(Icons.groups_rounded),
                  enabled: activeTeam != null,
                ),
              ],
              selected: {_visibility},
              onSelectionChanged: (val) => setState(() => _visibility = val.first),
            ),
            const SizedBox(height: 16),

            // Ödeme Yöntemi
            Text(
              'Ödeme Yöntemi',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _paymentMethod,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.payment_rounded),
              ),
              items: AppConstants.paymentMethods.entries.map((e) {
                return DropdownMenuItem(value: e.key, child: Text(e.value));
              }).toList(),
              onChanged: (val) => setState(() => _paymentMethod = val!),
            ),
            const SizedBox(height: 16),

            // Kredi Kartı Seçimi (Eğer kredi kartı seçildiyse)
            if (_paymentMethod == 'credit_card') ...[
              if (cards.isEmpty)
                AppCard(
                  color: Colors.amber.withOpacity(0.1),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, color: Colors.amber),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Kayıtlı kredi kartınız yok. Ayarlar > Kartlarım bölümünden kart ekleyebilirsiniz.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.push('/cards/add'),
                        child: const Text('Kart Ekle'),
                      ),
                    ],
                  ),
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
                      child: Text('${c.name} (••• ${c.last4Digits}) - Kesim: ${c.cutoffDay}. gün'),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedCardId = val),
                ),
              const SizedBox(height: 8),
              // Kesim Tarihi Önizleme Uyarısı
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_month_rounded, size: 18, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'İşlem tarihi kesim gününe göre hesaplandı: $calculatedPeriod ekstresine dahil edilecek.',
                        style: TextStyle(fontSize: 11, color: theme.colorScheme.primary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Harcama Tarihi Seçici
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: theme.dividerColor.withOpacity(0.15)),
              ),
              leading: const Icon(Icons.calendar_today_rounded),
              title: const Text('Harcama Tarihi'),
              subtitle: Text(DateFormat('d MMMM yyyy, HH:mm', 'tr_TR').format(_selectedDate)),
              trailing: const Icon(Icons.edit_calendar_rounded),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                );
                if (date != null && mounted) {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.fromDateTime(_selectedDate),
                  );
                  setState(() {
                    _selectedDate = DateTime(
                      date.year,
                      date.month,
                      date.day,
                      time?.hour ?? 12,
                      time?.minute ?? 0,
                    );
                  });
                }
              },
            ),
            const SizedBox(height: 16),

            // Not Alanı
            TextFormField(
              controller: _noteController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Not (İsteğe bağlı)',
                prefixIcon: Icon(Icons.notes_rounded),
              ),
            ),
            const SizedBox(height: 24),

            // Kaydet Butonu
            ElevatedButton(
              onPressed: _isLoading ? null : _handleSave,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Harcamayı Kaydet'),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
