import 'package:harcama_takip/core/l10n/app_locale.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers/auth_providers.dart';
import '../../../application/providers/repository_providers.dart';
import '../../../application/providers/team_providers.dart';
import '../../../core/errors/error_messages.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/color_utils.dart';
import '../../../core/utils/date_formats.dart';
import '../../../domain/entities/team.dart';
import '../../../domain/entities/team_invite.dart';
import '../../widgets/app_card.dart';
import '../../widgets/common.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/state_views.dart';

class TeamsScreen extends ConsumerWidget {
  const TeamsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teamsAsync = ref.watch(userTeamsProvider);
    final invites = ref.watch(myPendingInvitesProvider).valueOrNull ?? const [];
    final activeId = ref.watch(activeTeamProvider)?.id;
    final uid = ref.watch(currentUserIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Takımlar'.tr),
        actions: [
          TextButton.icon(
            onPressed: () => context.push('/teams/join'),
            icon: const Icon(Icons.vpn_key_outlined),
            label: Text('Kodla katıl'.tr),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab-teams',
        onPressed: () => context.push('/teams/new'),
        icon: const Icon(Icons.group_add_rounded),
        label: Text('Takım oluştur'.tr),
      ),
      body: AsyncValueView<List<Team>>(
        value: teamsAsync,
        onRetry: () => ref.invalidate(userTeamsProvider),
        data: (teams) => PageListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            96,
          ),
          children: [
            Text(
              'Ailenizle veya ev arkadaşlarınızla ortak harcamaları, bütçeyi ve kartları paylaşın. Kişisel harcamalarınız her zaman yalnızca size görünür.'
                  .tr,
              style: context.textStyles.bodyMedium?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
            if (invites.isNotEmpty) ...[
              SectionHeader(title: 'Bekleyen davetler'.tr),
              for (final invite in invites) ...[
                _InviteCard(invite: invite),
                const SizedBox(height: AppSpacing.sm),
              ],
            ],
            SectionHeader(title: 'Takımlarım'.tr),
            if (teams.isEmpty)
              AppCard(
                child: EmptyStateView(
                  compact: true,
                  icon: Icons.groups_outlined,
                  title: 'Henüz bir takımınız yok'.tr,
                  message: 'Yeni bir takım oluşturun veya size gönderilen davet koduyla katılın.'
                      .tr,
                  actionLabel: 'Takım oluştur'.tr,
                  actionIcon: Icons.group_add_rounded,
                  onAction: () => context.push('/teams/new'),
                ),
              )
            else
              for (final team in teams) ...[
                AppCard(
                  onTap: () => context.push('/teams/${team.id}'),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: ColorUtils.fromHex(team.colorHex),
                        child: Icon(
                          Icons.groups_rounded,
                          color: ColorUtils.onColor(
                            ColorUtils.fromHex(team.colorHex),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              team.name,
                              style: context.textStyles.titleSmall,
                            ),
                            Text(
                              '{0} üye{1}'.trArgs([
                                team.memberCount,
                                team.ownerUid == uid ? ' · Sahibisiniz'.tr : '',
                              ]),
                              style: context.textStyles.bodySmall?.copyWith(
                                color: context.colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (team.id == activeId)
                        Pill(label: 'Aktif'.tr, color: context.colors.primary),
                      const Icon(Icons.chevron_right_rounded),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
          ],
        ),
      ),
    );
  }
}

class _InviteCard extends ConsumerStatefulWidget {
  final TeamInvite invite;
  const _InviteCard({required this.invite});

  @override
  ConsumerState<_InviteCard> createState() => _InviteCardState();
}

class _InviteCardState extends ConsumerState<_InviteCard> {
  bool _busy = false;

  Future<void> _accept() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    // Kabul edilen davet listeden düştüğünde bu kart ağaçtan kaldırılır; bu yüzden
    // gerekli nesneler await'ten ÖNCE alınır (kaldırılmış widget'ta ref kullanılamaz).
    final repo = ref.read(teamRepositoryProvider);
    final workspace = ref.read(workspaceControllerProvider);
    final messenger = ScaffoldMessenger.of(context);
    final invite = widget.invite;
    setState(() => _busy = true);
    try {
      await repo.acceptInvite(invite: invite, user: user);
      await workspace.select(invite.teamId);
      messenger.showSnackBar(
        SnackBar(
          content: Text('"{0}" takımına katıldınız.'.trArgs([invite.teamName])),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(ErrorMessages.from(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _decline() async {
    final repo = ref.read(teamRepositoryProvider);
    final ok = await showConfirmDialog(
      context,
      title: 'Davet reddedilsin mi?'.tr,
      message: '"{0}" takımına yapılan davet reddedilecek.'.trArgs([
        widget.invite.teamName,
      ]),
      confirmLabel: 'Reddet'.tr,
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await repo.declineInvite(widget.invite);
    } catch (e) {
      if (mounted) context.showError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final invite = widget.invite;
    return AppCard(
      borderColor: context.colors.primary.withValues(alpha: 0.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.mail_outline_rounded, color: context.colors.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(invite.teamName, style: context.textStyles.titleSmall),
                    Text(
                      '{0}Son gün {1}'.trArgs([
                        invite.createdByName.isNotEmpty
                            ? '{0} sizi davet etti · '.trArgs([
                                invite.createdByName,
                              ])
                            : '',
                        DateFormats.dayShort(invite.expiresAt),
                      ]),
                      style: context.textStyles.bodySmall?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Reddet'.tr,
                  outlined: true,
                  onPressed: _busy ? null : _decline,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AppButton(
                  label: 'Katıl'.tr,
                  onPressed: _accept,
                  isLoading: _busy,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
