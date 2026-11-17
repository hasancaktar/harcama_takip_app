# Test Rehberi

| Katman | Komut | Kapsam |
|---|---|---|
| Statik analiz | `flutter analyze` | Sıkılaştırılmış lint kuralları (kullanımdan kalkmış API ve async-context uyarıları artık gizlenmiyor) |
| Birim | `flutter test test/unit` | Para ayrıştırma/biçimleme, ekstre ve dönem hesapları, taksit işleme politikası, varlık ayrıştırma, istatistik, bütçe eşikleri, doğrulayıcılar, hata mesajları, yönlendirme (e-posta doğrulama) kuralları |
| Çeviri | `flutter test test/unit/translations_test.dart` | Koddaki her metnin İngilizce karşılığı, kullanılmayan anahtar, yer tutucu uyumu, dil değiştirme ([localization.md](localization.md)) |
| Akış (widget) | `flutter test test/widget/app_flow_test.dart` | Gerçek router + ekranlar, sahte depolarla: giriş doğrulaması, kayıt → doğrulama → özet, nakit harcama dönemi, bütçe kaydı, davet kabulü, duyarlı gezinme |
| Yönetim ve dil (widget) | `flutter test test/widget/admin_and_locale_test.dart` | İngilizce arayüz, dilin anında değişmesi ve saklanması, yönetim paneline erişim (normal kullanıcı, doğrulanmamış yönetici, yönetici), bildirim gönderme onayı, kategori silme/geri yükleme |
| Yerleşim (widget) | `flutter test test/widget/responsive_layout_test.dart` | 33 ekranın tamamı 7 ekran boyutunda ve iki dilde açılır; taşma veya çizim hatası veren ekran dosya/satır ile raporlanır. Boş veri, 1.3x yazı boyutu ve ekran döndürme (durum korunur) dahil |
| Güvenlik kuralları | `cd firestore-tests && npm install && npm test` | Firestore Emulator üzerinde 42 senaryo (8'i yönetim yetkisi); JDK 21+ gerekir |
| Cloud Functions | `cd functions && npm test` | Taksit işleme ve bildirim saf mantığı: yönetici denetimi, saat dilimi, günde bir kez gönderim, alıcı seçimi, dil (Node test runner) |

Sahte depolar: [`test/helpers/fakes.dart`](../test/helpers/fakes.dart). Tüm Firebase bağımlılıkları
Riverpod sağlayıcıları üzerinden enjekte edildiği için testlerde Firebase gerekmez.

Yerleşim testi, test yazı tipinin gerçek yazı tiplerinden belirgin biçimde geniş olması
nedeniyle ihtiyatlıdır: testte sığan metin gerçek cihazda da sığar. Yeni bir ekran eklediğinizde
yolunu `responsive_layout_test.dart` içindeki `_signedInRoutes` listesine ekleyin.

Sistemdeki varsayılan Java 21'den eskiyse kural testleri için geçici olarak Android Studio'nun
JDK'sını kullanabilirsiniz (PowerShell):

```powershell
$env:JAVA_HOME='C:\Program Files\Android\Android Studio\jbr'; $env:Path="$env:JAVA_HOME\bin;$env:Path"; npm test
```

## Uçtan uca (E2E) — yerel emülatörlerle

Hiçbir istek canlı projeye gitmez.

1. Web derlemesini emülatör moduyla oluşturun:

   ```bash
   flutter build web --release --dart-define=USE_FIREBASE_EMULATOR=true
   ```

2. Auth + Firestore + Hosting emülatörlerini başlatın (JDK 21+):

   ```bash
   firebase emulators:start --only auth,firestore,hosting --project harcama-takip-app-7ff66
   ```

3. `http://localhost:5000` adresini açın. Doğrulama bağlantıları e-posta yerine emülatöre düşer:

   ```bash
   curl http://127.0.0.1:9099/emulator/v1/projects/harcama-takip-app-7ff66/oobCodes
   ```

   Listedeki `oobLink` adresini açmak e-postayı doğrular.

Emülatör modunda web'de oturum bellekte tutulur (sayfa yenilenince çıkış yapılır). Bu bilinçli bir
tercihtir: kalıcı oturum, FlutterFire'ın emülatöre bağlanmadan önce oturumu canlı sunucuda
doğrulamaya çalışmasına ve isteklerin canlı projeye gitmesine yol açıyordu.

### Emülatör test hesapları (yalnızca yerel emülatör)

| Rol | E-posta | Şifre |
|---|---|---|
| Takım sahibi | `ayse.e2e@example.test` | `E2eDeneme2026` |
| Davet edilen üye | `mehmet.e2e@example.test` | `E2eDeneme2026` |

Bu hesaplar yalnızca emülatörde oluşturulur; emülatör kapatıldığında silinir.

### Doğrulanan senaryolar (2026-11-16)

- Kayıt formu doğrulaması, gizlilik onayı zorunluluğu, kayıt → doğrulama ekranı
- Doğrulanmamış oturumla korumalı sayfaya derin bağlantı → engellendi
- Doğrulama bağlantısı sonrası otomatik geçiş (yoklama + ID token yenileme)
- Kart ekleme (kural şema doğrulamasından geçti), sonraki kesim/son ödeme hesabı
- Kesimden sonra kartlı harcama → sonraki ay ekstresi; nakit harcama → içinde bulunulan ay
- Geriye dönük taksit planı: vadesi gelmiş 2 taksit atomik olarak işlendi
- Bütçe kaydı (kanonik kimlik) ve aşım gösterimi
- Takım oluşturma, e-postaya bağlı davet kodu, ikinci kullanıcının daveti görmesi ve katılması
- Takım harcamasının diğer üye tarafından görülmesi; kişisel verilerin izolasyonu
- 1280 px masaüstü (yan gezinme rayı) ve 390 px mobil (alt çubuk) yerleşimleri
