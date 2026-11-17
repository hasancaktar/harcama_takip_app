import 'package:harcama_takip/core/l10n/app_locale.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/providers/team_providers.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/color_utils.dart';
import 'dialogs.dart';
import 'period_selector_widget.dart';

/// Çalışma alanı (Bireysel / Takım) seçici çipi.
class WorkspaceSelector extends ConsumerWidget {
  const WorkspaceSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspace = ref.watch(workspaceProvider).valueOrNull;
    final team = workspace?.team;
    final scheme = context.colors;
    final color = team != null
        ? ColorUtils.fromHex(team.colorHex)
        : scheme.primary;

    return Semantics(
      button: true,
      label: 'Çalışma alanı: {0}. Değiştirmek için dokunun.'.trArgs([
        workspace?.label ?? 'Bireysel'.tr,
      ]),
      excludeSemantics: true,
      child: Material(
        color: scheme.surfaceContainerLowest,
        shape: StadiumBorder(side: BorderSide(color: scheme.outlineVariant)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: () => showWorkspaceSheet(context, ref),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 6, 10, 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: color,
                  child: Icon(
                    team == null ? Icons.person_rounded : Icons.groups_rounded,
                    size: 16,
                    color: ColorUtils.onColor(color),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Flexible(
                  child: Text(
                    workspace?.label ?? 'Bireysel'.tr,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textStyles.titleSmall,
                  ),
                ),
                const Icon(Icons.expand_more_rounded, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> showWorkspaceSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => Consumer(
      builder: (context, ref, _) {
        final workspace = ref.watch(workspaceProvider).valueOrNull;
        final teams = workspace?.teams ?? const [];
        final activeId = workspace?.teamId;
        final scheme = context.colors;

        Future<void> select(String? teamId) async {
          Navigator.pop(sheetContext);
          try {
            await ref.read(workspaceControllerProvider).select(teamId);
          } catch (e) {
            if (context.mounted) context.showError(e);
          }
        }

        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.75,
            ),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.md,
              ),
              children: [
                Text('Çalışma alanı'.tr, style: context.textStyles.titleLarge),
                const SizedBox(height: 4),
                Text(
                  'Harcamalar, bütçe ve raporlar seçtiğiniz alana göre gösterilir.'
                      .tr,
                  style: context.textStyles.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                _WorkspaceOption(
                  icon: Icons.person_rounded,
                  color: scheme.primary,
                  title: 'Bireysel'.tr,
                  subtitle: 'Yalnızca sizin gördüğünüz kişisel harcamalar'.tr,
                  selected: activeId == null,
                  onTap: () => select(null),
                ),
                for (final team in teams)
                  _WorkspaceOption(
                    icon: Icons.groups_rounded,
                    color: ColorUtils.fromHex(team.colorHex),
                    title: team.name,
                    subtitle: '{0} üye · ortak harcamalar'.trArgs([
                      team.memberCount,
                    ]),
                    selected: activeId == team.id,
                    onTap: () => select(team.id),
                  ),
                const SizedBox(height: AppSpacing.xs),
                ListTile(
                  leading: const Icon(Icons.group_add_outlined),
                  title: Text(
                    teams.isEmpty
                        ? 'Takım oluştur veya katıl'.tr
                        : 'Takımları yönet'.tr,
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    context.push('/teams');
                  },
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

class _WorkspaceOption extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _WorkspaceOption({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: ListTile(
        selected: selected,
        selectedTileColor: scheme.primaryContainer.withValues(alpha: 0.5),
        leading: CircleAvatar(
          backgroundColor: color,
          child: Icon(icon, color: ColorUtils.onColor(color), size: 20),
        ),
        title: Text(title, style: context.textStyles.titleSmall),
        subtitle: Text(subtitle),
        trailing: selected
            ? Icon(Icons.check_circle_rounded, color: scheme.primary)
            : null,
        onTap: onTap,
      ),
    );
  }
}

/// Sayfa üstündeki bağlam çubuğu: çalışma alanı + dönem seçici.
/// Dar ekranlarda iki satıra sarılır; AppBar taşmasını önler.
class ContextBar extends StatelessWidget {
  final bool showPeriod;
  const ContextBar({super.key, this.showPeriod = true});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 260),
            child: const WorkspaceSelector(),
          ),
          if (showPeriod) const PeriodSelector(),
        ],
      ),
    );
  }
}
