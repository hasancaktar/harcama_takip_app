import 'package:harcama_takip/core/l10n/app_locale.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers/auth_providers.dart';
import '../../../application/providers/repository_providers.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/user_profile.dart';
import '../../widgets/app_card.dart';
import '../../widgets/common.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/state_views.dart';

class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);
    return Scaffold(
      appBar: AppBar(title: Text('Bildirimler'.tr)),
      body: AsyncValueView<UserProfile?>(
        value: profileAsync,
        onRetry: () => ref.invalidate(userProfileProvider),
        data: (profile) =>
            _ReminderForm(key: ValueKey(profile?.updatedAt), profile: profile),
      ),
    );
  }
}

class _ReminderForm extends ConsumerStatefulWidget {
  final UserProfile? profile;
  const _ReminderForm({super.key, required this.profile});

  @override
  ConsumerState<_ReminderForm> createState() => _ReminderFormState();
}

class _ReminderFormState extends ConsumerState<_ReminderForm> {
  static List<String> get _dayNames => [
    'Pzt'.tr,
    'Sal'.tr,
    'Çar'.tr,
    'Per'.tr,
    'Cum'.tr,
    'Cmt'.tr,
    'Paz'.tr,
  ];
  static List<String> get _dayFullNames => [
    'Pazartesi'.tr,
    'Salı'.tr,
    'Çarşamba'.tr,
    'Perşembe'.tr,
    'Cuma'.tr,
    'Cumartesi'.tr,
    'Pazar'.tr,
  ];

  late bool _enabled = widget.profile?.dailyReminderEnabled ?? false;
  late TimeOfDay _time = TimeOfDay(
    hour: widget.profile?.dailyReminderHour ?? 21,
    minute: widget.profile?.dailyReminderMinute ?? 0,
  );
  late final Set<int> _days = {
    ...(widget.profile?.dailyReminderDays ?? const [1, 2, 3, 4, 5, 6, 7]),
  };
  late bool _push = widget.profile?.pushEnabled ?? true;
  bool _saving = false;

  Future<void> _save() async {
    final uid = ref.read(currentUserIdProvider);
    if (uid == null) return;
    final service = ref.read(notificationServiceProvider);
    setState(() => _saving = true);
    try {
      if ((_enabled || _push) && service.isSupported) {
        final granted = await service.requestPermission();
        if (!granted && mounted) {
          context.showInfo(
            'Bildirim izni verilmedi. Hatırlatıcılar için cihaz ayarlarından izin verin.'
                .tr,
          );
        }
      }
      await ref.read(userRepositoryProvider).setPushEnabled(uid, _push);
      final days = _days.toList()..sort();
      // Profil güncellenince AppShell hatırlatıcıları otomatik olarak yeniden planlar.
      await ref
          .read(userRepositoryProvider)
          .updateReminderSettings(
            uid: uid,
            enabled: _enabled,
            hour: _time.hour,
            minute: _time.minute,
            days: days,
          );
      if (mounted) context.showSuccess('Bildirim tercihleri kaydedildi.'.tr);
    } catch (e) {
      if (mounted) context.showError(e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final supported = ref.watch(notificationServiceProvider).isSupported;
    final scheme = context.colors;
    final timeLabel =
        '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}';

    return PageListView(
      maxWidth: AppSpacing.maxFormWidth,
      children: [
        if (!supported) ...[
          InlineMessage(
            tone: MessageTone.info,
            message: 'Zamanlanmış hatırlatıcılar yalnızca mobil uygulamada çalışır. Buradaki ayar hesabınıza kaydedilir ve telefonunuzda uygulanır.'
                .tr,
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        AppCard(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xxs,
          ),
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _push,
            onChanged: (v) => setState(() => _push = v),
            title: Text('Duyuru ve hatırlatma bildirimleri'.tr),
            subtitle: Text(
              'Uygulama duyurularını ve otomatik günlük hatırlatmayı bu hesaba gönder. Kapatırsanız sunucudan bildirim almazsınız.'
                  .tr,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xxs,
          ),
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _enabled,
            onChanged: (v) => setState(() => _enabled = v),
            title: Text('Kişisel günlük hatırlatıcı'.tr),
            subtitle: Text(
              'Günün harcamalarını girmeyi unutmamanız için bildirim gönderir.'
                  .tr,
            ),
          ),
        ),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 200),
          crossFadeState: _enabled
              ? CrossFadeState.showFirst
              : CrossFadeState.showSecond,
          secondChild: const SizedBox(width: double.infinity),
          firstChild: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionHeader(title: 'Saat'.tr),
              AppCard(
                padding: EdgeInsets.zero,
                child: ListTile(
                  leading: const Icon(Icons.schedule_rounded),
                  title: Text('Bildirim saati'.tr),
                  trailing: Text(
                    timeLabel,
                    style: context.textStyles.titleLarge?.copyWith(
                      color: scheme.primary,
                    ),
                  ),
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: _time,
                    );
                    if (picked != null) setState(() => _time = picked);
                  },
                ),
              ),
              SectionHeader(title: 'Günler'.tr),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  for (var i = 0; i < 7; i++)
                    Semantics(
                      label: _dayFullNames[i],
                      child: FilterChip(
                        label: Text(_dayNames[i]),
                        selected: _days.contains(i + 1),
                        onSelected: (s) => setState(() {
                          if (s) {
                            _days.add(i + 1);
                          } else if (_days.length > 1) {
                            _days.remove(i + 1);
                          }
                        }),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'En az bir gün seçili olmalıdır.'.tr,
                style: context.textStyles.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: 'Kaydet'.tr,
          icon: Icons.check_rounded,
          onPressed: _save,
          isLoading: _saving,
        ),
      ],
    );
  }
}
