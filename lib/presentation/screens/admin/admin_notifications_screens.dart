import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers/admin_providers.dart';
import '../../../application/providers/auth_providers.dart';
import '../../../application/providers/repository_providers.dart';
import '../../../core/l10n/app_locale.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_formats.dart';
import '../../../core/utils/validators.dart';
import '../../../domain/entities/admin_models.dart';
import '../../widgets/app_card.dart';
import '../../widgets/common.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/state_views.dart';
import 'admin_home_screen.dart';

/// Türkçe (zorunlu) ve İngilizce (isteğe bağlı) başlık + metin alanları.
class _MessageFields extends StatelessWidget {
  final TextEditingController titleTr;
  final TextEditingController bodyTr;
  final TextEditingController titleEn;
  final TextEditingController bodyEn;

  const _MessageFields({
    required this.titleTr,
    required this.bodyTr,
    required this.titleEn,
    required this.bodyEn,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: 'Türkçe'.tr,
          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
        ),
        TextFormField(
          controller: titleTr,
          maxLength: 80,
          validator: Validators.requiredText('Başlık'.tr, maxLength: 80),
          decoration: InputDecoration(labelText: 'Başlık'.tr),
        ),
        const SizedBox(height: AppSpacing.xs),
        TextFormField(
          controller: bodyTr,
          maxLength: 240,
          minLines: 2,
          maxLines: 4,
          validator: Validators.requiredText('Mesaj'.tr, maxLength: 240),
          decoration: InputDecoration(labelText: 'Mesaj'.tr),
        ),
        SectionHeader(
          title: 'İngilizce (isteğe bağlı)'.tr,
          padding: const EdgeInsets.only(
            top: AppSpacing.sm,
            bottom: AppSpacing.xs,
          ),
        ),
        TextFormField(
          controller: titleEn,
          maxLength: 80,
          decoration: InputDecoration(labelText: 'Başlık (EN)'.tr),
        ),
        const SizedBox(height: AppSpacing.xs),
        TextFormField(
          controller: bodyEn,
          maxLength: 240,
          minLines: 2,
          maxLines: 4,
          decoration: InputDecoration(
            labelText: 'Mesaj (EN)'.tr,
            helperText: 'Boş bırakılırsa dili İngilizce olan kullanıcılara Türkçe metin gider.'
                .tr,
          ),
        ),
      ],
    );
  }
}

/// Alıcı seçimi: tüm kullanıcılar veya seçilenler.
class _TargetPicker extends ConsumerWidget {
  final String target;
  final Set<String> selectedUids;
  final ValueChanged<String> onTargetChanged;
  final ValueChanged<Set<String>> onUsersChanged;

  const _TargetPicker({
    required this.target,
    required this.selectedUids,
    required this.onTargetChanged,
    required this.onUsersChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final users = ref.watch(adminUsersProvider).valueOrNull ?? const [];
    final reachableAll = users.where((u) => u.reachable).length;
    final reachableSelected = users
        .where((u) => selectedUids.contains(u.uid) && u.reachable)
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<String>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(
              value: 'all',
              icon: const Icon(Icons.groups_rounded),
              label: Text('Tüm kullanıcılar'.tr),
            ),
            ButtonSegment(
              value: 'selected',
              icon: const Icon(Icons.person_search_rounded),
              label: Text('Seçilenler'.tr),
            ),
          ],
          selected: {target},
          onSelectionChanged: (s) => onTargetChanged(s.first),
        ),
        const SizedBox(height: AppSpacing.xs),
        if (target == 'all')
          Text(
            '{0} kullanıcıdan {1} tanesi şu an bildirim alabiliyor.'.trArgs([
              users.length,
              reachableAll,
            ]),
            style: context.textStyles.bodySmall?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          )
        else ...[
          OutlinedButton.icon(
            onPressed: () async {
              final result = await showModalBottomSheet<Set<String>>(
                context: context,
                isScrollControlled: true,
                builder: (_) => _UserSelectionSheet(initial: selectedUids),
              );
              if (result != null) onUsersChanged(result);
            },
            icon: const Icon(Icons.checklist_rounded),
            label: Text(
              selectedUids.isEmpty
                  ? 'Kullanıcı seç'.tr
                  : '{0} kullanıcı seçildi'.trArgs([selectedUids.length]),
            ),
          ),
          if (selectedUids.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                'Seçilenlerden {0} tanesi şu an bildirim alabiliyor.'.trArgs([
                  reachableSelected,
                ]),
                style: context.textStyles.bodySmall?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _UserSelectionSheet extends ConsumerStatefulWidget {
  final Set<String> initial;
  const _UserSelectionSheet({required this.initial});

  @override
  ConsumerState<_UserSelectionSheet> createState() =>
      _UserSelectionSheetState();
}

class _UserSelectionSheetState extends ConsumerState<_UserSelectionSheet> {
  late final Set<String> _selected = {...widget.initial};
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(adminUsersProvider);
    final height = MediaQuery.sizeOf(context).height;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.md,
          right: AppSpacing.md,
          bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.md,
        ),
        child: SizedBox(
          height: height * 0.75,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Kullanıcı seç'.tr, style: context.textStyles.titleLarge),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Ad veya e-posta ara'.tr,
                  prefixIcon: const Icon(Icons.search_rounded),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Expanded(
                child: usersAsync.when(
                  loading: () => const LoadingView(),
                  error: (e, _) => ErrorStateView(
                    error: e,
                    compact: true,
                    onRetry: () => ref.invalidate(adminUsersProvider),
                  ),
                  data: (users) {
                    final q = _query.trim().toLowerCase();
                    final list = users
                        .where(
                          (u) =>
                              q.isEmpty ||
                              u.email.toLowerCase().contains(q) ||
                              u.displayName.toLowerCase().contains(q),
                        )
                        .toList();
                    return ListView.builder(
                      itemCount: list.length,
                      itemBuilder: (context, i) {
                        final u = list[i];
                        return CheckboxListTile(
                          value: _selected.contains(u.uid),
                          onChanged: (v) => setState(() {
                            v == true
                                ? _selected.add(u.uid)
                                : _selected.remove(u.uid);
                          }),
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
                          secondary: UserPushStatus(user: u),
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: 'Seçimi onayla ({0})'.trArgs([_selected.length]),
                onPressed: () => Navigator.pop(context, _selected),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AdminSendNotificationScreen extends ConsumerStatefulWidget {
  const AdminSendNotificationScreen({super.key});

  @override
  ConsumerState<AdminSendNotificationScreen> createState() =>
      _AdminSendNotificationScreenState();
}

class _AdminSendNotificationScreenState
    extends ConsumerState<AdminSendNotificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleTr = TextEditingController();
  final _bodyTr = TextEditingController();
  final _titleEn = TextEditingController();
  final _bodyEn = TextEditingController();
  String _target = 'all';
  Set<String> _uids = {};
  bool _sending = false;

  @override
  void dispose() {
    _titleTr.dispose();
    _bodyTr.dispose();
    _titleEn.dispose();
    _bodyEn.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (_target == 'selected' && _uids.isEmpty) {
      context.showInfo('En az bir kullanıcı seçin.'.tr);
      return;
    }
    final admin = ref.read(currentUserProvider);
    if (admin == null) return;
    final ok = await showConfirmDialog(
      context,
      title: 'Bildirim gönderilsin mi?'.tr,
      message: _target == 'all'
          ? '"{0}" başlıklı bildirim tüm kullanıcılara gönderilecek. Bu işlem geri alınamaz.'
                .trArgs([_titleTr.text.trim()])
          : '"{0}" başlıklı bildirim {1} kullanıcıya gönderilecek. Bu işlem geri alınamaz.'
                .trArgs([_titleTr.text.trim(), _uids.length]),
      confirmLabel: 'Gönder'.tr,
    );
    if (!ok || !mounted) return;
    setState(() => _sending = true);
    try {
      await ref
          .read(adminRepositoryProvider)
          .createCampaign(
            admin,
            titleTr: _titleTr.text.trim(),
            bodyTr: _bodyTr.text.trim(),
            titleEn: _titleEn.text.trim(),
            bodyEn: _bodyEn.text.trim(),
            target: _target,
            targetUids: _uids.toList(),
          );
      if (!mounted) return;
      context.showSuccess(
        'Bildirim gönderim kuyruğuna alındı. Durumu geçmişten izleyebilirsiniz.'
            .tr,
      );
      context.pushReplacement('/admin/history');
    } catch (e) {
      if (mounted) {
        context.showError(e);
        setState(() => _sending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: 'Bildirim gönder'.tr,
      body: Form(
        key: _formKey,
        child: PageListView(
          maxWidth: AppSpacing.maxFormWidth,
          children: [
            InlineMessage(
              tone: MessageTone.info,
              message: 'Bildirimler sunucu tarafından gönderilir. Bildirimleri kapatan kullanıcılara ve kayıtlı cihazı olmayanlara ulaşmaz.'
                  .tr,
            ),
            const SizedBox(height: AppSpacing.md),
            _MessageFields(
              titleTr: _titleTr,
              bodyTr: _bodyTr,
              titleEn: _titleEn,
              bodyEn: _bodyEn,
            ),
            SectionHeader(title: 'Alıcılar'.tr),
            _TargetPicker(
              target: _target,
              selectedUids: _uids,
              onTargetChanged: (t) => setState(() => _target = t),
              onUsersChanged: (u) => setState(() => _uids = u),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: 'Bildirimi gönder'.tr,
              icon: Icons.send_rounded,
              onPressed: _send,
              isLoading: _sending,
            ),
          ],
        ),
      ),
    );
  }
}

class AdminDailyReminderScreen extends ConsumerWidget {
  const AdminDailyReminderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configAsync = ref.watch(reminderConfigProvider);
    return AdminScaffold(
      title: 'Günlük hatırlatma'.tr,
      body: configAsync.when(
        skipLoadingOnReload: true,
        skipLoadingOnRefresh: true,
        loading: () => const LoadingView(),
        error: (e, _) => ErrorStateView(
          error: e,
          onRetry: () => ref.invalidate(reminderConfigProvider),
        ),
        // Form bir kez kurulur; kayıt sonrası gelen güncelleme yazılanı ezmez.
        data: (config) =>
            _ReminderForm(key: const ValueKey('reminder'), config: config),
      ),
    );
  }
}

class _ReminderForm extends ConsumerStatefulWidget {
  final ReminderConfig config;
  const _ReminderForm({super.key, required this.config});

  @override
  ConsumerState<_ReminderForm> createState() => _ReminderFormState();
}

class _ReminderFormState extends ConsumerState<_ReminderForm> {
  final _formKey = GlobalKey<FormState>();
  late final _titleTr = TextEditingController(text: widget.config.titleTr);
  late final _bodyTr = TextEditingController(text: widget.config.bodyTr);
  late final _titleEn = TextEditingController(text: widget.config.titleEn);
  late final _bodyEn = TextEditingController(text: widget.config.bodyEn);
  late bool _enabled = widget.config.enabled;
  late TimeOfDay _time = TimeOfDay(
    hour: widget.config.hour,
    minute: widget.config.minute,
  );
  late String _target = widget.config.target;
  late Set<String> _uids = {...widget.config.targetUids};
  bool _saving = false;

  @override
  void dispose() {
    _titleTr.dispose();
    _bodyTr.dispose();
    _titleEn.dispose();
    _bodyEn.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (_target == 'selected' && _uids.isEmpty) {
      context.showInfo('En az bir kullanıcı seçin.'.tr);
      return;
    }
    final admin = ref.read(currentUserProvider);
    if (admin == null) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(adminRepositoryProvider)
          .saveReminderConfig(
            admin,
            ReminderConfig(
              enabled: _enabled,
              hour: _time.hour,
              minute: _time.minute,
              titleTr: _titleTr.text.trim(),
              bodyTr: _bodyTr.text.trim(),
              titleEn: _titleEn.text.trim(),
              bodyEn: _bodyEn.text.trim(),
              target: _target,
              targetUids: _target == 'selected' ? _uids.toList() : const [],
            ),
          );
      if (mounted) context.showSuccess('Hatırlatma ayarları kaydedildi.'.tr);
    } catch (e) {
      if (mounted) context.showError(e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final timeLabel =
        '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}';
    final lastSent = ref
        .watch(reminderConfigProvider)
        .valueOrNull
        ?.lastSentDate;

    return Form(
      key: _formKey,
      child: PageListView(
        maxWidth: AppSpacing.maxFormWidth,
        children: [
          AppCard(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xxs,
            ),
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _enabled,
              onChanged: (v) => setState(() => _enabled = v),
              title: Text('Günlük hatırlatma bildirimi'.tr),
              subtitle: Text(
                _enabled
                    ? 'Her gün {0} saatinde gönderilir.'.trArgs([timeLabel])
                    : 'Kapalı: otomatik bildirim gönderilmez.'.tr,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            padding: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.schedule_rounded),
              title: Text('Gönderim saati'.tr),
              subtitle: Text('Türkiye saati (Europe/Istanbul)'.tr),
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
          const SizedBox(height: AppSpacing.xs),
          Text(
            lastSent == null
                ? 'Henüz otomatik gönderim yapılmadı.'.tr
                : 'Son otomatik gönderim: {0}'.trArgs([lastSent]),
            style: context.textStyles.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _MessageFields(
            titleTr: _titleTr,
            bodyTr: _bodyTr,
            titleEn: _titleEn,
            bodyEn: _bodyEn,
          ),
          SectionHeader(title: 'Alıcılar'.tr),
          _TargetPicker(
            target: _target,
            selectedUids: _uids,
            onTargetChanged: (t) => setState(() => _target = t),
            onUsersChanged: (u) => setState(() => _uids = u),
          ),
          const SizedBox(height: AppSpacing.md),
          InlineMessage(
            tone: MessageTone.info,
            message: 'Günde en fazla bir kez gönderilir. Bildirimleri kapatan veya kendi kişisel hatırlatıcısını kullanan kullanıcılara gönderilmez (çift bildirim olmaması için).'
                .tr,
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: 'Ayarları kaydet'.tr,
            icon: Icons.check_rounded,
            onPressed: _save,
            isLoading: _saving,
          ),
        ],
      ),
    );
  }
}

class AdminNotificationHistoryScreen extends ConsumerWidget {
  const AdminNotificationHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final campaignsAsync = ref.watch(campaignsProvider);
    return AdminScaffold(
      title: 'Bildirim geçmişi'.tr,
      body: AsyncValueView<List<NotificationCampaign>>(
        value: campaignsAsync,
        onRetry: () => ref.invalidate(campaignsProvider),
        data: (campaigns) => campaigns.isEmpty
            ? EmptyStateView(
                icon: Icons.history_rounded,
                title: 'Henüz bildirim gönderilmedi'.tr,
                message: 'Gönderdiğiniz bildirimler ve otomatik hatırlatmalar burada listelenir.'
                    .tr,
                actionLabel: 'Bildirim gönder'.tr,
                actionIcon: Icons.campaign_outlined,
                onAction: () => context.pushReplacement('/admin/send'),
              )
            : PageListView(
                children: [
                  for (final c in campaigns) ...[
                    _CampaignCard(campaign: c),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                ],
              ),
      ),
    );
  }
}

class _CampaignCard extends StatelessWidget {
  final NotificationCampaign campaign;
  const _CampaignCard({required this.campaign});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final semantic = context.semantic;
    final c = campaign;
    final (String label, Color color) = switch (c.status) {
      'queued' => ('Kuyrukta'.tr, scheme.onSurfaceVariant),
      'sending' => ('Gönderiliyor'.tr, semantic.info),
      'sent' => ('Gönderildi'.tr, semantic.success),
      'partial' => ('Kısmen gönderildi'.tr, semantic.warning),
      'no_recipients' => ('Alıcı yok'.tr, scheme.onSurfaceVariant),
      _ => ('Başarısız'.tr, scheme.error),
    };
    final muted = context.textStyles.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                c.type == 'daily'
                    ? Icons.alarm_rounded
                    : Icons.campaign_outlined,
                size: 20,
                color: scheme.primary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  c.titleTr,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textStyles.titleSmall,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Pill(label: label, color: color),
            ],
          ),
          const SizedBox(height: 4),
          Text(c.bodyTr, maxLines: 3, overflow: TextOverflow.ellipsis),
          const SizedBox(height: AppSpacing.xs),
          Text(
            [
              DateFormats.dayTime(c.createdAt),
              c.type == 'daily' ? 'Otomatik hatırlatma'.tr : c.createdByEmail,
              c.target == 'all'
                  ? 'Tüm kullanıcılar'.tr
                  : '{0} seçili kullanıcı'.trArgs([c.targetUids.length]),
            ].join(' · '),
            style: muted,
          ),
          if (c.isFinished && c.status != 'failed') ...[
            const SizedBox(height: 4),
            Text(
              '{0} kullanıcı · {1} cihaz · {2} başarılı · {3} başarısız · {4} bildirimi kapalı'
                  .trArgs([
                    c.recipientCount,
                    c.tokenCount,
                    c.successCount,
                    c.failureCount,
                    c.optedOutCount,
                  ]),
              style: muted,
            ),
          ],
          if (c.status == 'queued')
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Sunucu işleyene kadar kuyrukta bekler. Uzun süre bu durumda kalırsa Cloud Functions yayınlanmamış olabilir.'
                    .tr,
                style: muted,
              ),
            ),
          if (c.error != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Hata: {0}'.trArgs([c.error]),
                style: context.textStyles.bodySmall?.copyWith(
                  color: scheme.error,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
