import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/l10n/app_locale.dart';
import '../../data/services/app_update_checker.dart';

/// "Sonra" denen güncelleme penceresi aynı sürüm için aynı gün tekrar açılmaz.
abstract class UpdatePromptPolicy {
  static const String key = 'update_prompt_snoozed';

  static String _today(DateTime now) =>
      '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

  static bool shouldShow(
    SharedPreferences? prefs,
    AvailableUpdate update, {
    required DateTime now,
  }) => prefs?.getString(key) != '${update.versionCode}|${_today(now)}';

  static Future<void> snooze(
    SharedPreferences? prefs,
    AvailableUpdate update, {
    required DateTime now,
  }) async {
    try {
      await prefs?.setString(key, '${update.versionCode}|${_today(now)}');
    } catch (_) {}
  }
}

/// Zorunlu olmayan güncelleme penceresi. "Güncelle" seçilirse `true` döner.
Future<bool> showUpdatePrompt(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.system_update_rounded),
      title: Text('Yeni sürüm mevcut'.tr),
      content: Text(
        'Yeni özellikler ve düzeltmeler için uygulamayı güncelleyin.'.tr,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text('Sonra'.tr),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text('Güncelle'.tr),
        ),
      ],
    ),
  );
  return result ?? false;
}
