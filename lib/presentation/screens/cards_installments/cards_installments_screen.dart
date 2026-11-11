import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../application/providers/card_providers.dart';
import '../../../application/providers/installment_providers.dart';
import '../../../core/utils/money_formatter.dart';
import '../../widgets/app_card.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/team_selector_widget.dart';

class CardsInstallmentsScreen extends ConsumerStatefulWidget {
  const CardsInstallmentsScreen({super.key});

  @override
  ConsumerState<CardsInstallmentsScreen> createState() => _CardsInstallmentsScreenState();
}

class _CardsInstallmentsScreenState extends ConsumerState<CardsInstallmentsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cards = ref.watch(creditCardsProvider).value ?? [];
    final installmentPlans = ref.watch(installmentPlansProvider).value ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kartlar & Taksitler'),
        actions: const [
          TeamSelectorWidget(),
          SizedBox(width: 12),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: theme.colorScheme.primary,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: theme.hintColor,
          tabs: const [
            Tab(text: 'Kredi Kartları', icon: Icon(Icons.credit_card_rounded, size: 20)),
            Tab(text: 'Taksit Planları', icon: Icon(Icons.splitscreen_rounded, size: 20)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 1. Kredi Kartları Sekmesi
          cards.isEmpty
              ? EmptyStateWidget(
                  icon: Icons.credit_card_off_rounded,
                  title: 'Kayıtlı Kart Yok',
                  message: 'Kredi kartlarınızı ekleyerek kesim tarihlerini ve taksitlerinizi takip edin.',
                  actionLabel: 'Yeni Kart Ekle',
                  onAction: () => context.push('/cards/add'),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: cards.length,
                  itemBuilder: (context, index) {
                    final card = cards[index];
                    final cardColor = Color(int.parse(card.colorHex.replaceFirst('#', '0xFF')));

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: AppCard(
                        padding: const EdgeInsets.all(16),
                        color: cardColor.withOpacity(0.08),
                        border: Border.all(color: cardColor.withOpacity(0.3)),
                        onTap: () => context.push('/cards/statement/${card.id}'),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  card.bankName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: cardColor,
                                    fontSize: 14,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: cardColor.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '•••• ${card.last4Digits}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: cardColor,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              card.name,
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 12),
                            const Divider(),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Kesim Günü', style: TextStyle(fontSize: 11, color: theme.hintColor)),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Her ayın ${card.cutoffDay}. günü',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text('Son Ödeme Vadesi', style: TextStyle(fontSize: 11, color: theme.hintColor)),
                                    const SizedBox(height: 2),
                                    Text(
                                      '+${card.paymentDueDaysAfterCutoff} gün',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

          // 2. Taksit Planları Sekmesi
          installmentPlans.isEmpty
              ? EmptyStateWidget(
                  icon: Icons.splitscreen_rounded,
                  title: 'Aktif Taksit Yok',
                  message: 'Taksitli harcama planı oluşturarak aylık ödeme yükünüzü ve bitiş tarihlerini izleyin.',
                  actionLabel: 'Yeni Taksit Planı Ekle',
                  onAction: () => context.push('/installments/add'),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: installmentPlans.length,
                  itemBuilder: (context, index) {
                    final plan = installmentPlans[index];
                    final postedCount = plan.installmentSchedule.where((s) => s.status == 'posted').length;
                    final progress = (postedCount / plan.totalInstallments).clamp(0.0, 1.0);
                    final monthlyCents = plan.totalAmountInCents ~/ plan.totalInstallments;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: AppCard(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    plan.title,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                ),
                                Text(
                                  MoneyFormatter.formatCents(plan.totalAmountInCents, currency: plan.currency),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Aylık Yaklaşık: ${MoneyFormatter.formatCents(monthlyCents)} • Kart: •••• ${plan.cardLast4}',
                              style: TextStyle(fontSize: 12, color: theme.hintColor),
                            ),
                            const SizedBox(height: 12),
                            LinearProgressIndicator(
                              value: progress,
                              backgroundColor: theme.colorScheme.surfaceVariant,
                              minHeight: 6,
                              borderRadius: BorderRadius.circular(3),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '$postedCount / ${plan.totalInstallments} Taksit Ödendi/Kesildi',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  plan.status == 'active' ? 'Devam Ediyor' : 'Tamamlandı',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: plan.status == 'active' ? theme.colorScheme.primary : Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_tabController.index == 0) {
            context.push('/cards/add');
          } else {
            context.push('/installments/add');
          }
        },
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}
