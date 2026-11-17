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

## 3. Yönetici bildirimleri ve sunucu hatırlatması (FCM)

> **Gönderimi şu an Cloudflare Workers'taki bildirim sunucusu yapar**
> ([notification-worker.md](notification-worker.md)); proje Firebase'in ücretsiz planında
> olduğu için Cloud Functions yayınlanamıyor. Aşağıdaki kurallar iki sunucu için de aynıdır;
> metindeki `sendCampaign` / `sendDailyReminder` adları Cloud Functions sürümünü anlatır.

Yönetim panelinden yönetilir ([admin-panel.md](admin-panel.md)); `announcements` kanalını kullanır.

**Elle gönderim (`sendCampaign`)**

- Yönetici başlık ve mesajı (Türkçe zorunlu, İngilizce isteğe bağlı) yazar, alıcıyı seçer:
  tüm kullanıcılar veya seçilen kullanıcılar (en fazla 500).
- İstemci `notificationCampaigns` koleksiyonuna `queued` kayıt ekler; fonksiyon gönderir ve
  durumu yazar: `sending` → `sent` / `partial` / `failed` / `no_recipients`. Alıcı, cihaz,
  başarılı, başarısız ve bildirimi kapalı kullanıcı sayıları geçmiş ekranında görünür.
- Geçersiz cihaz anahtarları gönderim sırasında temizlenir.

**Günlük otomatik hatırlatma (`sendDailyReminder`)**

- Ayar `appConfig/dailyReminder` belgesindedir: açık/kapalı, saat, başlık/mesaj (TR ve EN),
  alıcılar. Varsayılan mesaj: "Bugünkü harcamalarınızı girmeyi unutmayın!", varsayılan kapalı.
- Zamanlayıcı 5 dakikada bir çalışır ve saati **Europe/Istanbul** saatine göre değerlendirir
  (yaz saati kuralları `Intl` ile hesaplanır). Ayarlanan saatten sonraki 30 dakika içinde
  gönderir; zamanlayıcı gecikse de bildirim kaçmaz, saatler sonra da gönderilmez.
- **Günde bir kez:** gönderim günü ve saati (`lastSentDate`, `lastSentTime`) koşullu yazılır;
  eşzamanlı iki çalıştırma veya yeniden deneme ikinci bildirimi gönderemez. Yönetici aynı gün
  saati değiştirirse yeni saatte bir kez daha gönderilir. `lastSentDate` istemciden
  değiştirilemez (kurallar engeller).
- Her otomatik gönderim de `type: daily` olarak bildirim geçmişine düşer.

**Kullanıcı tercihleri**

- `users/{uid}.pushEnabled == false` olan kullanıcılara sunucu bildirimi gönderilmez
  (Ayarlar > Bildirimler > "Duyuru ve hatırlatma bildirimleri").
- Kendi kişisel hatırlatıcısını açmış kullanıcılar da sunucunun günlük hatırlatmasını alır
  (2026-11-18 kararı); bu kullanıcılar günde iki hatırlatma alabilir.
- Mesaj kullanıcının dilinde gider (`users/{uid}.language`); İngilizce metin boşsa Türkçe gider.
- Android 13+ bildirim izni ilk girişte bir kez istenir. İzin verilmezse cihaz anahtarı
  kaydedilse de sistem bildirimi göstermez.
- Uygulama açıkken gelen bildirim yerel bildirim olarak gösterilir; dokunmak "Yeni harcama"
  ekranını açar.

**Sınırlar**

- Saat tüm kullanıcılar için Türkiye saatidir; kullanıcının bulunduğu saat dilimine göre
  ayrı ayrı gönderim yapılmaz.
- Her gönderimde tüm `users` koleksiyonu okunur. Binlerce kullanıcıya kadar sorun olmaz;
  daha büyük ölçekte FCM konu (topic) aboneliğine geçilmelidir.
- Bildirim sunucusu (`https://harcama-bildirim.hasancaktar.workers.dev`) çalışmıyorsa bildirimler "Kuyrukta" kalır ve hiçbir şey gönderilmez.
