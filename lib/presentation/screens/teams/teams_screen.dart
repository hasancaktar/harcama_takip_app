import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../application/providers/team_providers.dart';
import '../../widgets/app_card.dart';
import '../../widgets/empty_state_widget.dart';

class TeamsScreen extends ConsumerWidget {
  const TeamsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final teams = ref.watch(userTeamsProvider).value ?? [];
    final activeTeam = ref.watch(activeTeamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Takımlarım'),
        actions: [
          IconButton(
            icon: const Icon(Icons.mail_outline_rounded),
            tooltip: 'Davet Kodu Gir',
            onPressed: () => context.push('/teams/join'),
          ),
        ],
      ),
      body: teams.isEmpty
          ? EmptyStateWidget(
              icon: Icons.groups_outlined,
              title: 'Henüz Bir Takımınız Yok',
              message: 'Ailenizle veya arkadaşlarınızla ortak harcamalarınızı paylaşmak için bir takım oluşturun veya davet kodu ile katılın.',
              actionLabel: 'Yeni Takım Oluştur',
              onAction: () => context.push('/teams/create'),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Bireysel Mod Kartı
                AppCard(
                  onTap: () {
                    ref.read(activeTeamIdProvider.notifier).state = null;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Bireysel harcama moduna geçildi.')),
                    );
                  },
                  child: Row(
                    children: [
                      const CircleAvatar(
                        backgroundColor: Colors.blueGrey,
                        child: Icon(Icons.person_rounded, color: Colors.white),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Bireysel Mod', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            Text('Yalnızca kişisel harcamalarınızı görüntüler', style: TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                      ),
                      if (activeTeam == null)
                        Icon(Icons.check_circle_rounded, color: theme.colorScheme.primary),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Aktif Takımlar',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...teams.map((team) {
                  final isSelected = activeTeam?.id == team.id;
                  final teamColor = Color(int.parse(team.colorHex.replaceFirst('#', '0xFF')));

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: AppCard(
                      onTap: () => context.push('/teams/detail/${team.id}'),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: teamColor,
                            child: const Icon(Icons.groups_rounded, color: Colors.white),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(team.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                const SizedBox(height: 2),
                                Text(
                                  '${team.memberCount} Üye • ${team.defaultCurrency}',
                                  style: TextStyle(fontSize: 12, color: theme.hintColor),
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Seçili',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                          const SizedBox(width: 4),
                          const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/teams/create'),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}
