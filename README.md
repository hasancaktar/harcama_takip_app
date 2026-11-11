# 💳 Harcama ve Taksit Takip Uygulaması

Ailelerin ve bireysel kullanıcıların harcamalarını, kredi kartı ekstrelerini, taksitli ödemelerini, kart kesim tarihlerini ve aylık bütçelerini takip edebileceği, üretime hazır ve test edilebilir Flutter mobil uygulaması.

---

## 🌟 Öne Çıkan Özellikler

1. **Bireysel ve Ortak Takım/Aile Yönetimi:**
   - Kullanıcılar tek bir hesapla hem kişisel harcamalarını bağımsız takip edebilir hem de aile/ev takımı oluşturarak ortak bütçe yönetebilir.
   - Rol tabanlı erişim kontrolü (`owner`, `admin`, `member`, `viewer`).
   - Davet kodu ile takıma katılma desteği.

2. **Kredi Kartı Kesim Tarihi & Otomatik Ekstre Mantığı:**
   - Ay sonu kenar durumları (28/29 Şubat artık yıl, 30 ve 31 gün çeken aylar) otomatik yönetilir.
   - Harcama tarihi ile kesim günü karşılaştırılarak işlemin mevcut ekstreye mi yoksa sonraki ekstreye mi gireceği deterministik olarak belirlenir.
   - Son ödeme vadesi ve yaklaşan kesim günü uyarıları.

3. **Kuruş Hassasiyetinde Taksit Motoru (Installment Engine):**
   - Kayan noktalı (`double`) yuvarlama hatalarını önlemek için para değerleri tamsayı kuruş (`amountInCents`) olarak saklanır.
   - Taksit sayısına tam bölünmeyen tutarlarda kalan kuruşlar deterministik olarak ilk taksite aktarılır; 1 kuruş dahi kaybolmaz.
   - Her taksit hareketi için idempotency anahtarı (`installmentPlanId_installmentNumber_statementPeriod`) kullanılarak mükerrer kayıt oluşması engellenir.

4. **Çift Katmanlı Bildirim Sistemi:**
   - **Yerel Bildirimler (`flutter_local_notifications`):** Kullanıcının dilediği saatte (varsayılan 21:00) ve dilediği günlerde harcama hatırlatıcısı (çevrimdışı çalışabilir).
   - **Firebase Cloud Messaging (FCM):** Takım üyeleri yeni harcama eklediğinde anlık push bildirimi.
   - IANA saat dilimi (`Europe/Istanbul`) ve yaz/kış saati koruması.

5. **Aylık Bütçe ve Zengin Raporlama:**
   - `fl_chart` ile interaktif, renk körlüğü dostu kategori dağılım pasta grafiği.
   - Aylık bütçe gerçekleşme oranı, kalan bütçe ve aşım uyarıları.

6. **Tasarım Sistemi: Emerald & Slate Trust:**
   - Modern Material 3 tabanlı, açık ve koyu tema destekli finans tasarımı.
   - Büyük ve okunaklı tutar girişi (10-15 saniyede harcama ekleme).

---

## 🏗️ Mimari ve Dizin Yapısı

Katmanlı Clean Architecture prensiplerine uygun olarak presentation, application, domain ve data katmanları ayrıştırılmıştır:

```
lib/
├── application/             # Use Case'ler, Servisler ve Riverpod Provider'ları
│   ├── providers/          # Auth, Takım, Harcama, Kart, Taksit, Bütçe Provider'ları
│   └── services/           # Bildirim ve Reconciliation (Senkronizasyon) Servisi
├── core/                   # Ortak yardımcılar, temalar, sabitler ve formatlayıcılar
│   ├── constants/          # AppColors, AppConstants (Kategoriler, Ödeme tipleri)
│   ├── firebase/           # Firebase güvenli başlatma ve kontrol
│   ├── theme/              # Light & Dark ThemeData (Emerald & Slate Trust)
│   └── utils/              # MoneyFormatter, StatementCalculator
├── data/                   # Firestore ve Firebase Auth Repository implementasyonları
│   └── repositories/
├── domain/                 # Değişmez modeller (Entities) ve Repository Arayüzleri
│   ├── entities/           # Expense, CreditCard, InstallmentPlan, Team, Budget, User
│   └── repositories/       # IExpenseRepository, ICardRepository, vb.
└── presentation/           # UI Sayfaları, GoRouter ve Reusable Widget'lar
    ├── navigation/         # AppRouter (StatefulShellRoute - 5 Sekme)
    ├── screens/            # Splash, Auth, Dashboard, Expenses, Cards, Reports, Settings
    └── widgets/            # AppCard, CategoryBadge, PeriodSelector, TeamSelector
```

---

## 🚀 Kurulum ve Çalıştırma

### 1. Gereksinimler
- Flutter SDK `^3.47.5`
- Dart SDK `^3.13.4`
- Node.js `^18.0.0` (Firebase Cloud Functions için)
- Firebase CLI (`npm install -g firebase-tools`)

### 2. Bağımlılıkları Yükleme
```bash
flutter pub get
```

### 3. Statik Kod Analizi ve Testleri Çalıştırma
```bash
flutter analyze
flutter test
```
Tüm birim testleri (kuruş bölme, kesim tarihi, artık yıl, taksit planı ve duman testleri) hatasız çalışır.

### 4. Firebase Kurulumu
1. Firebase Console üzerinden yeni bir proje oluşturun.
2. FlutterFire CLI ile projeyi yapılandırın:
   ```bash
   dart pub global activate flutterfire_cli
   flutterfire configure --project=YOUR_PROJECT_ID
   ```
3. Firestore Güvenlik Kuralları ve İndekslerini Yükleyin:
   ```bash
   firebase deploy --only firestore:rules,firestore:indexes
   ```
4. Cloud Functions'ı Dağıtın:
   ```bash
   cd functions
   npm install
   firebase deploy --only functions
   ```

### 5. Firebase Emulator Suite ile Lokal Geliştirme
İnternet bağlantısı veya canlı Firebase projesi olmadan lokalde test etmek için:
```bash
firebase emulators:start
```
Emulator UI: `http://localhost:4000` adresinde açılır (Auth: 9099, Firestore: 8080, Functions: 5001).

---

## 📚 Dokümantasyon Rehberi

Daha detaylı teknik belgeler `docs/` klasörü altında hazırlanmıştır:
- `docs/technology-decisions.md`: Seçilen paketler, versiyonlar, platform kısıtları ve kurulum notları.
- `docs/architecture.md`: Katmanlı mimari, durum yönetimi ve GoRouter navigasyon akışı.
- `docs/data-model.md`: Firestore koleksiyon şemaları ve composite index tanımları.
- `docs/security-rules.md`: Firestore güvenlik kuralları ve rol bazlı erişim matrisi.
- `docs/installment-and-statement-logic.md`: Kredi kartı kesim günü, artık yıllar, saat sınırları ve idempotent taksit algoritması.
- `docs/notifications.md`: Yerel ve push bildirim mimarisi, izin yönetimi ve zamanlama.
- `docs/design-system.md`: Emerald & Slate Trust tasarım sistemi, renk paletleri ve tipografi.
