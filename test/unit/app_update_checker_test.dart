import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harcama_takip/data/services/app_update_checker.dart';
import 'package:harcama_takip/presentation/widgets/update_prompt.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Play erişilemezse (eklenti yok) hata fırlatmadan null döner', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    expect(await PlayAppUpdateChecker().check(), isNull);
  });

  test('Android dışında kontrol yapılmaz', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    expect(await PlayAppUpdateChecker().check(), isNull);
  });

  test('"Sonra" aynı sürüm için yalnızca o gün geçerlidir', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    const v7 = AvailableUpdate(versionCode: 7);
    final day1 = DateTime(2026, 11, 25, 9);
    expect(UpdatePromptPolicy.shouldShow(prefs, v7, now: day1), isTrue);
    await UpdatePromptPolicy.snooze(prefs, v7, now: day1);
    expect(UpdatePromptPolicy.shouldShow(prefs, v7, now: day1), isFalse);
    expect(
      UpdatePromptPolicy.shouldShow(prefs, v7, now: DateTime(2026, 11, 26, 8)),
      isTrue,
    );
    expect(
      UpdatePromptPolicy.shouldShow(
        prefs,
        const AvailableUpdate(versionCode: 8),
        now: day1,
      ),
      isTrue,
    );
    // Tercihler yoksa (ör. başlatılamadıysa) yine sorulur, hata olmaz.
    expect(UpdatePromptPolicy.shouldShow(null, v7, now: day1), isTrue);
    await UpdatePromptPolicy.snooze(null, v7, now: day1);
  });
}
