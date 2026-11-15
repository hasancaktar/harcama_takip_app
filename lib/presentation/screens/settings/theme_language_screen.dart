import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
                semanticLabel: 'Seçili',
              )
            : const Icon(Icons.circle_outlined),
        onTap: () => ref.read(themeModeProvider.notifier).set(value),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Görünüm')),
      body: PageListView(
        maxWidth: AppSpacing.maxFormWidth,
        children: [
          const SectionHeader(
            title: 'Tema',
            padding: EdgeInsets.only(bottom: AppSpacing.xs),
          ),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
            child: Column(
              children: [
                option(
                  ThemeMode.system,
                  Icons.brightness_auto_outlined,
                  'Sistem',
                  'Cihazın açık/koyu ayarını izler',
                ),
                const Divider(indent: 56),
                option(
                  ThemeMode.light,
                  Icons.light_mode_outlined,
                  'Açık',
                  'Aydınlık ortamlar için',
                ),
                const Divider(indent: 56),
                option(
                  ThemeMode.dark,
                  Icons.dark_mode_outlined,
                  'Koyu',
                  'Göz yorgunluğunu azaltır',
                ),
              ],
            ),
          ),
          const SectionHeader(title: 'Bölge'),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
            child: Column(
              children: const [
                ListTile(
                  leading: Icon(Icons.translate_rounded),
                  title: Text('Dil'),
                  trailing: Text('Türkçe'),
                ),
                Divider(indent: 56),
                ListTile(
                  leading: Icon(Icons.currency_lira_rounded),
                  title: Text('Para birimi'),
                  trailing: Text('TRY (₺)'),
                ),
                Divider(indent: 56),
                ListTile(
                  leading: Icon(Icons.public_rounded),
                  title: Text('Saat dilimi'),
                  trailing: Text('Cihaz saati'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
