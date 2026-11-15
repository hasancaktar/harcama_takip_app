# Bildirimler

## 1. Günlük harcama hatırlatıcısı (yerel, Android/iOS)

- `NotificationService` (`flutter_local_notifications`) seçilen gün ve saatte tekrarlayan bildirim planlar.
- Ayar profil belgesinde saklanır (`dailyReminderEnabled`, `dailyReminderHour`,
  `dailyReminderMinute`, `dailyReminderDays`); uygulama açıldığında ve ayar değiştiğinde
  `AppShellScreen` hatırlatıcıları profille senkronlar (cihaz değişse de ayar korunur).
- Varsayılan **kapalıdır**; kullanıcı açtığında Android 13+ bildirim izni bağlamsal olarak istenir.
- Kesin alarm izni (`SCHEDULE_EXACT_ALARM`) gerektirmemek için `inexactAllowWhileIdle` kullanılır
  (Play Store politikası ve Android 14 varsayılan reddi nedeniyle). Bildirim birkaç dakika gecikebilir.
- Cihaz yeniden başlatıldığında hatırlatıcılar `ScheduledNotificationBootReceiver` ile geri yüklenir
  (alıcılar `AndroidManifest.xml` içinde tanımlıdır; önceki sürümde eksikti ve bildirimler hiç tetiklenmiyordu).
- Bildirime dokunmak "Yeni harcama" ekranını açar.
- Web'de zamanlanmış yerel bildirim yoktur; ayar ekranı bunu açıkça belirtir.

## 2. Takım harcaması bildirimi (FCM, Android)

- `PushTokenService` giriş sonrası cihaz anahtarını `users/{uid}.fcmTokens` dizisine ekler,
  anahtar yenilenince günceller, çıkışta siler. İzin istemez.
- `notifyTeamOnExpense` Cloud Function'ı yeni takım harcamasında diğer üyelere bildirim gönderir
  (`team_expenses` kanalı) ve geçersiz anahtarları temizler. Sistem tarafından işlenen aylık
  taksitler için bildirim gönderilmez.
- Bu özellik Cloud Functions'ın yayınlanmasını (Blaze planı) gerektirir.
- Web için FCM etkin değildir (VAPID anahtarı ve servis çalışanı yapılandırması gerekir).
