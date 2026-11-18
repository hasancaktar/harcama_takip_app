import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers/admin_providers.dart';
import '../../../application/providers/auth_providers.dart';
import '../../../application/providers/repository_providers.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/l10n/app_locale.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_formats.dart';
import '../../../domain/entities/admin_models.dart';
import '../../widgets/app_card.dart';
import '../../widgets/common.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/release_notes_dialog.dart';
import '../../widgets/state_views.dart';
import 'admin_home_screen.dart';

/// Kullanıcıların gönderdiği öneriler. Açılan öneri "okundu" olarak işaretlenir.
class AdminFeedbackScreen extends ConsumerWidget {
  const AdminFeedbackScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminFeedbackProvider);
    return AdminScaffold(
      title: 'Öneriler'.tr,
      body: AsyncValueView<List<FeedbackEntry>>(
        value: async,
        onRetry: () => ref.invalidate(adminFeedbackProvider),
        data: (items) {
          if (items.isEmpty) {
            return EmptyStateView(
              icon: Icons.lightbulb_outline_rounded,
              title: 'Henüz öneri yok'.tr,
              message: 'Kullanıcılar Ayarlar > Öneri gönder bölümünden yazdığında burada görünür.'
                  .tr,
            );
          }
          final unread = items.where((f) => f.isNew).length;
          return PageListView(
            children: [
              Text(
                '{0} öneri · {1} okunmamış'.trArgs([items.length, unread]),
                style: context.textStyles.bodySmall?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              for (final f in items) ...[
                _FeedbackCard(entry: f),
                const SizedBox(height: AppSpacing.sm),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _FeedbackCard extends ConsumerWidget {
  final FeedbackEntry entry;
  const _FeedbackCard({required this.entry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = context.colors;
    return AppCard(
      borderColor: entry.isNew ? scheme.primary.withValues(alpha: 0.5) : null,
      onTap: entry.isNew
          ? () async {
              final admin = ref.read(currentUserProvider);
              if (admin == null) return;
              try {
                await ref
                    .read(adminRepositoryProvider)
                    .markFeedbackRead(admin, entry);
              } catch (e) {
                if (context.mounted) context.showError(e);
              }
            }
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              UserAvatar(name: entry.senderLabel, radius: 16),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.senderLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textStyles.titleSmall,
                    ),
                    Text(
                      '${entry.email} · ${DateFormats.dayTime(entry.createdAt)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textStyles.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (entry.isNew) Pill(label: 'Yeni'.tr, color: scheme.primary),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          SelectableText(entry.message),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${entry.appVersion} · ${entry.platform}',
            style: context.textStyles.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Sürüm notları listesi.
class AdminReleaseNotesScreen extends ConsumerWidget {
  const AdminReleaseNotesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminReleaseNotesProvider);
    return AdminScaffold(
      title: 'Sürüm notları'.tr,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab-release-notes',
        onPressed: () =>
            context.push('/admin/release-notes/${AppConstants.appVersion}'),
        icon: const Icon(Icons.edit_note_rounded),
        label: Text('{0} notlarını yaz'.trArgs([AppConstants.appVersion])),
      ),
      body: AsyncValueView<List<ReleaseNotes>>(
        value: async,
        onRetry: () => ref.invalidate(adminReleaseNotesProvider),
        data: (items) => PageListView(
          children: [
            InlineMessage(
              tone: MessageTone.info,
              message: 'Yayınlanan notlar, uygulamanın o sürümüne güncelleyen kullanıcılara ilk açılışta bir kez gösterilir. Yeni kayıt olanlara gösterilmez.'
                  .tr,
            ),
            const SizedBox(height: AppSpacing.md),
            if (items.isEmpty)
              EmptyStateView(
                compact: true,
                icon: Icons.auto_awesome_outlined,
                title: 'Henüz sürüm notu yok'.tr,
                message: 'Bu sürüm için notları yazıp yayınlayın.'.tr,
              ),
            for (final n in items) ...[
              AppCard(
                onTap: () => context.push('/admin/release-notes/${n.version}'),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(n.version, style: context.textStyles.titleSmall),
                          Text(
                            '{0} yeni · {1} düzeltme · {2} kaldırılan'.trArgs([
                              n.addedTr.length,
                              n.fixedTr.length,
                              n.removedTr.length,
                            ]),
                            style: context.textStyles.bodySmall?.copyWith(
                              color: context.colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Pill(
                      label: n.published ? 'Yayında'.tr : 'Taslak'.tr,
                      color: n.published
                          ? context.colors.primary
                          : context.colors.onSurfaceVariant,
                    ),
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

/// Bir sürümün notlarını yazma / düzenleme. Her satır bir madde olur.
class AdminReleaseNotesEditScreen extends ConsumerWidget {
  final String version;
  const AdminReleaseNotesEditScreen({super.key, required this.version});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminReleaseNotesProvider);
    return AdminScaffold(
      title: 'Sürüm notları · {0}'.trArgs([version]),
      body: AsyncValueView<List<ReleaseNotes>>(
        value: async,
        onRetry: () => ref.invalidate(adminReleaseNotesProvider),
        data: (items) {
          ReleaseNotes? existing;
          for (final n in items) {
            if (n.version == version) existing = n;
          }
          return _ReleaseNotesForm(
            key: ValueKey('$version-${existing != null}'),
            version: version,
            existing: existing,
          );
        },
      ),
    );
  }
}

class _ReleaseNotesForm extends ConsumerStatefulWidget {
  final String version;
  final ReleaseNotes? existing;
  const _ReleaseNotesForm({
    super.key,
    required this.version,
    required this.existing,
  });

  @override
  ConsumerState<_ReleaseNotesForm> createState() => _ReleaseNotesFormState();
}

class _ReleaseNotesFormState extends ConsumerState<_ReleaseNotesForm> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _c = {
    for (final (key, lines) in [
      ('addedTr', widget.existing?.addedTr),
      ('addedEn', widget.existing?.addedEn),
      ('fixedTr', widget.existing?.fixedTr),
      ('fixedEn', widget.existing?.fixedEn),
      ('removedTr', widget.existing?.removedTr),
      ('removedEn', widget.existing?.removedEn),
    ])
      key: TextEditingController(text: (lines ?? const []).join('\n')),
  };
  late bool _published = widget.existing?.published ?? false;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  List<String> _lines(String key) => ReleaseNotes.linesOf(_c[key]!.text);

  ReleaseNotes _build() => ReleaseNotes(
    version: widget.version,
    addedTr: _lines('addedTr'),
    addedEn: _lines('addedEn'),
    fixedTr: _lines('fixedTr'),
    fixedEn: _lines('fixedEn'),
    removedTr: _lines('removedTr'),
    removedEn: _lines('removedEn'),
    published: _published,
  );

  String? _validate(String? text) {
    final lines = ReleaseNotes.linesOf(text ?? '');
    if (lines.length > ReleaseNotes.maxItems) {
      return 'En fazla {0} madde yazılabilir.'.trArgs([ReleaseNotes.maxItems]);
    }
    if (lines.any((l) => l.length > ReleaseNotes.maxItemLength)) {
      return 'Bir madde en fazla {0} karakter olabilir.'.trArgs([
        ReleaseNotes.maxItemLength,
      ]);
    }
    return null;
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final notes = _build();
    if (_published && notes.isEmpty) {
      context.showInfo('Yayınlamak için en az bir Türkçe madde yazın.'.tr);
      return;
    }
    final admin = ref.read(currentUserProvider);
    if (admin == null) return;
    final repo = ref.read(adminRepositoryProvider);
    setState(() => _saving = true);
    try {
      await repo.saveReleaseNotes(admin, notes);
      if (mounted) {
        context.showSuccess(
          _published
              ? 'Sürüm notları yayınlandı.'.tr
              : 'Sürüm notları taslak olarak kaydedildi.'.tr,
        );
      }
    } catch (e) {
      if (mounted) context.showError(e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _field(String key, String label) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: TextFormField(
      controller: _c[key],
      minLines: 2,
      maxLines: 8,
      validator: _validate,
      decoration: InputDecoration(
        labelText: label,
        hintText: 'Her satıra bir madde'.tr,
        alignLabelWithHint: true,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: PageListView(
        maxWidth: AppSpacing.maxFormWidth,
        children: [
          SectionHeader(title: 'Yeni'.tr),
          _field('addedTr', 'Türkçe'.tr),
          _field('addedEn', 'İngilizce (isteğe bağlı)'.tr),
          SectionHeader(title: 'Düzeltilenler'.tr),
          _field('fixedTr', 'Türkçe'.tr),
          _field('fixedEn', 'İngilizce (isteğe bağlı)'.tr),
          SectionHeader(title: 'Kaldırılanlar'.tr),
          _field('removedTr', 'Türkçe'.tr),
          _field('removedEn', 'İngilizce (isteğe bağlı)'.tr),
          const SizedBox(height: AppSpacing.xs),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _published,
            onChanged: (v) => setState(() => _published = v),
            title: Text('Yayınla'.tr),
            subtitle: Text(
              'Açıkken bu sürüme güncelleyen kullanıcılar notları bir kez görür.'
                  .tr,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: () => showReleaseNotesDialog(context, _build()),
            icon: const Icon(Icons.visibility_outlined),
            label: Text('Önizle'.tr),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: 'Kaydet'.tr,
            icon: Icons.check_rounded,
            onPressed: _save,
            isLoading: _saving,
          ),
        ],
      ),
    );
  }
}

/// Kullanıcı listesindeki pasife al / aktife al eylemi.
class UserActiveToggle extends ConsumerWidget {
  final AdminUserSummary user;
  const UserActiveToggle({super.key, required this.user});

  Future<void> _toggle(BuildContext context, WidgetRef ref) async {
    final admin = ref.read(currentUserProvider);
    if (admin == null) return;
    final disable = !user.disabled;
    final ok = await showConfirmDialog(
      context,
      title: disable
          ? '{0} pasife alınsın mı?'.trArgs([user.label])
          : '{0} aktife alınsın mı?'.trArgs([user.label]),
      message: disable
          ? 'Kullanıcı giriş yapamaz, verilerine erişemez ve bildirim almaz. Verileri silinmez; istediğiniz zaman aktife alabilirsiniz.'
                .tr
          : 'Kullanıcı yeniden giriş yapıp verilerine erişebilir.'.tr,
      confirmLabel: disable ? 'Pasife al'.tr : 'Aktife al'.tr,
      destructive: disable,
    );
    if (!ok || !context.mounted) return;
    try {
      await ref
          .read(adminRepositoryProvider)
          .setUserDisabled(admin, user, disabled: disable);
      ref.invalidate(adminUsersProvider);
      if (context.mounted) {
        context.showSuccess(
          disable
              ? 'Kullanıcı pasife alındı.'.tr
              : 'Kullanıcı aktife alındı.'.tr,
        );
      }
    } catch (e) {
      if (context.mounted) context.showError(e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final self = ref.watch(currentUserIdProvider) == user.uid;
    if (self) return const SizedBox.shrink();
    return PopupMenuButton<String>(
      tooltip: 'Kullanıcı işlemleri'.tr,
      onSelected: (_) => _toggle(context, ref),
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'toggle',
          child: Text(user.disabled ? 'Aktife al'.tr : 'Pasife al'.tr),
        ),
      ],
    );
  }
}
