import 'dart:async';

import 'package:flutter/foundation.dart';
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
  static const String _channelName = 'Günlük Harcama Hatırlatıcıları';
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

    tz.initializeTimeZones();
    try {
      final timeZone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZone));
    } catch (e) {
      debugPrint(
        '[NotificationService] Saat dilimi alınamadı, Europe/Istanbul kullanılıyor: $e',
      );
      tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));
    }

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
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
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: 'Günün harcamalarını girmeniz için hatırlatma gönderir',
        importance: Importance.defaultImportance,
      ),
    );
    // Cloud Functions'ın gönderdiği takım harcaması bildirimleri bu kanalı kullanır.
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        'team_expenses',
        'Takım harcamaları',
        description:
            'Takım üyeleri ortak harcama eklediğinde bildirim gönderir',
        importance: Importance.high,
      ),
    );

    _initialized = true;
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
        'Bugünkü harcamalarınızı eklediniz mi?',
        'Harcamalarınızı kaydederek bütçenizi kontrol altında tutun.',
        scheduled,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: 'Harcama girişi hatırlatması',
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
    await initialize();
    for (var day = 1; day <= 7; day++) {
      await _plugin.cancel(_baseId + day);
    }
  }
}
