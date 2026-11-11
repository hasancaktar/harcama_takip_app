# Teknoloji ve Mimari Kararları (Technology Decisions)

Bu doküman, **Flutter Harcama ve Taksit Takip Uygulaması** için seçilen mimari yaklaşımları, kütüphaneleri, sürümlerini, seçim gerekçelerini, alternatiflerini ve platform kısıtlarını açıklar.

---

## 1. Temel Platform ve SDK

- **Flutter SDK**: 3.47.5 (stable)
- **Dart SDK**: 3.13.4
- **Hedef Platformlar**:
  - Android (API Level 21+)
  - iOS (iOS 13.0+)
  - Web (PWA desteği ve responsive görünüm)

---

## 2. Paket Kararları ve Seçim Gerekçeleri

| Kategori | Paket & Sürüm | Alternatifler | Seçilme Nedeni | Kısıtlar & Kurulum Notları |
| :--- | :--- | :--- | :--- | :--- |
| **State Yönetimi** | `flutter_riverpod: ^2.6.1` | Bloc, Provider, Signals | Compile-time güvenliği, reaktif cache geçersiz kılma, test edilebilirlik, BuildContext bağımsızlığı. Repository ve use case katmanlarıyla tam uyumlu. | `ProviderScope` kök widget'ı gerektirir. Model üretiminde Freezed ile mükemmel eşleşir. |
| **Navigasyon** | `go_router: ^14.6.2` | auto_route, Beamer | Flutter resmi deklaratif yönlendirme çözümü, URL tabanlı deep link ve Firebase Dynamic Links/push notification yönlendirmeleri ile kolay entegrasyon, nested shell route (alt bar) desteği. | Android geri tuşu ve stateful shell navigasyonunun dikkatli yapılandırılması gerekir. |
| **Firebase Çekirdek** | `firebase_core: ^3.10.0` | Yok | Resmi Firebase SDK köprüleyici. | Android `google-services.json`, iOS `GoogleService-Info.plist` gerektirir. Emulator desteği tamdır. |
| **Kimlik Doğrulama** | `firebase_auth: ^5.4.0` | Özel Auth Backend | E-posta/şifre, Google Sign-In, e-posta doğrulama, token yenileme ve Firebase Security Rules ile doğrudan entegrasyon. | Google Sign-In için SHA-1 / SHA-256 parmak izleri Firebase Console'a girilmelidir. |
| **Veritabanı** | `cloud_firestore: ^5.6.0` | Supabase, Appwrite, Realm | Güçlü offline persistence, doküman bazlı güvenlik kuralları, gerçek zamanlı stream güncellemeleri, subcollection mimarisi. | Composite index'ler gereklidir; kayan noktalı tutarlar yerine integer kuruş saklanacaktır. |
| **Dosya Saklama** | `firebase_storage: ^12.3.0` | AWS S3, Cloudinary | Firestore güvenlik kuralları ve Auth ile doğrudan entegre dosya yükleme (makbuz/fatura fotoğrafları). | Resim sıkıştırma istemcide yapılmalı, dosya boyutu sınırı (örn. 5MB) konulmalıdır. |
| **Cloud Functions** | `cloud_functions: ^5.2.0` | Özel Node.js / REST API | Sunucu taraflı taksit kapatma, reconciliation ve zamanlanmış görevlerin güvenli çağrımı. | Blaze planı gerektirir. Lokal geliştirme için Firebase Functions Emulator kullanılacaktır. |
| **Push Bildirim** | `firebase_messaging: ^15.2.0` | OneSignal | FCM arka plan, ön plan ve terminated durumlarını standart yönetir. Takım içi ve zamanlanmış hatırlatmalar için esastır. | iOS APNs sertifikaları ve Android 13+ `POST_NOTIFICATIONS` izni gereklidir. |
| **Yerel Bildirim** | `flutter_local_notifications: ^18.0.1` | awesome_notifications | İnternet olmadan da kesim tarihi ve günlük harcama giriş hatırlatmalarının cihazda güvenle tetiklenmesi. | Android notification channels, exact alarm izinleri (`SCHEDULE_EXACT_ALARM`) ve iOS bildirim izinleri. |
| **Saat Dilimi** | `timezone: ^0.9.4` & `flutter_timezone: ^3.0.1` | intl tek başına | IANA saat dilimi (Europe/Istanbul) ve yerel bildirimlerin yaz/kış saatine duyarlı olarak planlanması. | `tz.initializeTimeZones()` uygulama açılışında çağrılmalıdır. |
| **Tarih & Para Formatı** | `intl: ^0.19.0` | Özel formatlayıcı | Para birimi gösterimi (TRY, USD, EUR), binlik ayırıcılar, Türkçe ay isimleri ve l10n entegrasyonu. | Varsayılan locale `tr_TR`. Kuruş dönüşümü için güvenli integer bölme fonksiyonu eşlik eder. |
| **Grafikler** | `fl_chart: ^0.70.0` | syncfusion_flutter_charts | Açık kaynak (MIT), hafif, yüksek özelleştirilebilirlik, pasta/çizgi/bar grafiklerinde akıcı animasyon ve touch/tooltip desteği. | Renk körlüğü için desen veya etiket ayrımı eklenmelidir. |
| **Görsel Seçimi** | `image_picker: ^1.1.2` | file_picker | Makbuz ve fatura fotoğrafları için kamera ve galeriden hızlı ve güvenli seçim. | Android Camera/Storage izinleri ve iOS `NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription`. |
| **Güvenli Depolama** | `flutter_secure_storage: ^9.2.2` | shared_preferences (düz) | Cihaz düzeyinde şifreli saklama (Android Keystore, iOS Keychain). Hassas kullanıcı tercihleri ve token'lar için. | Düşük boyutlu veri için uygundur; büyük veriler Firestore offline cache'e emanet edilir. |
| **Ağ Durumu** | `connectivity_plus: ^6.1.1` | internet_connection_checker | Cihazın WiFi/Mobil/Çevrimdışı durumunu algılama ve kullanıcıya anlık banner gösterme. | Yalnızca arayüz bilgilendirmesi içindir; gerçek veri senkronizasyonu Firestore Offline SDK tarafından yönetilir. |
| **Benzersiz Kimlikler** | `uuid: ^4.5.1` | nanoid | Çevrimdışı modda harcama, taksit ve işlem kimliklerinin istemci tarafında çakışmasız üretilmesi (v4). | Kriptografik güvenli rastgelelik. |

---

## 3. Mimari Kararlar (Clean Architecture & Layered Design)

Proje, gereksinimler doğrultusunda 4 ana katmana ayrılmıştır:

1. **Presentation Katmanı (`lib/presentation/`)**:
   - UI Widget'ları, Sayfalar, Riverpod Notifier'ları/Controller'ları.
   - Doğrudan Firestore erişimi **kesinlikle yasaktır**. Tüm veriler application/domain katmanından çekilir.
2. **Application Katmanı (`lib/application/`)**:
   - Use-case'ler, servisler, bildirim koordinatörleri, ekstre ve taksit motoru (InstallmentEngine).
3. **Domain Katmanı (`lib/domain/`)**:
   - İş modelleri (Entities), Value Object'ler (Money/Kuruş, StatementDate), Repository Sözleşmeleri (Interfaces), Hata sınıfları (Failures).
   - Tüm modeller **immutable**'dır.
4. **Data / Core Katmanı (`lib/data/` ve `lib/core/`)**:
   - Firestore repository implementasyonları, Firebase servisleri, lokal depolama, hata yakalama (Error Handler) ve ortak yardımcılar (Formatters, Constants).

---

## 4. Para Değerleri ve Kuruş Mantığı

- `double` tipi finansal hesaplamalarda yuvarlama hatalarına (ör. `0.1 + 0.2 = 0.30000000000000004`) yol açtığı için veritabanında ve domain modellerinde para değerleri **integer kuruş** olarak saklanır.
- Örnek: `125,50 TL` -> `12550` kuruş.
- Modelde `amountInCents: int` ve `currency: String` ("TRY") alanları bulunur.
- UI gösteriminde `MoneyFormatter.formatCents(12550, currency: 'TRY')` kullanılır -> `₺125,50`.
