import 'package:harcama_takip/core/l10n/app_locale.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers/auth_providers.dart';
import '../../../application/providers/repository_providers.dart';
import '../../../application/providers/team_providers.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/errors/error_messages.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/color_utils.dart';
import '../../../core/utils/date_formats.dart';
import '../../../core/utils/validators.dart';
import '../../../domain/entities/team.dart';
import '../../../domain/entities/team_invite.dart';
import '../../../domain/entities/team_member.dart';
import '../../widgets/app_card.dart';
import '../../widgets/common.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/state_views.dart';

class TeamDetailScreen extends ConsumerWidget {
  final String teamId;
  const TeamDetailScreen({super.key, required this.teamId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teamAsync = ref.watch(teamByIdProvider(teamId));
    final uid = ref.watch(currentUserIdProvider);

    return Scaffold(
      appBar: AppBar(title: Text(teamAsync.valueOrNull?.name ?? 'Takım'.tr)),
      body: AsyncValueView<Team?>(
        value: teamAsync,
        onRetry: () => ref.invalidate(teamByIdProvider(teamId)),
        data: (team) {
          if (team == null ||
              team.isArchived ||
              !team.memberUids.contains(uid)) {
            return EmptyStateView(
              icon: Icons.group_off_outlined,
              title: 'Takıma erişilemiyor'.tr,
              message: 'Takım kapatılmış ya da artık üyesi değilsiniz.'.tr,
              actionLabel: 'Takımlara dön'.tr,
              actionIcon: Icons.arrow_back_rounded,
              onAction: () => context.go('/teams'),
            );
          }
          return _TeamBody(team: team, isOwner: team.ownerUid == uid);
        },
      ),
    );
  }
}

class _TeamBody extends ConsumerWidget {
  final Team team;
  final bool isOwner;
  const _TeamBody({required this.team, required this.isOwner});

  Future<void> _invite(BuildContext context, WidgetRef ref) async {
    final invite = await showDialog<TeamInvite>(
      context: context,
      builder: (_) => _InviteDialog(team: team),
    );
    if (invite != null && context.mounted) {
      await showDialog<void>(
        context: context,
        builder: (_) => _InviteCodeDialog(invite: invite),
      );
    }
  }

  Future<void> _leave(BuildContext context, WidgetRef ref) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Takımdan ayrılınsın mı?'.tr,
      message: 'Takım harcamalarını artık göremeyeceksiniz. Eklediğiniz harcamalar takımda kalır.'
          .tr,
      confirmLabel: 'Ayrıl'.tr,
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    final uid = ref.read(currentUserIdProvider);
    if (uid == null) return;
    try {
      if (ref.read(activeTeamProvider)?.id == team.id) {
        await ref.read(workspaceControllerProvider).select(null);
      }
      await ref
          .read(teamRepositoryProvider)
          .leaveTeam(teamId: team.id, uid: uid);
      if (context.mounted) {
        context.showSuccess('Takımdan ayrıldınız.'.tr);
        context.go('/teams');
      }
    } catch (e) {
      if (context.mounted) context.showError(e);
    }
  }

  Future<void> _archive(BuildContext context, WidgetRef ref) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Takım kapatılsın mı?'.tr,
      message: 'Takım tüm üyeler için listeden kaldırılır. Harcama kayıtları silinmez ancak takım üzerinden görüntülenemez.'
          .tr,
      confirmLabel: 'Takımı kapat'.tr,
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    try {
      if (ref.read(activeTeamProvider)?.id == team.id) {
        await ref.read(workspaceControllerProvider).select(null);
      }
      await ref.read(teamRepositoryProvider).archiveTeam(team.id);
      if (context.mounted) {
        context.showSuccess('Takım kapatıldı.'.tr);
        context.go('/teams');
      }
    } catch (e) {
      if (context.mounted) context.showError(e);
    }
  }

  Future<void> _removeMember(
    BuildContext context,
    WidgetRef ref,
    TeamMember member,
  ) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Üye çıkarılsın mı?'.tr,
      message: '{0} takımdan çıkarılacak ve takım harcamalarını göremeyecek.'
          .trArgs([member.label]),
      confirmLabel: 'Çıkar'.tr,
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    try {
      await ref
          .read(teamRepositoryProvider)
          .removeMember(teamId: team.id, memberUid: member.uid);
      if (context.mounted) {
        context.showSuccess('{0} takımdan çıkarıldı.'.trArgs([member.label]));
      }
    } catch (e) {
      if (context.mounted) context.showError(e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(teamMembersProvider(team.id));
    final invitesAsync = isOwner
        ? ref.watch(teamInvitesProvider(team.id))
        : null;
    final uid = ref.watch(currentUserIdProvider);
    final isActive = ref.watch(activeTeamProvider)?.id == team.id;
    final color = ColorUtils.fromHex(team.colorHex);
    final onColor = ColorUtils.onColor(color);

    return PageListView(
      children: [
        AppCard(
          color: color,
          borderColor: color,
          padding: const EdgeInsets.all(AppSpacing.lg - 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      team.name,
                      style: context.textStyles.titleLarge?.copyWith(
                        color: onColor,
                      ),
                    ),
                  ),
                  if (isOwner)
                    IconButton(
                      tooltip: 'Takımı düzenle'.tr,
                      color: onColor,
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => _EditTeamSheet(team: team),
                      ),
                    ),
                ],
              ),
              if (team.description != null) ...[
                const SizedBox(height: 4),
                Text(
                  team.description!,
                  style: context.textStyles.bodyMedium?.copyWith(
                    color: onColor.withValues(alpha: 0.85),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              Text(
                '{0} üye'.trArgs([team.memberCount]),
                style: context.textStyles.labelLarge?.copyWith(color: onColor),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (!isActive)
          AppButton(
            label: 'Bu takıma geç'.tr,
            icon: Icons.swap_horiz_rounded,
            outlined: true,
            onPressed: () async {
              await ref.read(workspaceControllerProvider).select(team.id);
              if (context.mounted) {
                context.showSuccess('Çalışma alanı: {0}'.trArgs([team.name]));
              }
            },
          )
        else
          InlineMessage(
            tone: MessageTone.success,
            message: 'Bu takım aktif çalışma alanınız. Yeni harcamalar varsayılan olarak bu takıma eklenir.'
                .tr,
          ),
        SectionHeader(
          title: 'Üyeler'.tr,
          actionLabel: isOwner ? 'Davet et'.tr : null,
          onAction: isOwner ? () => _invite(context, ref) : null,
        ),
        membersAsync.when(
          skipLoadingOnReload: false,
          loading: () => const SizedBox(height: 120, child: LoadingView()),
          error: (e, _) => ErrorStateView(error: e, compact: true),
          data: (members) => AppCard(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
            child: Column(
              children: [
                for (final m in members)
                  ListTile(
                    leading: UserAvatar(name: m.label),
                    title: Text(
                      m.uid == uid ? '{0} (siz)'.trArgs([m.label]) : m.label,
                    ),
                    subtitle: Text(m.email),
                    trailing: isOwner && !m.isOwner
                        ? IconButton(
                            tooltip: '{0} adlı üyeyi çıkar'.trArgs([m.label]),
                            icon: const Icon(Icons.person_remove_outlined),
                            onPressed: () => _removeMember(context, ref, m),
                          )
                        : Pill(label: AppConstants.teamRoleName(m.role)),
                  ),
              ],
            ),
          ),
        ),
        if (invitesAsync != null) ...[
          SectionHeader(title: 'Bekleyen davetler'.tr),
          invitesAsync.when(
            skipLoadingOnReload: false,
            loading: () => const SizedBox(height: 80, child: LoadingView()),
            error: (e, _) => ErrorStateView(error: e, compact: true),
            data: (invites) => invites.isEmpty
                ? AppCard(
                    child: Text(
                      'Bekleyen davet yok. "Davet et" ile e-posta adresine özel bir davet kodu oluşturun.'
                          .tr,
                      style: context.textStyles.bodyMedium?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                  )
                : AppCard(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.xxs,
                    ),
                    child: Column(
                      children: [
                        for (final i in invites)
                          ListTile(
                            leading: const Icon(
                              Icons.mark_email_unread_outlined,
                            ),
                            title: Text(
                              i.invitedEmail,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              'Kod: {0} · son gün {1}'.trArgs([
                                i.code,
                                DateFormats.dayShort(i.expiresAt),
                              ]),
                            ),
                            onTap: () => showDialog<void>(
                              context: context,
                              builder: (_) => _InviteCodeDialog(invite: i),
                            ),
                            trailing: IconButton(
                              tooltip: 'Daveti iptal et'.tr,
                              icon: const Icon(Icons.cancel_outlined),
                              onPressed: () async {
                                try {
                                  await ref
                                      .read(teamRepositoryProvider)
                                      .revokeInvite(
                                        teamId: team.id,
                                        inviteId: i.id,
                                      );
                                  if (context.mounted) {
                                    context.showSuccess(
                                      'Davet iptal edildi.'.tr,
                                    );
                                  }
                                } catch (e) {
                                  if (context.mounted) context.showError(e);
                                }
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        if (isOwner)
          AppButton(
            label: 'Takımı kapat'.tr,
            icon: Icons.archive_outlined,
            outlined: true,
            destructive: true,
            onPressed: () => _archive(context, ref),
          )
        else
          AppButton(
            label: 'Takımdan ayrıl'.tr,
            icon: Icons.logout_rounded,
            outlined: true,
            destructive: true,
            onPressed: () => _leave(context, ref),
          ),
      ],
    );
  }
}

class _InviteDialog extends ConsumerStatefulWidget {
  final Team team;
  const _InviteDialog({required this.team});

  @override
  ConsumerState<_InviteDialog> createState() => _InviteDialogState();
}

class _InviteDialogState extends ConsumerState<_InviteDialog> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final invite = await ref
          .read(teamRepositoryProvider)
          .createInvite(
            team: widget.team,
            email: _emailController.text,
            invitedBy: user,
          );
      if (mounted) Navigator.pop(context, invite);
    } catch (e) {
      if (mounted) setState(() => _error = ErrorMessages.from(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Üye davet et'.tr),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Davet edeceğiniz kişinin e-posta adresini girin. Size özel bir kod oluşturulur; kişi bu adresle uygulamaya giriş yaptığında daveti görür veya kodla katılır.'
                    .tr,
              ),
              const SizedBox(height: AppSpacing.md),
              if (_error != null) ...[
                InlineMessage(message: _error!, tone: MessageTone.error),
                const SizedBox(height: AppSpacing.sm),
              ],
              TextFormField(
                controller: _emailController,
                autofocus: true,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                validator: Validators.email,
                onFieldSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: 'E-posta'.tr,
                  prefixIcon: Icon(Icons.alternate_email_rounded),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Vazgeç'.tr),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          style: FilledButton.styleFrom(minimumSize: const Size(64, 44)),
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text('Davet oluştur'.tr),
        ),
      ],
    );
  }
}

class _InviteCodeDialog extends StatelessWidget {
  final TeamInvite invite;
  const _InviteCodeDialog({required this.invite});

  String get _shareText => '"{0}" takımına katılmak için Harcama Takip uygulamasında {1} adresiyle giriş yapın ve Takımlar > Kodla katıl bölümüne {2} kodunu girin.'
      .trArgs([invite.teamName, invite.invitedEmail, invite.code]);

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return AlertDialog(
      title: Text('Davet kodu hazır'.tr),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '{0} için davet oluşturuldu. Kodu kişiyle paylaşın:'.trArgs([
                invite.invitedEmail,
              ]),
            ),
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: SelectableText(
                invite.code,
                textAlign: TextAlign.center,
                style: context.textStyles.headlineMedium?.copyWith(
                  letterSpacing: 6,
                  color: scheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Kod {0} tarihine kadar ve yalnızca bu e-posta adresi için geçerlidir.'
                  .trArgs([DateFormats.day(invite.expiresAt)]),
              style: context.textStyles.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: _shareText));
            if (context.mounted) {
              context.showSuccess('Davet mesajı kopyalandı.'.tr);
            }
          },
          icon: const Icon(Icons.copy_rounded),
          label: Text('Mesajı kopyala'.tr),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          style: FilledButton.styleFrom(minimumSize: const Size(64, 44)),
          child: Text('Tamam'.tr),
        ),
      ],
    );
  }
}

class _EditTeamSheet extends ConsumerStatefulWidget {
  final Team team;
  const _EditTeamSheet({required this.team});

  @override
  ConsumerState<_EditTeamSheet> createState() => _EditTeamSheetState();
}

class _EditTeamSheetState extends ConsumerState<_EditTeamSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.team.name);
  late final _description = TextEditingController(
    text: widget.team.description ?? '',
  );
  late String _colorHex = widget.team.colorHex;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(teamRepositoryProvider)
          .updateTeam(
            teamId: widget.team.id,
            name: _name.text.trim(),
            description: _description.text.trim().isEmpty
                ? null
                : _description.text.trim(),
            colorHex: _colorHex,
          );
      if (mounted) {
        Navigator.pop(context);
        context.showSuccess('Takım güncellendi.'.tr);
      }
    } catch (e) {
      if (mounted) {
        context.showError(e);
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            0,
            AppSpacing.md,
            AppSpacing.lg,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Takımı düzenle'.tr, style: context.textStyles.titleLarge),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _name,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(
                      AppConstants.maxNameLength,
                    ),
                  ],
                  validator: Validators.requiredText(
                    'Takım adı'.tr,
                    maxLength: AppConstants.maxNameLength,
                  ),
                  decoration: InputDecoration(labelText: 'Takım adı'.tr),
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _description,
                  maxLines: 2,
                  inputFormatters: [LengthLimitingTextInputFormatter(200)],
                  decoration: InputDecoration(labelText: 'Açıklama'.tr),
                ),
                const SizedBox(height: AppSpacing.md),
                ColorPickerRow(
                  selectedHex: _colorHex,
                  onSelected: (h) => setState(() => _colorHex = h),
                ),
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  label: 'Kaydet'.tr,
                  onPressed: _save,
                  isLoading: _saving,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
