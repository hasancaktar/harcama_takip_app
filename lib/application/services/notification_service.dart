import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/l10n/app_locale.dart';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Günlük harcama hatırlatıcılarını yöneten yerel bildirim servisi (Android/iOS).
/// Web'de yerel zamanlanmış bildirim desteklenmez; tüm çağrılar güvenle yok sayılır.
class NotificationService {
  NotificationService._internal();
  static final NotificationService instance = NotificationService._internal();

  /// Testlerde alt sınıf oluşturmak için.
  @visibleForTesting
  NotificationService.forTesting();

  static const String _channelId = 'daily_expense_reminders';
  static String get _channelName => 'Günlük Harcama Hatırlatıcıları'.tr;
  static const int _baseId = 100;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final StreamController<String> _tapController =
      StreamController<String>.broadcast();
  bool _initialized = false;

  bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Bildirime dokunulduğunda yönlendirilecek rota (ör. "/expenses/add").
  Stream<String> get onNotificationTap => _tapController.stream;

  Future<void> initialize() async {
    if (_initialized || !isSupported) return;

    try {
      tz.initializeTimeZones();
      try {
        final timeZone = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(timeZone));
      } catch (e) {
        debugPrint(
          '[NotificationService] Saat dilimi alınamadı, Europe/Istanbul deneniyor: $e',
        );
        try {
          tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));
        } catch (_) {}
      }

      const settings = InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_notification'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      );

      await _plugin.initialize(
        settings,
        onDidReceiveNotificationResponse: (response) {
          final payload = response.payload;
          if (payload != null && payload.startsWith('/')) {
            _tapController.add(payload);
          }
        },
      );

      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await android?.createNotificationChannel(
        AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: 'Günün harcamalarını girmeniz için hatırlatma gönderir'.tr,
          importance: Importance.defaultImportance,
        ),
      );
      // Cloud Functions'ın gönderdiği takım harcaması bildirimleri bu kanalı kullanır.
      await android?.createNotificationChannel(
        AndroidNotificationChannel(
          'team_expenses',
          'Takım harcamaları'.tr,
          description:
              'Takım üyeleri ortak harcama eklediğinde bildirim gönderir'.tr,
          importance: Importance.high,
        ),
      );

      // Yönetim panelinden gönderilen duyurular ve sunucu hatırlatmaları.
      await android?.createNotificationChannel(
        AndroidNotificationChannel(
          'announcements',
          'Duyurular ve hatırlatmalar'.tr,
          description: 'Uygulama duyuruları ve günlük hatırlatmalar'.tr,
          importance: Importance.high,
        ),
      );

      _initialized = true;
    } catch (e) {
      debugPrint('[NotificationService] Başlatma hatası: $e');
    }
  }

  /// Uygulama açıkken gelen push bildirimini hemen gösterir (Android, ön planda
  /// gelen FCM bildirimlerini kendiliğinden göstermez).
  Future<void> showNow({
    required String title,
    required String body,
    String? route,
    String channelId = 'announcements',
  }) async {
    if (!isSupported) return;
    await initialize();
    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch.remainder(1 << 30),
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelId == 'team_expenses'
              ? 'Takım harcamaları'.tr
              : 'Duyurular ve hatırlatmalar'.tr,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: route,
    );
  }

  /// Bildirime dokunma olayını dışarıdan (FCM) iletmek için.
  void emitTap(String route) {
    if (route.startsWith('/')) _tapController.add(route);
  }

  /// Uygulama bir bildirime dokunularak açıldıysa ilgili rotayı döner.
  Future<String?> launchRoute() async {
    if (!isSupported) return null;
    await initialize();
    final details = await _plugin.getNotificationAppLaunchDetails();
    final payload = details?.notificationResponse?.payload;
    if ((details?.didNotificationLaunchApp ?? false) &&
        payload != null &&
        payload.startsWith('/')) {
      return payload;
    }
    return null;
  }

  /// Bildirim izni ister. İzin verilirse `true` döner.
  Future<bool> requestPermission() async {
    if (!isSupported) return false;
    await initialize();
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    return await ios?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        ) ??
        false;
  }

  /// Seçilen günlerde ve saatte tekrarlayan hatırlatıcıları planlar.
  ///
  /// Kesin alarm izni (Android 12+) gerektirmemek için "inexact" planlama kullanılır;
  /// hatırlatıcı birkaç dakika gecikebilir, bu kullanım için yeterlidir.
  Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
    required List<int> days,
  }) async {
    if (!isSupported) return;
    await initialize();
    await cancelReminders();

    final now = tz.TZDateTime.now(tz.local);
    for (final day in days.toSet()) {
      var scheduled = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );
      while (scheduled.weekday != day || !scheduled.isAfter(now)) {
        scheduled = scheduled.add(const Duration(days: 1));
      }

      await _plugin.zonedSchedule(
        _baseId + day,
        'Bugünkü harcamalarınızı eklediniz mi?'.tr,
        'Harcamalarınızı kaydederek bütçenizi kontrol altında tutun.'.tr,
        scheduled,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: 'Harcama girişi hatırlatması'.tr,
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        payload: '/expenses/add',
      );
    }
    debugPrint(
      '[NotificationService] Hatırlatıcı planlandı: $hour:$minute, günler: $days',
    );
  }

  Future<void> cancelReminders() async {
    if (!isSupported) return;
    try {
      await initialize();
      for (var day = 1; day <= 7; day++) {
        await _plugin.cancel(_baseId + day);
      }
    } catch (e) {
      debugPrint('[NotificationService] Hatırlatıcı iptal hatası: $e');
    }
  }
}
