import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../application/providers/auth_providers.dart';
import '../../../application/providers/repository_providers.dart';
import '../../../application/providers/team_providers.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../domain/entities/credit_card.dart';

class AddEditCardScreen extends ConsumerStatefulWidget {
  final String? cardId;

  const AddEditCardScreen({super.key, this.cardId});

  @override
  ConsumerState<AddEditCardScreen> createState() => _AddEditCardScreenState();
}

class _AddEditCardScreenState extends ConsumerState<AddEditCardScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _bankController = TextEditingController();
  final _last4Controller = TextEditingController();
  final _limitController = TextEditingController();

  int _cutoffDay = 15;
  int _dueDaysAfterCutoff = 10;
  String _selectedColorHex = '#1E3A8A';
  bool _isSharedWithTeam = false;
  bool _isLoading = false;

  final List<String> _colorOptions = [
    '#1E3A8A', // Derin Gece Mavisi
    '#0F5132', // Zümrüt Yeşili
    '#7C3AED', // Asil Mor
    '#B91C1C', // Yakut Kırmızısı
    '#D97706', // Kehribar Sarısı
    '#0F172A', // Antrasit / Platin Siyah
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _bankController.dispose();
    _last4Controller.dispose();
    _limitController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final uid = ref.read(currentUserIdProvider)!;
      final activeTeam = ref.read(activeTeamProvider);
      final limitCents = MoneyFormatter.parseToCents(_limitController.text);

      final cardId = widget.cardId ?? const Uuid().v4();
      final newCard = CreditCard(
        id: cardId,
        ownerUid: uid,
        teamId: _isSharedWithTeam ? activeTeam?.id : null,
        isSharedWithTeam: _isSharedWithTeam,
        name: _nameController.text.trim(),
        bankName: _bankController.text.trim(),
        last4Digits: _last4Controller.text.trim(),
        colorHex: _selectedColorHex,
        limitInCents: limitCents,
        cutoffDay: _cutoffDay,
        paymentDueDaysAfterCutoff: _dueDaysAfterCutoff,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final cardRepo = ref.read(cardRepositoryProvider);
      await cardRepo.createCard(newCard);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kart başarıyla kaydedildi.')),
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
    final activeTeam = ref.watch(activeTeamProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.cardId == null ? 'Yeni Kredi Kartı' : 'Kartı Düzenle'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Güvenlik Bilgilendirme Notu
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withOpacity(0.4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.security_rounded, color: theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Güvenliğiniz için yalnızca kart adı ve son 4 hanesi saklanır. Tam kart numarası ve CVV asla istenmez.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Kart Adı
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Kart Adı',
                hintText: 'Örn: Maximum Platinum',
                prefixIcon: Icon(Icons.credit_card_rounded),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) return 'Kart adını giriniz';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Banka Adı
            TextFormField(
              controller: _bankController,
              decoration: const InputDecoration(
                labelText: 'Banka Adı',
                hintText: 'Örn: İş Bankası / Garanti BBVA',
                prefixIcon: Icon(Icons.account_balance_rounded),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) return 'Banka adını giriniz';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Son 4 Hane
            TextFormField(
              controller: _last4Controller,
              keyboardType: TextInputType.number,
              maxLength: 4,
              decoration: const InputDecoration(
                labelText: 'Kartın Son 4 Hanesi',
                hintText: '1234',
                prefixIcon: Icon(Icons.pin_rounded),
              ),
              validator: (val) {
                if (val == null || val.trim().length != 4) return 'Lütfen son 4 haneyi giriniz';
                return null;
              },
            ),
            const SizedBox(height: 8),

            // Kesim Günü Seçimi (1 - 31)
            Text(
              'Hesap Kesim Günü (Her Ayın Kaçıncı Günü?)',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _cutoffDay,
                  isExpanded: true,
                  items: List.generate(31, (index) => index + 1).map((day) {
                    return DropdownMenuItem<int>(
                      value: day,
                      child: Text('Her ayın $day. günü'),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _cutoffDay = val!),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Son Ödeme Vadesi (Kesimden kaç gün sonra?)
            Text(
              'Son Ödeme Tarihi Vadesi',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _dueDaysAfterCutoff,
                  isExpanded: true,
                  items: [7, 10, 12, 14, 15].map((days) {
                    return DropdownMenuItem<int>(
                      value: days,
                      child: Text('Hesap kesiminden $days gün sonra'),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _dueDaysAfterCutoff = val!),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Kart Kartvizit Rengi
            Text(
              'Kart Rengi',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: _colorOptions.map((hex) {
                final color = Color(int.parse(hex.replaceFirst('#', '0xFF')));
                final isSelected = _selectedColorHex == hex;
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: InkWell(
                    onTap: () => setState(() => _selectedColorHex = hex),
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(color: theme.colorScheme.primary, width: 3)
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
                          : null,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Takımla Paylaşım
            if (activeTeam != null)
              SwitchListTile(
                value: _isSharedWithTeam,
                title: Text('${activeTeam.name} takımı ile paylaş'),
                subtitle: const Text('Takım üyeleri bu kartın kesim tarihlerini görebilir'),
                onChanged: (val) => setState(() => _isSharedWithTeam = val),
              ),

            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _handleSave,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Kartı Kaydet'),
            ),
          ],
        ),
      ),
    );
  }
}
