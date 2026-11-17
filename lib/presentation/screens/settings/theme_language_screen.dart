import 'package:harcama_takip/core/l10n/app_locale.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers/auth_providers.dart';
import '../../../application/providers/repository_providers.dart';
import '../../../application/providers/settings_providers.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../widgets/app_card.dart';
import '../../widgets/common.dart';

class ThemeLanguageScreen extends ConsumerWidget {
  const ThemeLanguageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);
    final scheme = context.colors;

    Widget option(
      ThemeMode value,
      IconData icon,
      String title,
      String subtitle,
    ) {
      final selected = mode == value;
      return ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        selected: selected,
        trailing: selected
            ? Icon(
                Icons.check_circle_rounded,
                color: scheme.primary,
                semanticLabel: 'Seçili'.tr,
              )
            : const Icon(Icons.circle_outlined),
        onTap: () => ref.read(themeModeProvider.notifier).set(value),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text('Görünüm ve dil'.tr)),
      body: PageListView(
        maxWidth: AppSpacing.maxFormWidth,
        children: [
          SectionHeader(
            title: 'Tema'.tr,
            padding: EdgeInsets.only(bottom: AppSpacing.xs),
          ),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
            child: Column(
              children: [
                option(
                  ThemeMode.system,
                  Icons.brightness_auto_outlined,
                  'Sistem'.tr,
                  'Cihazın açık/koyu ayarını izler'.tr,
                ),
                const Divider(indent: 56),
                option(
                  ThemeMode.light,
                  Icons.light_mode_outlined,
                  'Açık'.tr,
                  'Aydınlık ortamlar için'.tr,
                ),
                const Divider(indent: 56),
                option(
                  ThemeMode.dark,
                  Icons.dark_mode_outlined,
                  'Koyu'.tr,
                  'Göz yorgunluğunu azaltır'.tr,
                ),
              ],
            ),
          ),
          SectionHeader(title: 'Dil'.tr),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
            child: Column(
              children: [
                for (final entry in AppLocale.languageNames.entries) ...[
                  if (entry.key != AppLocale.languageNames.keys.first)
                    const Divider(indent: 56),
                  ListTile(
                    leading: const Icon(Icons.translate_rounded),
                    title: Text(entry.value),
                    selected: locale.languageCode == entry.key,
                    trailing: locale.languageCode == entry.key
                        ? Icon(
                            Icons.check_circle_rounded,
                            color: scheme.primary,
                            semanticLabel: 'Seçili'.tr,
                          )
                        : const Icon(Icons.circle_outlined),
                    onTap: () async {
                      await ref.read(localeProvider.notifier).set(entry.key);
                      // Sunucu bildirimleri kullanıcının dilinde gönderilsin.
                      final uid = ref.read(currentUserIdProvider);
                      if (uid != null) {
                        try {
                          await ref
                              .read(userRepositoryProvider)
                              .setLanguage(uid, entry.key);
                        } catch (_) {}
                      }
                    },
                  ),
                ],
              ],
            ),
          ),
          SectionHeader(title: 'Bölge'.tr),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.currency_lira_rounded),
                  title: Text('Para birimi'.tr),
                  trailing: Text('TRY (₺)'),
                ),
                Divider(indent: 56),
                ListTile(
                  leading: Icon(Icons.public_rounded),
                  title: Text('Saat dilimi'.tr),
                  trailing: Text('Cihaz saati'.tr),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
