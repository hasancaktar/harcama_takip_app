# Harcama Takip

Kişisel ve aile harcamalarını, kredi kartı ekstrelerini, taksitleri ve aylık bütçeyi tek yerden
takip etmeye yarayan Flutter + Firebase uygulaması (Android ve Web).

## Özellikler

- **E-posta doğrulamalı hesap:** Kayıt sonrası doğrulama e-postası gönderilir; doğrulanmamış
  hesaplar uygulamanın hiçbir verisine erişemez (hem arayüzde hem Firestore kurallarında).
  Doğrulama e-postası 60 sn bekleme süresiyle tekrar gönderilebilir, durum otomatik algılanır.
- **Bireysel ve takım çalışma alanları:** Kişisel harcamalar yalnızca sahibine görünür.
  Aile/ev takımı oluşturulur, üyeler e-posta adresine bağlı 8 karakterlik davet koduyla katılır.
- **Kredi kartı ekstre mantığı:** Kesim gününe göre harcamanın hangi ekstreye yazılacağı
  otomatik hesaplanır (28/29/30/31 gün, yıl geçişi). Nakit ve diğer ödemeler takvim ayına yazılır.
- **Taksit planları:** Kuruş kaybı olmadan bölünür; her taksit kendi ekstre ayında idempotent
  olarak harcamalara eklenir. Plan detayı, ödeme takvimi ve iptal.
- **Bütçe:** Çalışma alanı + ay başına tek bütçe, isteğe bağlı kategori limitleri, aşım uyarıları.
- **Raporlar:** Son 6 ay trendi, kategori dağılımı, ödeme yöntemleri, takım üyelerine göre dağılım.
- **Duyarlı arayüz:** Telefonda alt gezinme çubuğu, tablet/masaüstünde ve yatay telefonda yan
  gezinme rayı; açık/koyu tema, erişilebilirlik etiketleri, çevrimdışı uyarısı. Tüm ekranlar
  7 ekran boyutunda ve iki dilde otomatik taşma denetiminden geçer.
- **Türkçe ve İngilizce:** Dil ayarlardan anında değişir; yeni dil eklemeye uygun merkezi yapı
  ([docs/localization.md](docs/localization.md)).
- **Yönetim paneli:** Yalnızca yönetici hesabına açık; push bildirimi gönderme, sunucu taraflı
  günlük hatırlatma, bildirim geçmişi, kategori yönetimi, kullanıcı listesi ve işlem kayıtları.
  Yetki Firestore kurallarında ve Cloud Functions'ta da denetlenir
  ([docs/admin-panel.md](docs/admin-panel.md)).
- **Hesap yönetimi:** Ad güncelleme, şifre değiştirme, yeniden kimlik doğrulamalı hesap ve veri silme.

## Mimari

```
lib/
├── core/          tema ve tasarım belirteçleri, dil (l10n), hata mesajları, para/dönem hesaplamaları, doğrulayıcılar
├── domain/        varlıklar (Expense, CreditCard, InstallmentPlan, Budget, Team, TeamInvite…) ve depo arayüzleri
├── data/          Firebase Auth / Firestore depo uygulamaları
├── application/   Riverpod sağlayıcıları ve servisler (taksit işleme, bildirim, hesap)
└── presentation/  GoRouter (oturum + e-posta doğrulama korumalı), ekranlar ve ortak bileşenler
firestore.rules            güvenlik kuralları  ·  firestore.indexes.json  dizinler
firestore-tests/           kural testleri (Firebase Emulator)
functions/                 Cloud Functions (2. nesil): gece taksit işleme, takım bildirimi,
                           yönetici bildirimleri ve günlük hatırlatma
```

Ayrıntılar: [docs/architecture.md](docs/architecture.md), [docs/security-rules.md](docs/security-rules.md),
[docs/installment-and-statement-logic.md](docs/installment-and-statement-logic.md).

## Geliştirme

```bash
flutter pub get
flutter run -d chrome            # canlı Firebase projesine bağlanır
```

Yerel emülatörlerle (önerilen; JDK 21+ gerekir):

```bash
firebase emulators:start --only auth,firestore --project harcama-takip-app-7ff66
```

```bash
flutter run -d chrome --dart-define=USE_FIREBASE_EMULATOR=true
```

Android emülatöründen bağlanırken `--dart-define=FIREBASE_EMULATOR_HOST=10.0.2.2` ekleyin.

## Testler

```bash
flutter analyze
```

```bash
flutter test
```

```bash
cd firestore-tests && npm install && npm test
```

```bash
cd functions && npm test
```

Uçtan uca test adımları ve test hesapları: [docs/testing.md](docs/testing.md).

## Yayınlama

Kurallar, dizinler, hosting ve fonksiyonların yayınlanması: [docs/backend-deployment-guide.md](docs/backend-deployment-guide.md).
Android sürüm imzalama: [docs/release-guide.md](docs/release-guide.md).
