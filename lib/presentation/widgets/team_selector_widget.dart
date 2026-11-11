import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/providers/team_providers.dart';

class TeamSelectorWidget extends ConsumerWidget {
  const TeamSelectorWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeTeam = ref.watch(activeTeamProvider);
    final userTeams = ref.watch(userTeamsProvider).value ?? [];
    final theme = Theme.of(context);

    return InkWell(
      onTap: () {
        showModalBottomSheet(
          context: context,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          builder: (ctx) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        'Çalışma Alanı Seç',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Colors.blueGrey,
                        child: Icon(Icons.person_rounded, color: Colors.white),
                      ),
                      title: const Text('Bireysel Harcamalarım'),
                      subtitle: const Text('Yalnızca sizin görebileceğiniz kayıtlar'),
                      trailing: activeTeam == null
                          ? Icon(Icons.check_circle_rounded, color: theme.colorScheme.primary)
                          : null,
                      onTap: () {
                        ref.read(activeTeamIdProvider.notifier).state = null;
                        Navigator.pop(ctx);
                      },
                    ),
                    const Divider(),
                    if (userTeams.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(20),
                        child: Text(
                          'Henüz bir takıma üye değilsiniz. Ayarlar > Takımlarım bölümünden yeni takım oluşturabilirsiniz.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    else
                      ...userTeams.map((team) {
                        final isSelected = activeTeam?.id == team.id;
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Color(
                              int.parse(team.colorHex.replaceFirst('#', '0xFF')),
                            ),
                            child: const Icon(Icons.groups_rounded, color: Colors.white),
                          ),
                          title: Text(team.name),
                          subtitle: Text('${team.memberCount} Üye'),
                          trailing: isSelected
                              ? Icon(Icons.check_circle_rounded, color: theme.colorScheme.primary)
                              : null,
                          onTap: () {
                            ref.read(activeTeamIdProvider.notifier).state = team.id;
                            Navigator.pop(ctx);
                          },
                        );
                      }),
                  ],
                ),
              ),
            );
          },
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.colorScheme.primary.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              activeTeam == null ? Icons.person_rounded : Icons.groups_rounded,
              size: 18,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 6),
            Text(
              activeTeam?.name ?? 'Bireysel',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down_rounded, size: 20, color: theme.colorScheme.primary),
          ],
        ),
      ),
    );
  }
}
