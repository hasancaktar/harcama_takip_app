import 'package:harcama_takip/core/l10n/app_locale.dart';

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers/admin_providers.dart';
import '../../../application/providers/auth_providers.dart';
import '../../../application/providers/installment_providers.dart';
import '../../../application/providers/repository_providers.dart';
import '../../../application/providers/settings_providers.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/user_profile.dart';

class _Destination {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  const _Destination(this.label, this.icon, this.selectedIcon);
}

List<_Destination> get _destinations => [
  _Destination(
    'Özet'.tr,
    Icons.space_dashboard_outlined,
    Icons.space_dashboard_rounded,
  ),
  _Destination(
    'Harcamalar'.tr,
    Icons.receipt_long_outlined,
    Icons.receipt_long_rounded,
  ),
  _Destination(
    'Kartlar'.tr,
    Icons.credit_card_outlined,
    Icons.credit_card_rounded,
  ),
  _Destination('Raporlar'.tr, Icons.insights_outlined, Icons.insights_rounded),
  _Destination('Ayarlar'.tr, Icons.settings_outlined, Icons.settings_rounded),
];

/// Ana iskelet: telefonda alt gezinme çubuğu, tablet/masaüstünde yan gezinme rayı.
/// Ayrıca oturum başında bir kez çalışması gereken arka plan işlerini başlatır.
class AppShellScreen extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;

  const AppShellScreen({super.key, required this.navigationShell});

  @override
  ConsumerState<AppShellScreen> createState() => _AppShellScreenState();
}

class _AppShellScreenState extends ConsumerState<AppShellScreen> {
  StreamSubscription<String>? _notificationTapSub;
  ProviderSubscription<AsyncValue<UserProfile?>>? _profileSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    final user = ref.read(currentUserProvider);
    if (user == null || !user.emailVerified) return;

    // 1) Profil yoksa oluştur (kayıt sırasında yazılamamış olabilir).
    try {
      await ref
          .read(userRepositoryProvider)
          .ensureProfile(
            uid: user.uid,
            email: user.email,
            displayName: user.displayName,
          );
    } catch (e) {
      debugPrint('[Bootstrap] Profil kontrolü başarısız: $e');
    }

    // 2) Vadesi gelen taksitleri işle (oturum başına bir kez).
    ref.read(installmentSyncProvider);

    // 3) Takım bildirimleri için cihaz anahtarını kaydet.
    unawaited(ref.read(pushTokenServiceProvider).register(user.uid));

    // Sunucu bildirimleri kullanıcının dilinde gitsin diye dili profile yaz.
    unawaited(
      ref
          .read(userRepositoryProvider)
          .setLanguage(user.uid, AppLocale.code)
          .catchError((_) {}),
    );

    // Bildirim iznini ilk girişte bir kez iste (Android 13+ için gerekli).
    final prefs = ref.read(sharedPreferencesProvider);
    if (ref.read(notificationServiceProvider).isSupported &&
        prefs != null &&
        prefs.getBool('notification_permission_asked') != true) {
      await prefs.setBool('notification_permission_asked', true);
      unawaited(ref.read(notificationServiceProvider).requestPermission());
    }

    // 4) Hatırlatıcıları profil ayarlarıyla senkron tut ve bildirime dokunmayı yönlendir.
    final notifications = ref.read(notificationServiceProvider);
    if (notifications.isSupported) {
      _profileSub = ref.listenManual<AsyncValue<UserProfile?>>(
        userProfileProvider,
        (prev, next) => _syncReminders(prev?.valueOrNull, next.valueOrNull),
        fireImmediately: true,
      );
      _notificationTapSub = notifications.onNotificationTap.listen(_openRoute);
      // Uygulama bir bildirime dokunularak açıldıysa ilgili sayfayı aç: önce
      // yerel hatırlatıcı, yoksa sunucudan gelen (FCM) bildirim.
      final launchRoute =
          await notifications.launchRoute() ??
          await ref.read(pushTokenServiceProvider).initialRoute();
      if (launchRoute != null) _openRoute(launchRoute);
    }
  }

  Future<void> _syncReminders(UserProfile? prev, UserProfile? next) async {
    if (next == null) return;
    final changed =
        prev == null ||
        prev.dailyReminderEnabled != next.dailyReminderEnabled ||
        prev.dailyReminderHour != next.dailyReminderHour ||
        prev.dailyReminderMinute != next.dailyReminderMinute ||
        !listEquals(prev.dailyReminderDays, next.dailyReminderDays);
    if (!changed) return;
    final service = ref.read(notificationServiceProvider);
    try {
      if (next.dailyReminderEnabled) {
        await service.scheduleDailyReminder(
          hour: next.dailyReminderHour,
          minute: next.dailyReminderMinute,
          days: next.dailyReminderDays,
        );
      } else {
        await service.cancelReminders();
      }
    } catch (e) {
      debugPrint('[Bootstrap] Hatırlatıcı senkronizasyonu başarısız: $e');
    }
  }

  void _openRoute(String route) {
    if (!mounted) return;
    context.push(route);
  }

  @override
  void dispose() {
    _notificationTapSub?.cancel();
    _profileSub?.close();
    super.dispose();
  }

  void _onSelect(int index) {
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final shell = widget.navigationShell;
    final isOnline = ref.watch(isOnlineProvider).valueOrNull ?? true;
    // Yönetici kategorileri değiştirdiğinde sekmeler yeni listeyle yeniden çizilir.
    final categories = ref.watch(categoriesProvider).valueOrNull;
    final categoryKey = ValueKey(
      categories
          ?.map(
            (c) =>
                '${c.id}${c.nameTr}${c.nameEn}${c.iconKey}${c.colorHex}${c.isActive}${c.isDeleted}${c.order}',
          )
          .join('|'),
    );

    final body = Column(
      children: [
        if (!isOnline) const _OfflineBanner(),
        Expanded(
          child: KeyedSubtree(key: categoryKey, child: shell),
        ),
      ],
    );

    if (width < AppSpacing.compactBreakpoint) {
      return Scaffold(
        body: body,
        bottomNavigationBar: NavigationBar(
          selectedIndex: shell.currentIndex,
          onDestinationSelected: _onSelect,
          destinations: [
            for (final d in _destinations)
              NavigationDestination(
                icon: Icon(d.icon),
                selectedIcon: Icon(d.selectedIcon),
                label: d.label,
              ),
          ],
        ),
      );
    }

    final extended = width >= AppSpacing.expandedBreakpoint;
    final scheme = context.colors;
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: shell.currentIndex,
            onDestinationSelected: _onSelect,
            extended: extended,
            minExtendedWidth: 220,
            labelType: extended
                ? NavigationRailLabelType.none
                : NavigationRailLabelType.all,
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: extended
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.account_balance_wallet_rounded,
                          color: scheme.primary,
                          size: 28,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          AppConstants.appName,
                          style: context.textStyles.titleMedium,
                        ),
                      ],
                    )
                  : Icon(
                      Icons.account_balance_wallet_rounded,
                      color: scheme.primary,
                      size: 28,
                    ),
            ),
            destinations: [
              for (final d in _destinations)
                NavigationRailDestination(
                  icon: Icon(d.icon),
                  selectedIcon: Icon(d.selectedIcon),
                  label: Text(d.label),
                ),
            ],
          ),
          VerticalDivider(width: 1, color: scheme.outlineVariant),
          Expanded(child: body),
        ],
      ),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    final semantic = context.semantic;
    return Material(
      color: semantic.warningContainer,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          child: Row(
            children: [
              Icon(Icons.wifi_off_rounded, size: 18, color: semantic.warning),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  'Çevrimdışısınız. Değişiklikler bağlantı geldiğinde senkronize edilecek.'
                      .tr,
                  style: context.textStyles.bodySmall?.copyWith(
                    color: context.colors.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
