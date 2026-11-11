import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Timezone başlat
      tz.initializeTimeZones();
      final String timeZoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (e) {
      debugPrint('[NotificationService] Timezone başlatma hatası, Europe/Istanbul kullanılıyor: $e');
      try {
        tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));
      } catch (_) {}
    }

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('[NotificationService] Bildirime tıklandı: ${response.payload}');
      },
    );

    // Android bildirim kanalı oluştur
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'daily_expense_reminders',
      'Günlük Harcama Hatırlatıcıları',
      description: 'Günün harcamalarını girmeniz için size hatırlatma gönderir',
      importance: Importance.high,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    _isInitialized = true;
  }

  Future<bool> requestPermissions() async {
    final androidPlugin = _localNotifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final bool? androidGranted = await androidPlugin?.requestNotificationsPermission();

    final iosPlugin = _localNotifications.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    final bool? iosGranted = await iosPlugin?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );

    return (androidGranted ?? false) || (iosGranted ?? false);
  }

  /// Kullanıcının seçtiği saatte günlük yerel bildirim planlar.
  Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
    required List<int> days,
  }) async {
    if (!_isInitialized) await initialize();

    // Önceki günlük bildirimleri iptal et (ID: 100 - 107)
    for (int i = 1; i <= 7; i++) {
      await _localNotifications.cancel(100 + i);
    }

    final now = tz.TZDateTime.now(tz.local);

    for (final day in days) {
      var scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );

      // İlgili haftanın gününe ayarla
      while (scheduledDate.weekday != day || scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      await _localNotifications.zonedSchedule(
        100 + day,
        'Günün Harcamalarını Eklemeyi Unutma',
        'Bugün yaptığın harcamaları kaydederek bütçeni kontrol altında tut.',
        scheduledDate,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'daily_expense_reminders',
            'Günlük Harcama Hatırlatıcıları',
            channelDescription: 'Harcama girişi hatırlatması',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        payload: '/expenses/add',
      );
    }

    debugPrint('[NotificationService] Günlük hatırlatıcı saat $hour:$minute için planlandı.');
  }

  Future<void> cancelAll() async {
    await _localNotifications.cancelAll();
  }
}
