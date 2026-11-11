import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../application/providers/auth_providers.dart';
import '../../../application/providers/repository_providers.dart';
import '../../widgets/app_card.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(authStateProvider).value;
    final profile = ref.watch(userProfileProvider).value;

    return Scaffold(
      appBar: AppBar(title: const Text('Ayarlar')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Profil Özeti Kartı
          AppCard(
            onTap: () => context.push('/settings/profile'),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Text(
                    user?.displayName?.isNotEmpty == true ? user!.displayName![0].toUpperCase() : 'U',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.displayName ?? 'Kullanıcı',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user?.email ?? '',
                        style: TextStyle(color: theme.hintColor, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Colors.grey),
              ],
            ),
          ),
          const SizedBox(height: 24),

          Text('Tercihler & Yönetim', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),

          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.notifications_active_outlined),
                  title: const Text('Bildirim Ayarları'),
                  subtitle: Text(
                    profile?.dailyReminderEnabled == true
                        ? 'Günlük hatırlatıcı: ${profile!.dailyReminderHour.toString().padLeft(2, '0')}:${profile.dailyReminderMinute.toString().padLeft(2, '0')}'
                        : 'Hatırlatıcılar kapalı',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push('/settings/notifications'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.groups_outlined),
                  title: const Text('Takımlarım & Aile'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push('/teams'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.credit_card_outlined),
                  title: const Text('Kredi Kartlarım'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push('/cards-installments'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.category_outlined),
                  title: const Text('Kategoriler'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push('/settings/categories'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.palette_outlined),
                  title: const Text('Tema ve Dil'),
                  subtitle: const Text('Açık/Koyu tema, Türkçe/TRY', style: TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push('/settings/theme-language'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Çıkış Yap Butonu
          OutlinedButton.icon(
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Çıkış Yap'),
                  content: const Text('Oturumunuzu kapatmak istediğinizden emin misiniz?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                      child: const Text('Çıkış'),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                final authRepo = ref.read(authRepositoryProvider);
                await authRepo.signOut();
                if (context.mounted) {
                  context.go('/login');
                }
              }
            },
            icon: const Icon(Icons.logout_rounded, color: Colors.red),
            label: const Text('Çıkış Yap', style: TextStyle(color: Colors.red)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.red),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
