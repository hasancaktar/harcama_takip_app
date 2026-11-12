# Google Play Store ve Sıfır Maliyetli Yayına Alma Rehberi

Bu rehber, **Harcama ve Taksit Takip** uygulamasını Google Play Console hesabınızı ve Firebase'in **100% ücretsiz Spark planını** kullanarak tek kuruş ek masraf yapmadan canlıya alma adımlarını açıklar.

---

## 📌 Sıfır Maliyet Mimarisi Özeti
- **Google Play Console Hesabı:** Zaten mevcut (ek ücret yok).
- **Backend & Veritabanı:** Firebase Spark Planı (Kredi kartı gerekmez, aylık 50.000 kullanıcı, günlük 50.000 okuma / 20.000 yazma tamamen ücretsizdir).
- **Sunucu & Cron:** Uygulamamız sunucu maliyetine girmemek için istemci taraflı otomatik reconciliation (`InstallmentReconciliationService`) ve cihaz yerel bildirimleri (`flutter_local_notifications`) kullanır.
- **Gizlilik Politikası:** Hazırladığımız `docs/privacy-policy.md` dosyası GitHub Pages üzerinden 100% ücretsiz barındırılır.

---

## 1. Adım: Firebase Projesini 0 TL ile Yapılandırma

1. **[Firebase Console](https://console.firebase.google.com/)** adresine Google hesabınızla giriş yapın.
2. **"Proje Ekle" (Add project)** butonuna tıklayın:
   - Proje adı girin (Örn: `harcama-takip-app`).
   - Google Analytics'i etkinleştirebilirsiniz (Ücretsizdir).
   - "Spark (Ücretsiz)" planda kaldığınızdan emin olun (kredi kartı bilgisi girilmez).
3. **Servisleri Etkinleştirin:**
   - **Authentication:** Sol menüden *Authentication* > *Başlayın* > Oturum açma yöntemi olarak **E-posta/Şifre** ve **Google**'ı aktif edin.
   - **Cloud Firestore:** Sol menüden *Firestore Database* > *Veritabanı Oluştur* > Konum olarak `europe-west3` (Frankfurt) veya `europe-west1` seçin > Kurallar adımında projemizdeki kuralları yükleyeceğiz.
   - **Storage (Opsiyonel):** Makbuz yüklemeleri için *Storage* > *Başlayın* deyin.
4. **Projeyi Flutter ile Eşleştirin:**
   Terminalde proje klasöründe (`d:\Hasan\Proje\harcama_takip`) şu komutu çalıştırın:
   ```bash
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```
   *(Listeden az önce oluşturduğunuz Firebase projesini seçin; Android ve Web platformlarını işaretleyin).*
5. **Güvenlik Kurallarını ve İndeksleri Yükleyin:**
   ```bash
   firebase deploy --only firestore:rules,firestore:indexes
   ```

---

## 2. Adım: Android İmzalama Anahtarı (Keystore) Oluşturma

Google Play'e yüklenecek olan uygulamanın şifreli bir imza anahtarına (Upload Keystore) sahip olması gerekir.

1. Terminalde (PowerShell) şu komutu çalıştırarak anahtarınızı üretin:
   ```powershell
   keytool -genkey -v -keystore android/app/upload-keystore.jks -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```
   *(Sizden bir şifre belirlemeniz ve ad-soyad gibi bilgileri girmeniz istenecektir. Belirlediğiniz şifreyi bir yere kaydedin).*

2. `android/key.properties` dosyasını oluşturun:
   `android/key.properties.example` dosyasını `android/key.properties` olarak adlandırın ve içine şifrelerinizi yazın:
   ```properties
   storePassword=BURAYA_BELIRLEDIGINIZ_SIFRE
   keyPassword=BURAYA_BELIRLEDIGINIZ_SIFRE
   keyAlias=upload
   storeFile=../app/upload-keystore.jks
   ```
   *(Bu dosya ve .jks anahtarınız `.gitignore` tarafından otomatik korunur, asla GitHub'a gitmez).*

3. **Google Sign-In için SHA-1 Parmak İzinizi Alın:**
   ```powershell
   keytool -list -v -keystore android/app/upload-keystore.jks -alias upload
   ```
   Çıkan `SHA1:` değerini kopyalayın. Firebase Console > Proje Ayarları > Genel > Android Uygulamanız > **"Parmak İzi Ekle" (Add fingerprint)** alanına yapıştırın. (Bu işlem olmadan Google ile giriş çalışmaz).

---

## 3. Adım: Google Play İçin App Bundle (`.aab`) Derleme

Google Play artık düz APK yerine optimize edilmiş `.aab` (Android App Bundle) formatı ister.

Terminalde şu komutu çalıştırın:
```bash
flutter build appbundle --release
```

Derleme tamamlandığında dosyanız şurada hazır olacaktır:
👉 `build\app\outputs\bundle\release\app-release.aab`

---

## 4. Adım: Google Play Console'da Yayına Alma

1. **[Google Play Console](https://play.google.com/console)**'a gidin.
2. **"Uygulama oluştur" (Create app)** butonuna tıklayın:
   - Uygulama adı: **Harcama ve Taksit Takip**
   - Varsayılan dil: **Türkçe - tr-TR**
   - Uygulama mı, oyun mu?: **Uygulama**
   - Ücretsiz mi, ücretli mi?: **Ücretsiz**
3. **Uygulama Kurulumu (App Setup) Görevlerini Tamamlayın:**
   - **Gizlilik Politikası (Privacy Policy):**
     Ücretsiz Gizlilik Politikası URL'niz:
     `https://raw.githubusercontent.com/hasancaktar/harcama_takip_app/main/docs/privacy-policy.md`
     *(Google bu raw GitHub markdown bağlantısını doğrudan kabul eder).*
   - **Uygulama Erişimi:** "Tüm işlevler özel erişim olmadan kullanılabilir" veya test hesabı girişi tanımlayın.
   - **Reklamlar:** "Hayır, uygulamamda reklam yok".
   - **İçerik Derecelendirmesi (Content Rating):** Anketi doldurun (Şiddet yok, kumar yok vb. -> 3+ derecesi alır).
   - **Hedef Kitle:** 18 yaş ve üzeri.
   - **Finansal Özellikler:** "Kişisel finans yönetimi / Bütçe takibi".
   - **Veri Güvenliği (Data Safety):**
     - Toplanan veriler: Ad, E-posta, Kullanıcı Kimliği, Harcama ve Finans Kayıtları.
     - Veriler şifreli mi iletiliyor?: **Evet (HTTPS/TLS)**.
     - Kullanıcılar verilerinin silinmesini talep edebilir mi?: **Evet** (Uygulama içindeki "Hesabı Sil" butonu).
4. **Ana Mağaza Girişi (Store Listing):**
   - **Kısa Açıklama:** Aile bütçesi, kredi kartı ekstreleri ve taksit takip uygulaması.
   - **Tam Açıklama:** [README.md](file:///d:/Hasan/Proje/harcama_takip/README.md) içerisindeki özellikleri kopyalayabilirsiniz.
   - **Grafik Varlıkları:**
     - Uygulama simgesi (512x512 PNG).
     - Özellik grafiği (1024x500 PNG).
     - En az 2 adet telefon ekran görüntüsü.
5. **Sürümü Yükleyin ve Gönderin:**
   - Sol menüden **Üretim (Production)** > **Yeni sürüm oluştur**'a tıklayın.
   - `build\app\outputs\bundle\release\app-release.aab` dosyasını sürükleyip bırakın.
   - Sürüm notu yazın (Örn: *İlk sürüm: Harcama, taksit ve kart takibi yayında*).
   - **İncelemeye Gönder** butonuna tıklayın!

Google incelemesi genellikle 24-48 saat içinde tamamlanır ve uygulamanız Google Play Store'da tüm dünyada ücretsiz olarak yayına girer.

---

## 5. Adım: Web Sürümünü Canlıya Alma (Bonus: Firebase Hosting - 0 TL)

Uygulamanızı dileyen kullanıcıların tarayıcıdan da kullanabilmesi için:

```bash
# Web derlemesi alın
flutter build web --release

# Firebase hosting ile canlıya alın
firebase deploy --only hosting
```

Anında `https://harcama-takip-app.web.app` adresinde ücretsiz SSL sertifikalı olarak yayına girer.
