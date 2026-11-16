import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers/auth_providers.dart';
import '../../../application/providers/settings_providers.dart';
import '../../../application/providers/team_providers.dart';
import '../../../application/services/account_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../widgets/app_card.dart';
import '../../widgets/common.dart';
import '../../widgets/dialogs.dart';
import '../splash/splash_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Çıkış yapılsın mı?',
      message:
          'Bu cihazdaki oturumunuz kapatılacak. Verileriniz hesabınızda kalır.',
      confirmLabel: 'Çıkış yap',
    );
    if (!ok || !context.mounted) return;
    final router = GoRouter.of(context);
    try {
      await ref.read(accountServiceProvider).signOut();
      // Bilinçli çıkışta önceki sayfaya dönüş adresi taşınmaz.
      router.go('/login');
    } catch (e) {
      if (context.mounted) context.showError(e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final profile = ref.watch(userProfileProvider).valueOrNull;
    final themeMode = ref.watch(themeModeProvider);
    final workspace = ref.watch(workspaceProvider).valueOrNull;
    final invites = ref.watch(myPendingInvitesProvider).valueOrNull ?? const [];
    final scheme = context.colors;

    final reminderText = profile?.dailyReminderEnabled == true
        ? 'Her gün ${profile!.dailyReminderHour.toString().padLeft(2, '0')}:${profile.dailyReminderMinute.toString().padLeft(2, '0')}'
        : 'Kapalı';
    final themeText = switch (themeMode) {
      ThemeMode.light => 'Açık',
      ThemeMode.dark => 'Koyu',
      ThemeMode.system => 'Sistem',
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Ayarlar')),
      body: PageListView(
        children: [
          AppCard(
            onTap: () => context.push('/settings/profile'),
            child: Row(
              children: [
                UserAvatar(
                  name: user?.displayName.isNotEmpty == true
                      ? user!.displayName
                      : (user?.email ?? '?'),
                  radius: 26,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.displayName.isNotEmpty == true
                            ? user!.displayName
                            : 'Profilinizi tamamlayın',
                        style: context.textStyles.titleMedium,
                      ),
                      Text(
                        user?.email ?? '',
                        style: context.textStyles.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Pill(
                        icon: Icons.verified_rounded,
                        label: 'E-posta doğrulandı',
                        color: context.semantic.success,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
          const SectionHeader(title: 'Yönetim'),
          _SettingsGroup(
            children: [
              _SettingsTile(
                icon: Icons.groups_outlined,
                title: 'Takımlar ve aile',
                subtitle: 'Aktif: ${workspace?.label ?? 'Bireysel'}',
                badge: invites.isNotEmpty ? '${invites.length}' : null,
                onTap: () => context.push('/teams'),
              ),
              _SettingsTile(
                icon: Icons.savings_outlined,
                title: 'Bütçe',
                subtitle: 'Aylık ve kategori bazlı limitler',
                onTap: () => context.push('/budgets'),
              ),
              _SettingsTile(
                icon: Icons.credit_card_outlined,
                title: 'Kartlar ve taksitler',
                onTap: () => context.go('/cards'),
              ),
              _SettingsTile(
                icon: Icons.category_outlined,
                title: 'Kategoriler',
                onTap: () => context.push('/settings/categories'),
              ),
            ],
          ),
          const SectionHeader(title: 'Tercihler'),
          _SettingsGroup(
            children: [
              _SettingsTile(
                icon: Icons.notifications_outlined,
                title: 'Hatırlatıcılar',
                subtitle: reminderText,
                onTap: () => context.push('/settings/notifications'),
              ),
              _SettingsTile(
                icon: Icons.palette_outlined,
                title: 'Görünüm',
                subtitle: 'Tema: $themeText',
                onTap: () => context.push('/settings/appearance'),
              ),
            ],
          ),
          const SectionHeader(title: 'Hakkında'),
          _SettingsGroup(
            children: [
              _SettingsTile(
                icon: Icons.privacy_tip_outlined,
                title: 'Gizlilik politikası',
                subtitle: AppConstants.privacyPolicyUrl,
                onTap: () => showDialog<void>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Gizlilik politikası'),
                    content: const SelectableText(
                      'Verileriniz yalnızca hesabınızla ve dahil olduğunuz takımlarla paylaşılır; '
                      'kart numarası, CVV veya banka şifresi saklanmaz. Hesabınızı Profil ekranından '
                      'istediğiniz zaman tüm verilerinizle birlikte silebilirsiniz.\n\n'
                      'Politikanın tam metni: ${AppConstants.privacyPolicyUrl}',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Kapat'),
                      ),
                    ],
                  ),
                ),
              ),
              _SettingsTile(
                icon: Icons.info_outline_rounded,
                title: 'Uygulama hakkında',
                onTap: () => showAboutDialog(
                  context: context,
                  applicationName: AppConstants.appName,
                  applicationVersion: '1.0.0',
                  applicationIcon: const AppLogo(size: 48),
                  applicationLegalese: AppConstants.appTagline,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: 'Çıkış yap',
            icon: Icons.logout_rounded,
            outlined: true,
            destructive: true,
            onPressed: () => _signOut(context, ref),
          ),
        ],
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  final List<Widget> children;
  const _SettingsGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(indent: 56),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? badge;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: subtitle != null
          ? Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis)
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (badge != null) Badge(label: Text(badge!)),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
      onTap: onTap,
    );
  }
}
