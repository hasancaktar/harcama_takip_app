import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../application/providers/auth_providers.dart';
import '../../../application/providers/repository_providers.dart';
import '../../../application/providers/team_providers.dart';
import '../../../domain/entities/team_member.dart';
import '../../widgets/app_card.dart';

class TeamDetailScreen extends ConsumerWidget {
  final String teamId;

  const TeamDetailScreen({super.key, required this.teamId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final teamRepo = ref.watch(teamRepositoryProvider);
    final teams = ref.watch(userTeamsProvider).value ?? [];
    final team = teams.firstWhere((t) => t.id == teamId);
    final uid = ref.watch(currentUserIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(team.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_rounded),
            tooltip: 'Üye Davet Et',
            onPressed: () => _showInviteDialog(context, ref, team.name),
          ),
        ],
      ),
      body: StreamBuilder<List<TeamMember>>(
        stream: teamRepo.watchTeamMembers(teamId),
        builder: (context, snapshot) {
          final members = snapshot.data ?? [];

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Takım Başlık Kartı
              AppCard(
                color: Color(int.parse(team.colorHex.replaceFirst('#', '0xFF'))),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(team.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
                    if (team.description != null) ...[
                      const SizedBox(height: 6),
                      Text(team.description!, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    ],
                    const SizedBox(height: 12),
                    Text(
                      '${members.length} Aktif Üye • Para Birimi: ${team.defaultCurrency}',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Takım Üyeleri', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  TextButton.icon(
                    onPressed: () => _showInviteDialog(context, ref, team.name),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Davet Et'),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              ...members.map((member) {
                final isMe = member.uid == uid;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AppCard(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        CircleAvatar(
                          child: Text(member.displayName.isNotEmpty ? member.displayName[0].toUpperCase() : '?'),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${member.displayName} ${isMe ? '(Siz)' : ''}',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text(member.email, style: TextStyle(fontSize: 12, color: theme.hintColor)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceVariant,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            member.role == 'owner' ? 'Sahip' : 'Üye',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),

              const SizedBox(height: 32),
              OutlinedButton.icon(
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Takımdan Ayrıl'),
                      content: const Text('Bu takımdan ayrılmak istediğinizden emin misiniz?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          style: TextButton.styleFrom(foregroundColor: Colors.red),
                          child: const Text('Ayrıl'),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true && uid != null) {
                    await teamRepo.leaveTeam(teamId, uid);
                    if (context.mounted) {
                      ref.read(activeTeamIdProvider.notifier).state = null;
                      context.pop();
                    }
                  }
                },
                style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                icon: const Icon(Icons.exit_to_app_rounded),
                label: const Text('Takımdan Ayrıl'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showInviteDialog(BuildContext context, WidgetRef ref, String teamName) {
    final emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Üye Davet Et'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Davet etmek istediğiniz aile üyenizin veya arkadaşınızın e-posta adresini girin:'),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'E-posta',
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () async {
              final email = emailController.text.trim();
              if (email.isNotEmpty) {
                final uid = ref.read(currentUserIdProvider)!;
                final teamRepo = ref.read(teamRepositoryProvider);
                await teamRepo.inviteMember(
                  teamId: teamId,
                  teamName: teamName,
                  email: email,
                  invitedByUid: uid,
                );
                if (context.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Davet başarıyla oluşturuldu.')),
                  );
                }
              }
            },
            child: const Text('Davet Gönder'),
          ),
        ],
      ),
    );
  }
}
