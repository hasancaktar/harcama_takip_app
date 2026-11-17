# Kredi Kartı Kesim Tarihi ve Taksit Motoru Mantığı (Installment & Statement Logic)

> **Güncel kurallar (v1.2)** — Bu belgenin geri kalanından önce okunmalıdır:
>
> 1. **Dönem ataması:** Yalnızca *kredi kartı* harcamaları kesim gününe göre ekstre dönemine yazılır.
>    Nakit, banka kartı, havale vb. harcamalar harcamanın yapıldığı **takvim ayına** yazılır
>    (`StatementCalculator.periodForExpense`). Önceki sürüm bunları kesim günü 1 varsayımıyla
>    hesaplıyor, ayın 1'inden sonraki tüm nakit harcamaları bir sonraki aya yazıyordu.
> 2. **Taksitler baştan yazılır (v1.2):** Taksit planı oluşturulduğunda (taksit planı ekranı veya
>    harcama formundaki "Taksit sayısı") **tüm taksitler hemen** kendi ekstre dönemlerine harcama olarak
>    yazılır (`InstallmentPostingService.applyAllPostings`). Böylece gelecek ayların harcama ve rapor
>    ekranları taksitleri önceden gösterir. Bu yüzden takvimde `posted`, "ödendi" anlamına gelmez.
>    - **Ekstreye yansıdı:** taksit `posted` **ve** dönemi içinde bulunulan aydan sonra değil
>      (`InstallmentPlan.isBilledAt`). İlerleme (`billedCountAt`), ödenen (`billedAmountAt`), kalan borç
>      (`remainingAmountAt`) ve sıradaki taksit (`nextInstallmentAt`) bugünün dönemine göre hesaplanır.
>    - **Tamamlanma:** son taksitin dönemi gelince plan tamamlanmış görünür (`displayStatusAt`); istemci
>      senkronu ve gece çalışan Cloud Function planı `completed` olarak kaydeder.
>    - **İptal:** ekstreye henüz yansımamış taksit harcamaları silinir (soft delete) ve takvimde yeniden
>      `upcoming` olur; bu aya kadar yansıyanlar korunur. Plan durumu ve silmeler tek yığında yazılır.
>    - Eski sürümde oluşturulmuş (taksitleri ayı gelince işlenen) planlar aynı hesaplarla doğru görünür;
>      onlar için `applyDuePostings` ve gece fonksiyonu eskisi gibi çalışır.
> 3. **Harcama tarihi:** 1. taksit alışveriş tarihinde, sonrakiler bankanın işlediği kesim tarihinde görünür.
> 4. **Idempotens:** Harcama kimliği `planId_taksitNo_dönem`; istemci ve Cloud Function aynı kuralı
>    (`functions/lib/installments.js`) uygular. İşlenen taksit planda `posted` olarak işaretlenir.
> 5. **Takvim:** `generateSchedule` tüm taksitleri `upcoming` üretir; son ödeme tarihi kesim gününden
>    `paymentDueDaysAfterCutoff` gün sonrasıdır (saat bilgisi olmadan, yaz saati etkisiz).
> 6. **Tutar girişi:** Türkçe biçim esas alınır: nokta binlik, virgül ondalık ayırıcıdır
>    (`1.250` = 1.250 TL, `1.250,50` = 1.250,50 TL, `12.5` = 12,50 TL). Virgülden sonra 3+ hane reddedilir.


Bu doküman, kredi kartı ekstre dönemlerinin hesaplanması, taksit tutarlarının kuruş hassasiyetinde bölünmesi, kenar durumların (Şubat ayı, 30/31 çeken aylar, yıl geçişi) çözümü ve otomatik taksit ekleme/senkronizasyon kurallarını açıklar.

---

## 1. Kredi Kartı Kesim Günü ve Ekstre Dönemi Hesaplama

### 1.1. Tanımlar
- **`cutoffDay` (Kesim Günü):** 1 ile 31 arasında tamsayı.
- **`paymentDueDaysAfterCutoff` (Vade Gün Sayısı):** Kesim tarihinden kaç gün sonra son ödeme tarihi olduğu (örneğin 10 gün).
- **`statementPeriod` (Ekstre Dönemi):** `YYYY-MM` formatında (örneğin `2026-11`).

### 1.2. Ay Sonu Kenar Durumları (Clamping)
Tüm ayların 31 günü yoktur:
- 30 gün çeken aylar: Nisan, Haziran, Eylül, Kasım.
- Şubat: 28 gün (artık yıllarda 29 gün).
- **Kural:** Eğer kartın `cutoffDay` değeri ilgili ayın gün sayısından büyükse, o ayın **son takvim günü** kesim günü kabul edilir.
  - Örnek: `cutoffDay = 31` olan bir kart için:
    - Ocak kesim tarihi: `31 Ocak`
    - Şubat 2026 kesim tarihi: `28 Şubat`
    - Nisan kesim tarihi: `30 Nisan`

### 1.3. Saat Sınırı ve Saat Dilimi (Boundary & Europe/Istanbul)
- Karşılaştırmalar daima kartın ve kullanıcının IANA saat diliminde (varsayılan: `Europe/Istanbul`) yapılır.
- **Kesim Günü Sınırı:** İlgili ayın kesim gününde saat `23:59:59.999` anına kadar yapılan işlemler o ayın ekstresine dahil edilir.
  - Kesim gününden sonra (örneğin ertesi gün 00:00 ve sonrası) yapılan işlemler **bir sonraki ekstre dönemine** aktarılır.
  - *Not:* Eğer işlem tam kesim gününde yapılmışsa mevcut döneme dahil edilir.

### 1.4. Algoritma (Dart Kodu Karşılığı)
```dart
DateTime getActualCutoffDate(int year, int month, int targetDay) {
  // İlgili ayın son gününü bul
  final lastDayOfMonth = DateTime(year, month + 1, 0).day;
  final effectiveDay = targetDay > lastDayOfMonth ? lastDayOfMonth : targetDay;
  return DateTime(year, month, effectiveDay, 23, 59, 59, 999);
}

String resolveStatementPeriod(DateTime transactionDate, int cutoffDay) {
  final year = transactionDate.year;
  final month = transactionDate.month;
  final cutoffDate = getActualCutoffDate(year, month, cutoffDay);

  if (transactionDate.isAfter(cutoffDate)) {
    // Sonraki aya geçer
    final nextMonthDate = DateTime(year, month + 1, 1);
    final formattedMonth = nextMonthDate.month.toString().padLeft(2, '0');
    return '${nextMonthDate.year}-$formattedMonth';
  } else {
    // Mevcut aya aittir
    final formattedMonth = month.toString().padLeft(2, '0');
    return '$year-$formattedMonth';
  }
}
```

---

## 2. Taksit Tutarı Bölme ve Kalan Kuruş Algoritması

Finansal kayıtlarda kuruş kaybı kabul edilemez.

### 2.1. Dağıtım Kuralı
Toplam kuruş tutarı taksit sayısına tam bölünmediğinde (`totalAmountInCents % totalInstallments != 0`), kalan kuruşlar **deterministik olarak ilk taksite** eklenir.

### 2.2. Matematiksel İspat ve Örnek:
- **Örnek 1:** 100,00 TL (10.000 kuruş), 3 taksit:
  - Taban taksit: `10000 ~/ 3 = 3333` kuruş (33,33 TL).
  - Kalan: `10000 % 3 = 1` kuruş.
  - Taksit 1: `3333 + 1 = 3334` kuruş (33,34 TL).
  - Taksit 2: `3333` kuruş (33,33 TL).
  - Taksit 3: `3333` kuruş (33,33 TL).
  - Toplam kontrol: `3334 + 3333 + 3333 = 10000` kuruş (100,00 TL). Tam eşleşme!
- **Örnek 2:** 1000,00 TL (100.000 kuruş), 6 taksit:
  - Taban taksit: `100000 ~/ 6 = 16666` kuruş (166,66 TL).
  - Kalan: `100000 % 6 = 4` kuruş.
  - Taksit 1: `16666 + 4 = 16670` kuruş (166,70 TL).
  - Taksit 2 - 6: her biri `16666` kuruş (166,66 TL).
  - Toplam kontrol: `16670 + (5 * 16666) = 16670 + 83330 = 100000` kuruş. Tam eşleşme!

---

## 3. Otomatik Ekstreye Ekleme ve Idempotency

### 3.1. Benzersiz Anahtar (Idempotency Key)
Aynı taksit hareketinin mükerrer kaydedilmesini engellemek için her harcama kaydının ID'si deterministik olarak türetilir:
`idempotencyKey = "${installmentPlanId}_${installmentNumber}_${statementPeriod}"`

### 3.2. Zamanlanmış İşlem (Cloud Function / Scheduler)
- Her gece saat `00:05`'te (Europe/Istanbul) bir Scheduled Cloud Function tetiklenir.
- Fonksiyon, o gün kesim tarihi gelen kartlara ait aktif taksit planlarının o döneme ait taksit hareketini kontrol eder.
- Eğer ilgili ID'ye sahip harcama kaydı zaten varsa işlem pas geçilir (no-op). Yoksa yeni harcama dokümanı oluşturulur.

### 3.3. İstemci Senkronizasyonu (Client-Side Reconciliation)
- Kullanıcı uygulamayı çevrimdışı modda açtığında veya Cloud Function çalışmamışsa:
  - İstemci, yerel kart kesim tarihlerini kontrol eder.
  - Kesim tarihi geçmiş ancak henüz `expenses` koleksiyonuna düşmemiş taksitler tespit edilir.
  - Aynı idempotency key kullanılarak Firestore Transaction veya batch write ile güvenle eklenir.
  - Böylece sunucu veya istemci kim önce yazarsa yazsın **kesinlikle duplicate oluşmaz**.
