import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers/admin_providers.dart';
import '../../../application/providers/auth_providers.dart';
import '../../../application/providers/repository_providers.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/l10n/app_locale.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../../widgets/app_card.dart';
import '../../widgets/common.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/state_views.dart';
import 'admin_home_screen.dart';

const _categoryColors = [
  '#10B981',
  '#F97316',
  '#3B82F6',
  '#EF4444',
  '#8B5CF6',
  '#06B6D4',
  '#6366F1',
  '#F59E0B',
  '#EC4899',
  '#14B8A6',
  '#84CC16',
  '#EAB308',
  '#A855F7',
  '#E11D48',
  '#0EA5E9',
  '#6B7280',
];

/// Türkçe addan Firestore belge kimliği üretir: "Evcil Hayvan" -> "evcil_hayvan".
String categoryIdFromName(String name, Iterable<String> existingIds) {
  const map = {
    'ç': 'c',
    'ğ': 'g',
    'ı': 'i',
    'ö': 'o',
    'ş': 's',
    'ü': 'u',
    'İ': 'i',
    'Ç': 'c',
    'Ğ': 'g',
    'Ö': 'o',
    'Ş': 's',
    'Ü': 'u',
  };
  var slug = name.trim().split('').map((ch) => map[ch] ?? ch).join();
  slug = slug
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  if (slug.length < 2) slug = 'kategori';
  if (slug.length > 34) slug = slug.substring(0, 34);
  var candidate = slug;
  var i = 2;
  while (existingIds.contains(candidate)) {
    candidate = '${slug}_$i';
    i++;
  }
  return candidate;
}

class AdminCategoriesScreen extends ConsumerWidget {
  const AdminCategoriesScreen({super.key});

  Future<void> _run(
    BuildContext context,
    Future<void> Function() action,
    String success,
  ) async {
    try {
      await action();
      if (context.mounted) context.showSuccess(success);
    } catch (e) {
      if (context.mounted) context.showError(e);
    }
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    List<CategoryItem> all, {
    CategoryItem? existing,
  }) async {
    final result = await showModalBottomSheet<CategoryItem>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CategoryEditor(
        existing: existing,
        existingIds: all.map((c) => c.id).toSet(),
        nextOrder: all.length,
      ),
    );
    final admin = ref.read(currentUserProvider);
    if (result == null || admin == null || !context.mounted) return;
    await _run(
      context,
      () => ref
          .read(adminRepositoryProvider)
          .saveCategory(admin, result, isNew: existing == null),
      existing == null ? 'Kategori eklendi.'.tr : 'Kategori güncellendi.'.tr,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remoteAsync = ref.watch(remoteCategoriesProvider);
    final repo = ref.read(adminRepositoryProvider);
    final admin = ref.watch(currentUserProvider);
    final all = remoteAsync.valueOrNull ?? const <CategoryItem>[];

    return AdminScaffold(
      title: 'Kategori yönetimi'.tr,
      floatingActionButton: all.isEmpty
          ? null
          : FloatingActionButton.extended(
              heroTag: 'fab-admin-categories',
              onPressed: () => _edit(context, ref, all),
              icon: const Icon(Icons.add_rounded),
              label: Text('Kategori ekle'.tr),
            ),
      body: AsyncValueView<List<CategoryItem>>(
        value: remoteAsync,
        onRetry: () => ref.invalidate(remoteCategoriesProvider),
        data: (all) {
          if (all.isEmpty) {
            return EmptyStateView(
              icon: Icons.category_outlined,
              title: 'Yerleşik kategoriler kullanılıyor'.tr,
              message: 'Kategorileri düzenlemek için önce yerleşik listeyi yönetilebilir kategorilere dönüştürün. Mevcut harcamalar etkilenmez.'
                  .tr,
              actionLabel: 'Varsayılanları içe aktar'.tr,
              actionIcon: Icons.download_rounded,
              onAction: admin == null
                  ? null
                  : () => _run(
                      context,
                      () => repo.importDefaultCategories(admin),
                      'Kategoriler içe aktarıldı.'.tr,
                    ),
            );
          }
          final visible = all.where((c) => !c.isDeleted).toList();
          final deleted = all.where((c) => c.isDeleted).toList();

          return PageListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              96,
            ),
            children: [
              Text(
                'Sürükleyerek sıralayın. Pasif kategoriler yeni harcamalarda seçilemez; geçmiş harcamalarda görünmeye devam eder.'
                    .tr,
                style: context.textStyles.bodyMedium?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppCard(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
                child: ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  buildDefaultDragHandles: false,
                  itemCount: visible.length,
                  onReorderItem: (oldIndex, newIndex) {
                    if (admin == null) return;
                    final list = [...visible];
                    list.insert(newIndex, list.removeAt(oldIndex));
                    _run(
                      context,
                      () =>
                          repo.saveCategoryOrder(admin, [...list, ...deleted]),
                      'Sıralama kaydedildi.'.tr,
                    );
                  },
                  itemBuilder: (context, i) {
                    final c = visible[i];
                    return ListTile(
                      key: ValueKey(c.id),
                      contentPadding: const EdgeInsets.only(
                        left: AppSpacing.xs,
                        right: AppSpacing.xs,
                      ),
                      leading: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ReorderableDragStartListener(
                            index: i,
                            child: Tooltip(
                              message: 'Sıralamak için sürükleyin'.tr,
                              child: const Padding(
                                padding: EdgeInsets.all(10),
                                child: Icon(Icons.drag_indicator_rounded),
                              ),
                            ),
                          ),
                          Opacity(
                            opacity: c.isActive ? 1 : 0.45,
                            child: CategoryIcon(categoryId: c.id, size: 36),
                          ),
                        ],
                      ),
                      title: Text(
                        c.nameTr,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        [
                          if (c.nameEn.isNotEmpty) c.nameEn,
                          if (!c.isActive) 'Pasif'.tr,
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Switch(
                            value: c.isActive,
                            onChanged: admin == null
                                ? null
                                : (v) => _run(
                                    context,
                                    () => repo.saveCategory(
                                      admin,
                                      c.copyWith(isActive: v),
                                      isNew: false,
                                    ),
                                    v
                                        ? 'Kategori aktifleştirildi.'.tr
                                        : 'Kategori pasifleştirildi.'.tr,
                                  ),
                          ),
                          PopupMenuButton<String>(
                            tooltip: 'Kategori işlemleri'.tr,
                            onSelected: (value) async {
                              if (value == 'edit') {
                                await _edit(context, ref, all, existing: c);
                              } else if (admin != null) {
                                final ok = await showConfirmDialog(
                                  context,
                                  title: 'Kategori silinsin mi?'.tr,
                                  message: '"{0}" kategorisi listelerden kaldırılacak. Bu kategorideki geçmiş harcamalar silinmez ve adıyla görünmeye devam eder. İsterseniz sonradan geri yükleyebilirsiniz.'
                                      .trArgs([c.nameTr]),
                                  confirmLabel: 'Sil'.tr,
                                  destructive: true,
                                );
                                if (!ok || !context.mounted) return;
                                await _run(
                                  context,
                                  () => repo.setCategoryDeleted(
                                    admin,
                                    c,
                                    deleted: true,
                                  ),
                                  'Kategori silindi.'.tr,
                                );
                              }
                            },
                            itemBuilder: (_) => [
                              PopupMenuItem(
                                value: 'edit',
                                child: Text('Düzenle'.tr),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text('Sil'.tr),
                              ),
                            ],
                          ),
                        ],
                      ),
                      onTap: () => _edit(context, ref, all, existing: c),
                    );
                  },
                ),
              ),
              if (deleted.isNotEmpty) ...[
                SectionHeader(title: 'Silinen kategoriler'.tr),
                AppCard(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
                  child: Column(
                    children: [
                      for (final c in deleted)
                        ListTile(
                          leading: Opacity(
                            opacity: 0.45,
                            child: CategoryIcon(categoryId: c.id, size: 36),
                          ),
                          title: Text(c.nameTr),
                          subtitle: Text('Geçmiş harcamalar korunuyor'.tr),
                          trailing: TextButton(
                            onPressed: admin == null
                                ? null
                                : () => _run(
                                    context,
                                    () => repo.setCategoryDeleted(
                                      admin,
                                      c,
                                      deleted: false,
                                    ),
                                    'Kategori geri yüklendi.'.tr,
                                  ),
                            child: Text('Geri yükle'.tr),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _CategoryEditor extends StatefulWidget {
  final CategoryItem? existing;
  final Set<String> existingIds;
  final int nextOrder;

  const _CategoryEditor({
    required this.existing,
    required this.existingIds,
    required this.nextOrder,
  });

  @override
  State<_CategoryEditor> createState() => _CategoryEditorState();
}

class _CategoryEditorState extends State<_CategoryEditor> {
  final _formKey = GlobalKey<FormState>();
  late final _nameTr = TextEditingController(
    text: widget.existing?.nameTr ?? '',
  );
  late final _nameEn = TextEditingController(
    text: widget.existing?.nameEn ?? '',
  );
  late String _iconKey = widget.existing?.iconKey ?? CategoryIcons.fallbackKey;
  late String _colorHex = widget.existing?.colorHex ?? _categoryColors.first;
  late bool _active = widget.existing?.isActive ?? true;

  @override
  void dispose() {
    _nameTr.dispose();
    _nameEn.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final existing = widget.existing;
    final base =
        existing ??
        CategoryItem(
          id: categoryIdFromName(_nameTr.text, widget.existingIds),
          nameTr: '',
          order: widget.nextOrder,
        );
    Navigator.pop(
      context,
      base.copyWith(
        nameTr: _nameTr.text.trim(),
        nameEn: _nameEn.text.trim(),
        iconKey: _iconKey,
        colorHex: _colorHex,
        isActive: _active,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final preview = CategoryItem(
      id: 'preview',
      nameTr: _nameTr.text,
      iconKey: _iconKey,
      colorHex: _colorHex,
    );
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
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: preview.color.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(preview.icon, color: preview.color),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        widget.existing == null
                            ? 'Yeni kategori'.tr
                            : 'Kategoriyi düzenle'.tr,
                        style: context.textStyles.titleLarge,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _nameTr,
                  maxLength: 40,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (_) => setState(() {}),
                  validator: Validators.requiredText(
                    'Türkçe ad'.tr,
                    maxLength: 40,
                  ),
                  decoration: InputDecoration(labelText: 'Türkçe ad'.tr),
                ),
                const SizedBox(height: AppSpacing.xs),
                TextFormField(
                  controller: _nameEn,
                  maxLength: 40,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: 'İngilizce ad'.tr,
                    helperText:
                        'Boşsa İngilizce arayüzde Türkçe ad gösterilir.'.tr,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text('Simge'.tr, style: context.textStyles.titleSmall),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    for (final entry in CategoryIcons.all.entries)
                      Semantics(
                        button: true,
                        selected: entry.key == _iconKey,
                        label: entry.key,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => setState(() => _iconKey = entry.key),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: entry.key == _iconKey
                                  ? scheme.primaryContainer
                                  : scheme.surfaceContainer,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: entry.key == _iconKey
                                    ? scheme.primary
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: Icon(entry.value, size: 22),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text('Renk'.tr, style: context.textStyles.titleSmall),
                const SizedBox(height: AppSpacing.xs),
                ColorPickerRow(
                  colors: _categoryColors,
                  selectedHex: _colorHex,
                  onSelected: (h) => setState(() => _colorHex = h),
                ),
                const SizedBox(height: AppSpacing.sm),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _active,
                  onChanged: (v) => setState(() => _active = v),
                  title: Text('Aktif'.tr),
                  subtitle: Text(
                    'Pasif kategoriler yeni harcamalarda seçilemez.'.tr,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: 'Kaydet'.tr,
                  icon: Icons.check_rounded,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
