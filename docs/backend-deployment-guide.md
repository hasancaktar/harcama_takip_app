# Backend Yayınlama Rehberi

Uygulama sunucusuz çalışır: Firebase Authentication + Cloud Firestore + Firebase Hosting (web)
ve isteğe bağlı Cloud Functions. Bu sürümle gelen kural ve dizin değişiklikleri **yayınlanmadan
uygulamanın yeni sürümü canlıda doğru çalışmaz.**

## 1. Ön koşullar

```bash
npm install -g firebase-tools
```

```bash
firebase login
```

Firestore emülatörü ve kural testleri için JDK 21 veya üzeri gerekir.

## 2. Firebase Console ayarları

1. **Authentication > Sign-in method:** E-posta/Şifre etkin olmalı.
2. **Authentication > Templates:** Şablon dilini Türkçe yapın; "Email address verification" ve
   "Password reset" e-postalarının gönderici adını ve metnini düzenleyin.
3. **Authentication > Settings > Authorized domains:** Web uygulamasının yayınlandığı alan
   adlarını ekleyin (ör. `harcama-takip-app-7ff66.web.app`).
4. **Authentication > Settings > User account management:** "Email enumeration protection"
   açık kalmalı (şifre sıfırlama ekranı buna göre tasarlandı).
5. **Google Cloud Console > APIs & Services > Credentials:** Web API anahtarını HTTP referrer
   (alan adı) ile, Android anahtarını paket adı + SHA-1 ile kısıtlayın. Firebase istemci anahtarları
   gizli değildir; erişim güvenliği kurallarla sağlanır, kısıtlama kötüye kullanımı azaltır.
6. (Önerilen) **App Check:** Android için Play Integrity, web için reCAPTCHA Enterprise etkinleştirip
   Firestore'da zorunlu kılın.

## 3. Kurallar ve dizinler (zorunlu)

```bash
firebase deploy --only firestore:rules,firestore:indexes
```

Dizinlerin oluşması birkaç dakika sürebilir. Takım davetleri için `invites` koleksiyon grubu
dizini (`invitedEmail`, `status`) gereklidir.

## 4. Web uygulaması

```bash
flutter build web --release
```

```bash
firebase deploy --only hosting
```

`firebase.json` SPA yönlendirmesini, güvenlik başlıklarını (X-Frame-Options, nosniff,
Referrer-Policy, Permissions-Policy) ve önbellek kurallarını içerir.

## 5. Cloud Functions (isteğe bağlı, Blaze planı gerekir)

| Fonksiyon | Tetikleyici | Görev |
|---|---|---|
| `postDueInstallments` | Her gece 00:10 (Europe/Istanbul) | Vadesi gelen taksitleri idempotent olarak harcamalara işler (uygulama açılmasa da). |
| `notifyTeamOnExpense` | `expenses/{id}` oluşturulduğunda | Takım harcamasında diğer üyelere FCM bildirimi gönderir, geçersiz cihaz anahtarlarını temizler. |
| `sendCampaign` | `notificationCampaigns/{id}` oluşturulduğunda | Yöneticinin kuyruğa eklediği bildirimi gönderir, göndereni Auth kaydından doğrular, sonucu belgeye yazar. |
| `sendDailyReminder` | 5 dakikada bir (Europe/Istanbul) | Ayarlanan saatte günlük hatırlatmayı günde bir kez gönderir. Ayar kapalıyken yalnızca bir belge okur. |

```bash
cd functions && npm install && npm test
```

```bash
firebase deploy --only functions
```

Fonksiyonlar yayınlanmasa da uygulama çalışır: taksitler uygulama açılışında istemci tarafından
işlenir. Ancak takım bildirimleri gitmez ve **yönetim panelinden gönderilen bildirimler ile
günlük otomatik hatırlatma çalışmaz** (gönderimler "Kuyrukta" kalır).

Yönetim paneli için kuralların (`firebase deploy --only firestore:rules`) da yayınlanmış olması
gerekir; aksi halde kategori, bildirim ve işlem kaydı yazmaları reddedilir. Yeni koleksiyonlar
tek alanlı sıralama kullandığından ek dizin gerekmez.

`sendDailyReminder` ayda yaklaşık 8.600 kez çalışır (Cloud Scheduler'da 1 iş). Bu, Blaze
planının ücretsiz kotası içindedir.

> Önceki sürümdeki `api` HTTP fonksiyonu (sabit `dev-secret-key` yedek anahtarıyla herkese açıktı
> ve hiçbir iş yapmıyordu) ve boş çalışan saatlik hatırlatıcı kaldırıldı. Daha önce yayınlandıysa
> `firebase functions:delete api sendDailySpendingReminders postScheduledInstallments onExpenseCreated`
> ile silin.

## 6. Mevcut veriler hakkında

- Eski sürüm nakit/banka kartı harcamalarını, ayın 1'inden sonra girildiyse **bir sonraki aya**
  yazıyordu. Bu kayıtlar silinmedi; düzenlenip kaydedildiklerinde doğru aya taşınır.
- Eski sürümün rastgele kimlikle yazdığı bütçeler okunmaya devam eder; yeni kayıtlar
  `user_{uid}_{dönem}` / `team_{teamId}_{dönem}` kimliğiyle yazılır.
- Mevcut kullanıcılar bir sonraki girişte e-posta doğrulama ekranını görür.
