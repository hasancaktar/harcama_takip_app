import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers/admin_providers.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/l10n/app_locale.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_formats.dart';
import '../../../domain/entities/admin_models.dart';
import '../../widgets/app_card.dart';
import '../../widgets/common.dart';
import '../../widgets/state_views.dart';
import 'admin_content_screens.dart';

/// Yönetim ekranlarının ortak iskeleti. Yönetici olmayan biri bu sayfaya bir
/// şekilde ulaşsa bile içerik gösterilmez (veriyi zaten Firestore kuralları vermez).
class AdminScaffold extends ConsumerWidget {
  final String title;
  final Widget body;
  final Widget? floatingActionButton;
  final List<Widget>? actions;

  const AdminScaffold({
    super.key,
    required this.title,
    required this.body,
    this.floatingActionButton,
    this.actions,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(isAdminProvider);
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: actions),
      floatingActionButton: isAdmin ? floatingActionButton : null,
      body: isAdmin
          ? body
          : EmptyStateView(
              icon: Icons.lock_outline_rounded,
              title: 'Bu sayfaya erişim yetkiniz yok'.tr,
              message: 'Yönetim paneli yalnızca yönetici hesabına açıktır.'.tr,
            ),
    );
  }
}

class AdminHomeScreen extends ConsumerWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(adminUsersProvider);
    final campaigns = ref.watch(campaignsProvider).valueOrNull ?? const [];
    final users = usersAsync.valueOrNull ?? const <AdminUserSummary>[];
    final reachable = users.where((u) => u.reachable).length;
    final unreadFeedback = (ref.watch(adminFeedbackProvider).valueOrNull ?? [])
        .where((f) => f.isNew)
        .length;

    final sections = [
      _Section(
        Icons.campaign_outlined,
        'Bildirim gönder'.tr,
        'Tüm kullanıcılara veya seçtiklerinize push bildirimi'.tr,
        '/admin/send',
      ),
      _Section(
        Icons.alarm_rounded,
        'Günlük hatırlatma'.tr,
        'Otomatik hatırlatmanın saati, metni ve alıcıları'.tr,
        '/admin/daily-reminder',
      ),
      _Section(
        Icons.history_rounded,
        'Bildirim geçmişi'.tr,
        'Gönderimler ve teslim durumları'.tr,
        '/admin/history',
      ),
      _Section(
        Icons.category_outlined,
        'Kategori yönetimi'.tr,
        'Ekle, düzenle, sırala, pasifleştir'.tr,
        '/admin/categories',
      ),
      _Section(
        Icons.people_outline_rounded,
        'Kullanıcılar'.tr,
        'Kayıtlı hesaplar, bildirim durumu, pasife alma'.tr,
        '/admin/users',
      ),
      _Section(
        Icons.lightbulb_outline_rounded,
        'Öneriler'.tr,
        unreadFeedback > 0
            ? '{0} okunmamış öneri'.trArgs([unreadFeedback])
            : 'Kullanıcıların gönderdiği öneriler'.tr,
        '/admin/feedback',
      ),
      _Section(
        Icons.auto_awesome_outlined,
        'Sürüm notları'.tr,
        'Güncellemeden sonra gösterilen "Yenilikler"'.tr,
        '/admin/release-notes',
      ),
      _Section(
        Icons.fact_check_outlined,
        'İşlem kayıtları'.tr,
        'Yönetici işlemlerinin değiştirilemez günlüğü'.tr,
        '/admin/logs',
      ),
    ];

    return AdminScaffold(
      title: 'Yönetim paneli'.tr,
      body: PageListView(
        maxWidth: 960,
        children: [
          InlineMessage(
            tone: MessageTone.info,
            message: 'Bu panel yalnızca {0} hesabına açıktır. Tüm işlemler kayıt altına alınır.'
                .trArgs([AppConstants.adminEmail]),
          ),
          const SizedBox(height: AppSpacing.md),
          LayoutBuilder(
            builder: (context, c) {
              final stats = [
                (
                  'Kullanıcı'.tr,
                  usersAsync.isLoading ? '…' : '${users.length}',
                ),
                (
                  'Bildirim alabilen'.tr,
                  usersAsync.isLoading ? '…' : '$reachable',
                ),
                ('Gönderim'.tr, '${campaigns.length}'),
              ];
              Widget tile((String, String) s) => AppCard(
                padding: const EdgeInsets.all(AppSpacing.sm + 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      s.$1,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.textStyles.labelMedium?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                    Text(s.$2, style: context.textStyles.titleLarge),
                  ],
                ),
              );
              // Çok dar ekranda alt alta; diğer tüm boyutlarda yan yana üç kutu.
              if (c.maxWidth < 300) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final s in stats) ...[
                      tile(s),
                      if (s != stats.last)
                        const SizedBox(height: AppSpacing.sm),
                    ],
                  ],
                );
              }
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final s in stats) ...[
                      Expanded(child: tile(s)),
                      if (s != stats.last) const SizedBox(width: AppSpacing.sm),
                    ],
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: AppSpacing.md),
          LayoutBuilder(
            builder: (context, c) {
              final cols = c.maxWidth >= 840 ? 3 : (c.maxWidth >= 520 ? 2 : 1);
              final w = (c.maxWidth - (cols - 1) * AppSpacing.sm) / cols;
              return Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final s in sections)
                    SizedBox(
                      width: w,
                      child: AppCard(
                        onTap: () => context.push(s.route),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: context.colors.primaryContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                s.icon,
                                color: context.colors.onPrimaryContainer,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    s.title,
                                    style: context.textStyles.titleSmall,
                                  ),
                                  Text(
                                    s.subtitle,
                                    style: context.textStyles.bodySmall
                                        ?.copyWith(
                                          color:
                                              context.colors.onSurfaceVariant,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Section {
  final IconData icon;
  final String title;
  final String subtitle;
  final String route;
  const _Section(this.icon, this.title, this.subtitle, this.route);
}

class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(adminUsersProvider);
    return AdminScaffold(
      title: 'Kullanıcılar'.tr,
      actions: [
        IconButton(
          tooltip: 'Yenile'.tr,
          icon: const Icon(Icons.refresh_rounded),
          onPressed: () => ref.invalidate(adminUsersProvider),
        ),
      ],
      body: AsyncValueView<List<AdminUserSummary>>(
        value: usersAsync,
        onRetry: () => ref.invalidate(adminUsersProvider),
        data: (users) {
          final q = _query.trim().toLowerCase();
          final filtered = q.isEmpty
              ? users
              : users
                    .where(
                      (u) =>
                          u.email.toLowerCase().contains(q) ||
                          u.displayName.toLowerCase().contains(q),
                    )
                    .toList();
          return PageListView(
            children: [
              TextField(
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Ad veya e-posta ara'.tr,
                  prefixIcon: const Icon(Icons.search_rounded),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '{0} kullanıcı'.trArgs([filtered.length]),
                style: context.textStyles.bodySmall?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              if (filtered.isEmpty)
                AppCard(
                  child: EmptyStateView(
                    compact: true,
                    icon: Icons.person_search_outlined,
                    title: 'Kullanıcı bulunamadı'.tr,
                    message: 'Aramayı değiştirip tekrar deneyin.'.tr,
                  ),
                )
              else
                AppCard(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
                  child: Column(
                    children: [
                      for (final u in filtered)
                        ListTile(
                          leading: UserAvatar(name: u.label),
                          title: Text(
                            u.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            u.email,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (u.disabled)
                                Pill(
                                  label: 'Pasif'.tr,
                                  color: context.colors.error,
                                )
                              else
                                UserPushStatus(user: u),
                              UserActiveToggle(user: u),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Kullanıcının push bildirimi alıp alamayacağını gösteren etiket.
class UserPushStatus extends StatelessWidget {
  final AdminUserSummary user;
  const UserPushStatus({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    if (!user.pushEnabled) {
      return Pill(
        label: 'Bildirim kapalı'.tr,
        icon: Icons.notifications_off_outlined,
      );
    }
    if (!user.hasPushToken) {
      return Pill(label: 'Cihaz yok'.tr, icon: Icons.phonelink_off_rounded);
    }
    return Pill(
      label: 'Alabilir'.tr,
      icon: Icons.notifications_active_outlined,
      color: context.semantic.success,
    );
  }
}

class AdminLogsScreen extends ConsumerWidget {
  const AdminLogsScreen({super.key});

  static String actionLabel(String action) => switch (action) {
    'category.create' => 'Kategori eklendi'.tr,
    'category.update' => 'Kategori güncellendi'.tr,
    'category.delete' => 'Kategori silindi'.tr,
    'category.restore' => 'Kategori geri yüklendi'.tr,
    'category.reorder' => 'Kategori sırası değişti'.tr,
    'category.import_defaults' => 'Varsayılan kategoriler içe aktarıldı'.tr,
    'reminder.update' => 'Günlük hatırlatma ayarı değişti'.tr,
    'notification.send' => 'Bildirim gönderildi'.tr,
    _ => action,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(adminLogsProvider);
    return AdminScaffold(
      title: 'İşlem kayıtları'.tr,
      body: AsyncValueView<List<AdminLogEntry>>(
        value: logsAsync,
        onRetry: () => ref.invalidate(adminLogsProvider),
        data: (logs) => logs.isEmpty
            ? EmptyStateView(
                icon: Icons.fact_check_outlined,
                title: 'Henüz kayıt yok'.tr,
                message:
                    'Yönetim panelinde yaptığınız her işlem burada listelenir.'
                        .tr,
              )
            : PageListView(
                children: [
                  AppCard(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.xxs,
                    ),
                    child: Column(
                      children: [
                        for (final log in logs)
                          ListTile(
                            leading: const Icon(Icons.history_edu_rounded),
                            title: Text(actionLabel(log.action)),
                            subtitle: Text(
                              '${log.summary}\n${DateFormats.dayTime(log.createdAt)} · ${log.adminEmail}',
                            ),
                            isThreeLine: true,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
