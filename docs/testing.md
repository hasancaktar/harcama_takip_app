# Test Rehberi

| Katman | Komut | Kapsam |
|---|---|---|
| Statik analiz | `flutter analyze` | Sıkılaştırılmış lint kuralları (kullanımdan kalkmış API ve async-context uyarıları artık gizlenmiyor) |
| Birim | `flutter test test/unit` | Para ayrıştırma/biçimleme, ekstre ve dönem hesapları, taksit işleme politikası, varlık ayrıştırma, istatistik, bütçe eşikleri, doğrulayıcılar, hata mesajları, yönlendirme (e-posta doğrulama) kuralları |
| Akış (widget) | `flutter test test/widget` | Gerçek router + ekranlar, sahte depolarla: giriş doğrulaması, kayıt → doğrulama → özet, nakit harcama dönemi, bütçe kaydı, davet kabulü, duyarlı gezinme |
| Güvenlik kuralları | `cd firestore-tests && npm install && npm test` | Firestore Emulator üzerinde 32 senaryo |
| Cloud Functions | `cd functions && npm test` | Taksit işleme saf mantığı (Node test runner) |

Sahte depolar: [`test/helpers/fakes.dart`](../test/helpers/fakes.dart). Tüm Firebase bağımlılıkları
Riverpod sağlayıcıları üzerinden enjekte edildiği için testlerde Firebase gerekmez.

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
