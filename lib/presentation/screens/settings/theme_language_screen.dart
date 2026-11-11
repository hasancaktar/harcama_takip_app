import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../widgets/app_card.dart';

final appThemeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);

class ThemeLanguageScreen extends ConsumerWidget {
  const ThemeLanguageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(appThemeModeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Tema ve Dil')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Görünüm Teması',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                RadioListTile<ThemeMode>(
                  title: const Text('Sistem Teması'),
                  subtitle: const Text('Cihazınızın açık/koyu mod ayarını takip eder'),
                  value: ThemeMode.system,
                  groupValue: themeMode,
                  onChanged: (val) => ref.read(appThemeModeProvider.notifier).state = val!,
                ),
                const Divider(height: 1),
                RadioListTile<ThemeMode>(
                  title: const Text('Açık Tema (Emerald & Slate Trust)'),
                  subtitle: const Text('Açık ve sakin zümrüt yeşili finans teması'),
                  value: ThemeMode.light,
                  groupValue: themeMode,
                  onChanged: (val) => ref.read(appThemeModeProvider.notifier).state = val!,
                ),
                const Divider(height: 1),
                RadioListTile<ThemeMode>(
                  title: const Text('Koyu Tema'),
                  subtitle: const Text('Gözü yormayan antrasit gece teması'),
                  value: ThemeMode.dark,
                  groupValue: themeMode,
                  onChanged: (val) => ref.read(appThemeModeProvider.notifier).state = val!,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Para Birimi & Dil',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),
          const AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Varsayılan Para Birimi: Türk Lirası (₺ / TRY)', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 4),
                Text('Varsayılan Dil: Türkçe (tr_TR)', style: TextStyle(fontSize: 13, color: Colors.grey)),
                SizedBox(height: 4),
                Text('Saat Dilimi: Europe/Istanbul', style: TextStyle(fontSize: 13, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
