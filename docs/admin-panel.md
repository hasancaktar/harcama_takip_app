# Yönetim Paneli

Uygulama içinde, yalnızca yönetici hesabına açık bir bölümdür: **Ayarlar > Yönetim paneli**
(`/admin`). Web'de ve mobilde aynı ekranlar kullanılır.

## Yetki

Yönetici, e-posta adresi **doğrulanmış** `hasancaktar@gmail.com` hesabıdır. Yetki üç katmanda
denetlenir; arayüzdeki gizleme tek başına güvenlik sayılmaz:

| Katman | Yer | Görev |
|---|---|---|
| Firestore kuralları | `isAdmin()` – [`firestore.rules`](../firestore.rules) | Asıl koruma. Yönetici koleksiyonlarına yazmayı ve okumayı yalnızca yöneticiye açar. |
| Cloud Functions | `isAdminUser()` – [`functions/lib/notifications.js`](../functions/lib/notifications.js) | Bildirimi kuyruğa ekleyen hesabı Auth kaydından ikinci kez doğrular; değilse gönderim `failed/unauthorized` olur. |
| Arayüz | `isAdminProvider`, `resolveAuthRedirect`, `AdminScaffold` | Paneli gizler, `/admin/...` adreslerini özete yönlendirir. |

Yönetici adresini değiştirmek için üç yeri birlikte güncelleyin: `firestore.rules`,
`functions/lib/notifications.js` (`ADMIN_EMAIL`) ve `AppConstants.adminEmail`. Ardından kuralları
ve fonksiyonları yeniden yayınlayın.

## Bölümler

| Yol | Ekran | İşlev |
|---|---|---|
| `/admin` | Panel | Kullanıcı, bildirim alabilen kullanıcı ve gönderim sayıları; bölümlere geçiş |
| `/admin/send` | Bildirim gönder | Tüm kullanıcılara veya seçilenlere push bildirimi (Türkçe zorunlu, İngilizce isteğe bağlı) |
| `/admin/daily-reminder` | Günlük hatırlatma | Aç/kapat, saat, mesaj, alıcılar; son otomatik gönderim |
| `/admin/history` | Bildirim geçmişi | Her gönderimin durumu ve teslim sayıları |
| `/admin/categories` | Kategori yönetimi | Ekle, düzenle, sırala, pasifleştir, sil/geri yükle |
| `/admin/users` | Kullanıcılar | Kayıtlı hesaplar, dil ve bildirim alabilme durumu |
| `/admin/logs` | İşlem kayıtları | Yönetici işlemlerinin değiştirilemez günlüğü |

## Kategori yönetimi

- Kategoriler `categories/{id}` koleksiyonunda tutulur. Koleksiyon boşken uygulama yerleşik
  listeyi (`AppConstants.defaultCategories`) kullanır; "Varsayılanları içe aktar" bu listeyi
  yönetilebilir kayıtlara dönüştürür. Mevcut harcamalar etkilenmez, çünkü kimlikler aynıdır.
- Her kategorinin Türkçe adı, isteğe bağlı İngilizce adı, simgesi, rengi, sırası ve aktiflik
  durumu vardır. İngilizce ad boşsa İngilizce arayüzde Türkçe ad gösterilir.
- **Pasif** kategori yeni harcamalarda seçilemez; geçmiş harcamalarda görünmeye devam eder.
- **Silme kalıcı değildir.** Belge silinmez, `isDeleted = true` yapılır (kurallar `delete`
  işlemini herkese kapatır). Böylece o kategorideki geçmiş harcamalar adını, simgesini ve rengini
  kaybetmez. Silinen kategori "Geri yükle" ile geri alınabilir.
- Kategori kimliği addan üretilir (`a-z0-9_`) ve sonradan değişmez.

## Bildirimler

Ayrıntılar: [notifications.md](notifications.md#3-yönetici-bildirimleri-ve-sunucu-hatırlatması-fcm).

- İstemci bildirimi **göndermez**, yalnızca `notificationCampaigns` koleksiyonuna `queued`
  durumunda bir kayıt ekler. Gönderimi `sendCampaign` Cloud Function'ı yapar ve sonucu aynı
  belgeye yazar. Sonuç alanları istemciden değiştirilemez.
- Bir gönderim uzun süre "Kuyrukta" kalıyorsa Cloud Functions yayınlanmamıştır.

## İşlem kayıtları

Her yönetici yazması, asıl işlemle **aynı yığında** (batch) `adminLogs` koleksiyonuna bir kayıt
ekler: ya ikisi de olur ya hiçbiri. Kayıtlar yalnızca eklenir; kurallar güncellemeyi ve silmeyi
yönetici dahil herkese kapatır.

| `action` | Ne zaman |
|---|---|
| `notification.send` | Bildirim kuyruğa alındı |
| `reminder.update` | Günlük hatırlatma ayarı değişti |
| `category.create` / `category.update` | Kategori eklendi / düzenlendi (aktif-pasif dahil) |
| `category.reorder` | Sıralama değişti |
| `category.delete` / `category.restore` | Kategori silindi / geri yüklendi |
| `category.import_defaults` | Yerleşik kategoriler içe aktarıldı |

## Yayınlama

Panelin canlıda çalışması için kurallar ve fonksiyonlar yayınlanmış olmalıdır:
[backend-deployment-guide.md](backend-deployment-guide.md).
