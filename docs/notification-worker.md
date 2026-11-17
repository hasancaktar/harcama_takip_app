# Bildirim Sunucusu (Cloudflare Workers)

Yönetim panelinden gönderilen push bildirimlerini ve günlük otomatik hatırlatmayı,
Firebase'in ücretli Blaze planı gerekmeden **Cloudflare Workers ücretsiz planında**
çalışan küçük bir sunucu gönderir. Kod: [`notification-worker/`](../notification-worker).

## Nasıl çalışır

```
Yönetim paneli ──(1) kampanyayı kuyruğa yazar──▶ Firestore: notificationCampaigns (status: queued)
       │
       └──(2) POST /send  (Firebase kimlik anahtarıyla) ──▶ Cloudflare Worker
                                                              │ yönetici mi? (imza + e-posta)
                                                              │ kullanıcıları ve cihaz anahtarlarını okur
                                                              ├──▶ FCM HTTP v1: cihazlara gönderir
                                                              └──▶ sonucu kampanyaya yazar (sent / partial …)

Zamanlayıcı (dakikada bir) ──▶ Worker: günlük hatırlatma saati geldiyse kuyruğa ekler,
                                       bekleyen veya yarım kalmış gönderimi sürdürür
```

- (2) numaralı istek başarısız olsa bile (ağ, uygulama kapandı…) zamanlayıcı kuyruğu
  dakikada bir taradığı için bildirim **en geç bir dakika** içinde gider.
- Kampanyayı aynı anda iki çalıştırma işleyemez (`leaseUntil` kilidi ve koşullu yazma).
- Günlük hatırlatma, `lastSentDate` koşullu yazıldığı için günde **bir kez** gider.
- Kullanıcı tercihleri, dil ve geçersiz cihaz anahtarlarının temizlenmesi Cloud Functions
  sürümüyle aynıdır; ortak mantık [`functions/lib/notifications.js`](../functions/lib/notifications.js)
  dosyasından kullanılır.

### Ücretsiz plan sınırları

| Sınır | Etkisi |
|---|---|
| Günde 100.000 istek | Zamanlayıcı günde 1.440 kez çalışır; fazlasıyla yeter |
| Bir çalıştırmada en fazla 50 dış istek | Her çalıştırma en fazla **35 cihaza** gönderir (`CHUNK_SIZE`). Daha fazla cihaz varsa kalanlar sonraki dakikalarda gönderilir; 350 cihaz ≈ 10 dakika |
| Çalıştırma başına 10 ms işlemci süresi | İmzalama ve JSON işlemleri bu sınırın altında kalır; ağ beklemesi sayılmaz |

## Güvenlik

- Sunucu, Firestore'a ve FCM'e **yalnızca iki yetkisi olan** ayrı bir servis hesabıyla erişir.
  Anahtar Cloudflare'de şifreli "secret" olarak saklanır; kodda ve GitHub'da yer almaz.
- `/send` isteği yalnızca e-postası doğrulanmış yönetici hesabının Firebase kimlik
  anahtarıyla kabul edilir; imza Google'ın açık anahtarlarıyla doğrulanır. Yönetici
  yalnızca kendi oluşturduğu kampanyayı tetikleyebilir.
- Kampanya oluşturma yetkisi değişmedi: Firestore kurallarında yalnızca yönetici yazabilir.
- Web uygulamasının istek yapabileceği adresler `wrangler.toml` içindeki `ALLOWED_ORIGINS`
  listesiyle sınırlıdır.

## Kurulum (bir kez)

### 1. Cloudflare hesabı

[dash.cloudflare.com/sign-up](https://dash.cloudflare.com/sign-up) adresinden ücretsiz hesap
açın. Kredi kartı istenmez.

### 2. Servis hesabı ve anahtarı (Google Cloud)

1. [Servis hesapları](https://console.cloud.google.com/iam-admin/serviceaccounts?project=harcama-takip-app-7ff66)
   sayfasında **Servis hesabı oluştur**: ad `harcama-bildirim`.
2. Rol olarak **yalnızca** şu ikisini ekleyin:
   - `Cloud Datastore User` (Firestore okuma/yazma)
   - `Firebase Cloud Messaging API Admin` (bildirim gönderme)
3. Hesabı açın → **Anahtarlar** → **Anahtar ekle** → **JSON**. İnen dosyayı proje klasörünün
   **dışında** bir yere kaydedin (ör. `İndirilenler`).
4. [Firebase Cloud Messaging API](https://console.cloud.google.com/apis/library/fcm.googleapis.com?project=harcama-takip-app-7ff66)
   sayfasında API'nin **Etkin** olduğunu kontrol edin.

### 3. Yükleme

```bash
cd notification-worker
```

```bash
npm install
```

```bash
npx wrangler login
```

```bash
npx wrangler deploy
```

Son komut sunucunun adresini yazar: `https://harcama-bildirim.<hesap-adı>.workers.dev`.

### 4. Anahtarı sunucuya verme

PowerShell'de (dosya yolunu kendi indirdiğiniz dosyayla değiştirin):

```powershell
Get-Content "$HOME\Downloads\harcama-takip-app-7ff66-xxxx.json" -Raw | npx wrangler secret put GOOGLE_SERVICE_ACCOUNT
```

Ardından anahtar dosyasını bilgisayarınızdan silin; Cloudflare'de saklanıyor.

### 5. Kontrol

`https://harcama-bildirim.<hesap-adı>.workers.dev/health` adresi `{"ok":true,"configured":true}`
dönmelidir.

### 6. Uygulamaya adresi tanıtma

Sunucu adresi `AppConstants.notificationServerUrl` içinde tanımlıdır (veya derlemede
`--dart-define=NOTIFICATION_SERVER_URL=...`). Adres tanımlı değilse uygulama yine çalışır;
bildirimler yalnızca zamanlayıcıyla (en geç bir dakika içinde) gider. Adres tanımlanınca
"Gönder"e basılır basılmaz gider. Değişiklikten sonra web ve Android sürümleri yeniden
derlenmelidir.

## İşletme

| İş | Komut (`notification-worker` klasöründe) |
|---|---|
| Testler | `npm test` |
| Canlı kayıtları izleme | `npx wrangler tail` |
| Yeniden yükleme | `npx wrangler deploy` |
| Yerelde çalıştırma | `npx wrangler dev --test-scheduled` (sahte anahtar için `.dev.vars`; git dışında) |
| Anahtarı yenileme | Google Cloud'da yeni JSON anahtar oluşturup 4. adımı tekrarlayın, eskisini silin |

> **Cloud Functions ile birlikte kullanmayın.** İleride Blaze planına geçilirse
> `sendCampaign` ve `sendDailyReminder` fonksiyonları yayınlanmamalı ya da bu sunucu
> kapatılmalıdır; ikisi aynı anda çalışırsa günlük hatırlatma iki kez gidebilir.
