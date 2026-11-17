import 'package:harcama_takip/core/l10n/app_locale.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers/admin_providers.dart';
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
      title: 'Çıkış yapılsın mı?'.tr,
      message:
          'Bu cihazdaki oturumunuz kapatılacak. Verileriniz hesabınızda kalır.'
              .tr,
      confirmLabel: 'Çıkış yap'.tr,
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
        ? 'Her gün {0}:{1}'.trArgs([
            profile!.dailyReminderHour.toString().padLeft(2, '0'),
            profile.dailyReminderMinute.toString().padLeft(2, '0'),
          ])
        : 'Kapalı'.tr;
    final themeText = switch (themeMode) {
      ThemeMode.light => 'Açık'.tr,
      ThemeMode.dark => 'Koyu'.tr,
      ThemeMode.system => 'Sistem'.tr,
    };

    return Scaffold(
      appBar: AppBar(title: Text('Ayarlar'.tr)),
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
                            : 'Profilinizi tamamlayın'.tr,
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
                        label: 'E-posta doğrulandı'.tr,
                        color: context.semantic.success,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
          if (ref.watch(isAdminProvider)) ...[
            const SizedBox(height: AppSpacing.md),
            AppCard(
              onTap: () => context.push('/admin'),
              borderColor: scheme.primary.withValues(alpha: 0.5),
              child: Row(
                children: [
                  Icon(
                    Icons.admin_panel_settings_outlined,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Yönetim paneli'.tr,
                          style: context.textStyles.titleSmall,
                        ),
                        Text(
                          'Bildirimler, kategoriler, kullanıcılar ve işlem kayıtları'
                              .tr,
                          style: context.textStyles.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
            ),
          ],
          SectionHeader(title: 'Yönetim'.tr),
          _SettingsGroup(
            children: [
              _SettingsTile(
                icon: Icons.groups_outlined,
                title: 'Takımlar ve aile'.tr,
                subtitle: 'Aktif: {0}'.trArgs([
                  workspace?.label ?? 'Bireysel'.tr,
                ]),
                badge: invites.isNotEmpty ? '${invites.length}' : null,
                onTap: () => context.push('/teams'),
              ),
              _SettingsTile(
                icon: Icons.savings_outlined,
                title: 'Bütçe'.tr,
                subtitle: 'Aylık ve kategori bazlı limitler'.tr,
                onTap: () => context.push('/budgets'),
              ),
              _SettingsTile(
                icon: Icons.credit_card_outlined,
                title: 'Kartlar ve taksitler'.tr,
                onTap: () => context.go('/cards'),
              ),
              _SettingsTile(
                icon: Icons.category_outlined,
                title: 'Kategoriler'.tr,
                onTap: () => context.push('/settings/categories'),
              ),
            ],
          ),
          SectionHeader(title: 'Tercihler'.tr),
          _SettingsGroup(
            children: [
              _SettingsTile(
                icon: Icons.notifications_outlined,
                title: 'Bildirimler'.tr,
                subtitle: reminderText,
                onTap: () => context.push('/settings/notifications'),
              ),
              _SettingsTile(
                icon: Icons.palette_outlined,
                title: 'Görünüm ve dil'.tr,
                subtitle: [
                  'Tema: {0}'.trArgs([themeText]),
                  ?AppLocale.languageNames[AppLocale.code],
                ].join(' · '),
                onTap: () => context.push('/settings/appearance'),
              ),
            ],
          ),
          SectionHeader(title: 'Hakkında'.tr),
          _SettingsGroup(
            children: [
              _SettingsTile(
                icon: Icons.language_rounded,
                title: 'Web sürümü'.tr,
                subtitle: AppConstants.webAppUrl,
                onTap: () => showDialog<void>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text('Web sürümü'.tr),
                    content: SelectableText(
                      'Harcama Takip uygulamasını bilgisayarınızdan veya tabletinizden tarayıcı üzerinden de kullanabilirsiniz.\n\nWeb adresi: {0}'
                          .trArgs([AppConstants.webAppUrl]),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text('Kapat'.tr),
                      ),
                    ],
                  ),
                ),
              ),
              _SettingsTile(
                icon: Icons.privacy_tip_outlined,
                title: 'Gizlilik politikası'.tr,
                subtitle: AppConstants.privacyPolicyUrl,
                onTap: () => showDialog<void>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text('Gizlilik politikası'.tr),
                    content: SelectableText(
                      'Verileriniz yalnızca hesabınızla ve dahil olduğunuz takımlarla paylaşılır; kart numarası, CVV veya banka şifresi saklanmaz. Hesabınızı Profil ekranından istediğiniz zaman tüm verilerinizle birlikte silebilirsiniz.\n\nPolitikanın tam metni: {0}'
                          .trArgs([AppConstants.privacyPolicyUrl]),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text('Kapat'.tr),
                      ),
                    ],
                  ),
                ),
              ),
              _SettingsTile(
                icon: Icons.info_outline_rounded,
                title: 'Uygulama hakkında'.tr,
                onTap: () => showAboutDialog(
                  context: context,
                  applicationName: AppConstants.appName,
                  applicationVersion: '1.1.0+2',
                  applicationIcon: const AppLogo(size: 48),
                  applicationLegalese: AppConstants.appTagline,
                  children: [
                    const SizedBox(height: 16),
                    SelectableText(
                      'Uygulamayı tarayıcınızdan da kullanabilirsiniz:\n{0}'
                          .trArgs([AppConstants.webAppUrl]),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: 'Çıkış yap'.tr,
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
