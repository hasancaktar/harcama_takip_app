import 'package:harcama_takip/core/l10n/app_locale.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

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
import 'license_screen.dart';

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
    try {
      final currentEmail = ref.read(currentUserProvider)?.email;
      if (currentEmail != null && currentEmail.isNotEmpty) {
        await ref
            .read(sharedPreferencesProvider)
            ?.setString('last_login_email', currentEmail);
      }
      await ref.read(accountServiceProvider).signOut();
      if (context.mounted) {
        context.go('/login');
      }
    } catch (e) {
      debugPrint('[SettingsScreen] Çıkış hatası: $e');
      if (context.mounted) {
        context.showError(e);
      }
    }
  }

  Future<void> _openUrl(BuildContext context, String urlString) async {
    try {
      final uri = Uri.parse(urlString);
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && context.mounted) {
        context.showError('Bağlantı açılamadı.'.tr);
      }
    } catch (_) {
      if (context.mounted) {
        context.showError('Bağlantı açılamadı.'.tr);
      }
    }
  }

  Future<void> _copyUrl(BuildContext context, String urlString) async {
    await Clipboard.setData(ClipboardData(text: urlString));
    if (context.mounted) {
      context.showSuccess('Bağlantı kopyalandı.'.tr);
    }
  }

  Future<void> _copyEmail(BuildContext context) async {
    await Clipboard.setData(
      const ClipboardData(text: AppConstants.contactEmail),
    );
    if (context.mounted) {
      context.showSuccess('E-posta adresi kopyalandı.'.tr);
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
                icon: Icons.account_balance_wallet_outlined,
                title: 'Bütçe'.tr,
                subtitle: 'Aylık ve kategori bazlı limitler'.tr,
                onTap: () => context.push('/budgets'),
              ),
              _SettingsTile(
                icon: Icons.credit_card_outlined,
                title: 'Kartlar ve ödemeler'.tr,
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
                trailing: const Icon(Icons.open_in_new_rounded, size: 20),
                onTap: () => _openUrl(context, AppConstants.webAppUrl),
                onLongPress: () => _copyUrl(context, AppConstants.webAppUrl),
              ),
              _SettingsTile(
                icon: Icons.privacy_tip_outlined,
                title: 'Gizlilik politikası'.tr,
                subtitle: AppConstants.privacyPolicyUrl,
                trailing: const Icon(Icons.open_in_new_rounded, size: 20),
                onTap: () => _openUrl(context, AppConstants.privacyPolicyUrl),
                onLongPress: () =>
                    _copyUrl(context, AppConstants.privacyPolicyUrl),
              ),
              _SettingsTile(
                icon: Icons.mail_outline_rounded,
                title: 'İletişim'.tr,
                subtitle: AppConstants.contactEmail,
                trailing: IconButton(
                  tooltip: 'E-posta gönder'.tr,
                  icon: const Icon(Icons.send_rounded, size: 20),
                  onPressed: () => _openUrl(
                    context,
                    'mailto:${AppConstants.contactEmail}?subject=Harcama%20Takip',
                  ),
                ),
                onTap: () => _copyEmail(context),
              ),
              _SettingsTile(
                icon: Icons.info_outline_rounded,
                title: 'Uygulama hakkında'.tr,
                onTap: () => showDialog<void>(
                  context: context,
                  builder: (ctx) {
                    final scheme = ctx.colors;
                    return AlertDialog(
                      title: Row(
                        children: [
                          const AppLogo(size: 32),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(child: Text(AppConstants.appName)),
                        ],
                      ),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppConstants.appVersionLabel,
                            style: ctx.textStyles.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(AppConstants.appTagline),
                          const SizedBox(height: AppSpacing.md),
                          InkWell(
                            onTap: () =>
                                _openUrl(context, AppConstants.webAppUrl),
                            onLongPress: () =>
                                _copyUrl(context, AppConstants.webAppUrl),
                            child: SelectableText(
                              'Uygulamayı tarayıcınızdan da kullanabilirsiniz:\n{0}'
                                  .trArgs([AppConstants.webAppUrl]),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          InkWell(
                            onTap: () => _copyEmail(context),
                            child: Text(
                              'İletişim: {0}'.trArgs([
                                AppConstants.contactEmail,
                              ]),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Powered by Faydalab', // l10n-ignore
                              style: ctx.textStyles.labelMedium?.copyWith(
                                color: scheme.onPrimaryContainer,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AppLicensePage(),
                              ),
                            );
                          },
                          child: Text('Lisansları görüntüle'.tr),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text('Kapat'.tr),
                        ),
                      ],
                    );
                  },
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
  final Widget? trailing;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.badge,
    this.trailing,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: subtitle != null
          ? Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis)
          : null,
      trailing:
          trailing ??
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (badge != null) Badge(label: Text(badge!)),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }
}
