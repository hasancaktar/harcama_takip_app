# Uygulama Mimarisi (Architecture Guide)

## 1. Mimari Genel Bakış

**Harcama ve Taksit Takip Uygulaması**, Domain-Driven Design (DDD) ve Clean Architecture prensiplerine göre katmanlandırılmış, modüler ve test edilebilir bir yapıya sahiptir.

```
┌─────────────────────────────────────────────────────────────┐
│                    Presentation Katmanı                     │
│  (UI Pages, Widgets, Riverpod Controllers, State Notifiers) │
└──────────────────────────────┬──────────────────────────────┘
                               │ UI State & Kullanıcı Aksiyonları
┌──────────────────────────────▼──────────────────────────────┐
│                    Application Katmanı                      │
│     (Use Cases, Facade Services, InstallmentEngine,         │
│          StatementCalculator, NotificationCoordinator)      │
└──────────────────────────────┬──────────────────────────────┘
                               │ Domain Mantığı & Kurallar
┌──────────────────────────────▼──────────────────────────────┐
│                      Domain Katmanı                         │
│  (Entities: Expense, Card, InstallmentPlan, Team, Budget;    │
│   Value Objects: Money, StatementPeriod; Repository Interfaces)
└──────────────────────────────┬──────────────────────────────┘
                               │ Veri Sözleşmeleri
┌──────────────────────────────▼──────────────────────────────┐
│                  Data ve Altyapı Katmanı                    │
│   (Firestore Repositories, Firebase Auth, Firebase Storage, │
│    Local Notification Service, Local Cache, Cloud Functions)│
└─────────────────────────────────────────────────────────────┘
```

---

## 2. Katmanların Sorumlulukları

### A. Presentation Katmanı (`lib/presentation/`)
- Ekranlar (`screens/`), yeniden kullanılabilir bileşenler (`widgets/`), tema ve arayüz yardımcıları.
- Durum yönetimi için **Riverpod Notifier/AsyncNotifier** kullanılır.
- UI bileşenleri yalnızca state'i dinler ve intent bildirir; asla doğrudan Firestore sorgusu çalıştırmaz.
- Tüm formlar doğrulanır ve hata/yükleme durumları standart bileşenlerle (`LoadingIndicator`, `AppErrorWidget`, `EmptyStateWidget`) gösterilir.

### B. Application Katmanı (`lib/application/`)
- İş senaryolarını (Use Cases) orkestre eder.
- Örnek servisler:
  - `ExpenseService`: Harcama oluşturma, takım/bireysel ayrımı, kategori ilişkilendirme.
  - `InstallmentEngine`: Taksit planını kuruş hassasiyetinde taksit hareketlerine bölme ve idempotency anahtarı üretme.
  - `StatementCalculator`: Kredi kartı harcama tarihi ile kesim gününü karşılaştırıp doğru ekstre dönemini belirleme (28/29/30/31 gün ve yıl atlama korumalı).
  - `TeamService`: Takım oluşturma, üye davet etme, yetki doğrulama.
  - `NotificationCoordinator`: FCM ve yerel bildirimleri zamanlama ve senkronize etme.

### C. Domain Katmanı (`lib/domain/`)
- İş kurallarının kalbidir; Flutter ve dış kütüphanelerden bağımsızdır.
- Modeller değişmezdir (`@immutable`).
- Depo arayüzleri (`IExpenseRepository`, `ICardRepository`, `ITeamRepository`, `IInstallmentRepository`, `IBudgetRepository`, `IUserRepository`) burada tanımlanır.
- Para değerleri `int amountInCents` olarak tutulur.

### D. Data Katmanı (`lib/data/`)
- Domain arayüzlerinin somut sınıflarını (implementations) içerir:
  - `FirestoreExpenseRepository`
  - `FirestoreCardRepository`
  - `FirestoreTeamRepository`
  - `FirestoreInstallmentRepository`
  - `FirebaseAuthRepository`
- DTO (Data Transfer Object) ve Firestore serileştirme/deserileştirme kodları bu katmandadır.
- Firestore offline persistence aktif tutulur.

### E. Core Katmanı (`lib/core/`)
- Uygulama çapında paylaşılan sabitler, formatlayıcılar, tema tanımları, hata sınıfları (`Failure`, `AppException`), network/bağlantı izleyicileri ve yardımcı fonksiyonlar.

---

## 3. Durum Yönetimi (Riverpod Akışı)

1. **State:** Immutable Dart sınıfları ile temsil edilir.
2. **Provider Yapısı:**
   - `authRepositoryProvider`: Auth işlemleri.
   - `currentAuthUserProvider`: Giriş yapmış kullanıcının Stream'i.
   - `userProfileProvider`: Firestore'daki kullanıcı profili stream'i.
   - `activeTeamProvider`: Kullanıcının o anda seçili takımı veya `null` (Bireysel Mod).
   - `expensesStreamProvider(filter)`: Seçili ay, takım ve görünürlüğe göre filtreli Firestore stream'i.
   - `installmentPlansProvider`: Aktif taksit planları.
   - `creditCardsProvider`: Tanımlı kredi kartları.
   - `monthlyReportProvider(period)`: Seçili ayın harcama, taksit ve bütçe özetleri.

---

## 4. Navigasyon (GoRouter)

- Uygulama rotaları `AppRouter` altında tanımlıdır.
- `StatefulShellRoute.indexedStack` kullanılarak alt gezinme çubuğu (Bottom Navigation Bar) durumunu korur:
  - Tab 1: **Özet / Dashboard** (`/dashboard`)
  - Tab 2: **Harcamalar** (`/expenses`)
  - Tab 3: **Kartlar & Taksitler** (`/cards-installments`)
  - Tab 4: **Raporlar** (`/reports`)
  - Tab 5: **Ayarlar / Takım** (`/settings`)
- Yetkilendirme yönlendirmesi (`redirect`): Kullanıcı oturum açmamışsa otomatik olarak `/login` rotasına yönlendirilir; oturum açtığında son kalınan ekrana döner.
