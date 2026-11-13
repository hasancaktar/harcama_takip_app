# Backend ve API Yayınlama Rehberi (Step-by-Step Backend Guide)

Bu rehber, **Harcama ve Taksit Takip** uygulamasının backend altyapısını, veritabanı servislerini ve HTTP API'lerini canlıya nasıl alacağınızı adım adım açıklar.

---

## 💡 1. Firebase Mimarisi: "Neden Ayrı Bir Sunucu Kiralamıyorsunuz?"

Geleneksel mimarilerde (Node.js/Express, Python/Django vb.) bir Linux sunucu (VPS) kiralar, Nginx kurar, port açar ve REST API yazarsınız. 

**Firebase (Serverless / BaaS) mimarisinde ise sunucu bakımı tamamen ortadan kalkar:**
- **Kimlik Doğrulama API'niz:** `Firebase Authentication` (Kullanıcı kaydı, şifre sıfırlama, JWT token üretimi).
- **Veritabanı API'niz:** `Cloud Firestore` (Flutter uygulaması doğrudan şifreli gRPC/HTTPS protokolüyle bağlanır).
- **API Middleware & Güvenlik Katmanı:** `firestore.rules` (Yetkisiz hiç kimse başkasının verisini okuyamaz veya değiştiremez).
- **Özel HTTP REST API & Arka Plan Görevleri:** `Firebase Cloud Functions` (`functions/index.js`).

---

## 🚀 2. Backend'i Canlıya Alma: Adım Adım

### 1. Adım: Firebase CLI Girişi Yapın
Terminalde (PowerShell) Firebase CLI hesabınıza giriş yapın:
```bash
firebase login
```
*(Tarayıcınız açılacak; Google hesabınızı seçip "İzin Ver"e tıklayın).*

---

### 2. Adım: Firebase Console'da Projenizi Açın
1. **[https://console.firebase.google.com/](https://console.firebase.google.com/)** adresine gidin.
2. **"Proje Ekle" (Add project)** butonuna tıklayın.
   - Proje adı belirleyin (Örn: `harcama-takip-backend`).
   - "Spark (Ücretsiz)" planda başlayın (kredi kartı istemez).
3. Sol menüden şu 2 servisi açın:
   - **Authentication:** *Oturum Açma Yöntemi* > **E-posta/Şifre** ve **Google**'ı etkinleştirin.
   - **Firestore Database:** *Veritabanı Oluştur* > Konum olarak `europe-west3` (Frankfurt) veya `europe-west1` seçin.

---

### 3. Adım: Güvenlik Kurallarını ve API İndekslerini Yayına Alın
Proje klasörünüzde (`d:\Hasan\Proje\harcama_takip`) hazırladığımız Firestore kurallarını ve indekslerini buluta göndermek için tek bir komut yeterlidir:
```bash
firebase deploy --only firestore:rules,firestore:indexes
```
✅ **Bu komutla birlikte veritabanı API'niz ve güvenlik duvarınız (RBAC kuralları) anında canlıya geçer.**

---

### 4. Adım: Flutter Mobil Uygulamasını Backend'e Bağlayın
Uygulamanın bu canlı backend ile konuşabilmesi için yapılandırma dosyasını otomatik üretin:
```bash
dart pub global activate flutterfire_cli
flutterfire configure
```
- Ekranda çıkan listeden az önce oluşturduğunuz Firebase projesini seçin.
- Platformlar olarak `android` ve `web`'i işaretleyin (boşluk tuşu ile seçilir, Enter ile onaylanır).
- Bu işlem `lib/firebase_options.dart` dosyasını otomatik üreterek mobil uygulamanızı canlı backend'e bağlar.

---

## 🌐 3. Özel HTTP REST API ve Cloud Functions'ı Açma

Eğer dış sistemlerden veya tarayıcıdan çağrılabilecek HTTP REST API endpoint'leri (`GET /health`, `POST /sync-installments`) ve zamanlanmış gece cron'larını çalıştırmak isterseniz:

### 1. Bağımlılıkları Yükleyin:
```bash
cd functions
npm install
cd ..
```

### 2. Fonksiyonları ve REST API'yi Canlıya Gönderin:
```bash
firebase deploy --only functions
```

### 3. Canlı API Endpoint'iniz Hazır:
Deploy bittiğinde terminal size canlı HTTP URL'inizi verecektir:
```text
✔ functions[api(us-central1)]: Successful create operation.
Function URL (api): https://us-central1-YOUR_PROJECT_ID.cloudfunctions.net/api
```

Artık API'niz dünyaya açıktır:
- **Sağlık Kontrolü:** `GET https://us-central1-YOUR_PROJECT_ID.cloudfunctions.net/api/health`
- **Taksit Tetikleme:** `POST https://us-central1-YOUR_PROJECT_ID.cloudfunctions.net/api/sync-installments`

---

## 💰 4. 0 TL (Sıfır Masraf) Güvencesi: Hangi Yolu Seçmelisiniz?

İki seçeneğiniz bulunmaktadır:

### Seçenek A (Tavsiye Edilen - Kredi Kartsız, %100 Ücretsiz Spark Planı):
- Yalnızca **Firestore + Authentication + Security Rules** kullanılır (`firebase deploy --only firestore`).
- Kredi kartı eklemenize **kesinlikle gerek yoktur**.
- Geliştirdiğimiz [`InstallmentReconciliationService`](../lib/application/services/installment_reconciliation_service.dart) ve [`NotificationService`](../lib/application/services/notification_service.dart) motorları sayesinde sunucu/cron fonksiyonlarına ihtiyaç duymadan uygulama içinde otomatik ve ücretsiz çalışır.

### Seçenek B (Cloud Functions ile REST API - Blaze Planı):
- Google Cloud hesabınıza bir banka/kredi kartı tanımlarsınız.
- Firebase aylık **ilk 2 milyon API çağrısını tamamen ücretsiz** verir. Harcama takip gibi bir uygulamada ayda 2 milyon çağrıya ulaşmak neredeyse imkansız olduğundan **faturanız yine 0 TL** gelir.
