# Bildirim Sistemi Mimarisi (Notifications Guide)

Bu doküman, yerel bildirimler (Local Notifications) ve Firebase Cloud Messaging (FCM) altyapısını, zamanlanmış günlük hatırlatma mantığını, izin yönetimini ve çoklu cihaz senkronizasyonunu tanımlar.

---

## 1. İki Katmanlı Bildirim Mimarisi

```
┌────────────────────────────────────────────────────────┐
│                   BİLDİRİM SİSTEMİ                     │
├──────────────────────────┬─────────────────────────────┤
│   1. YEREL BİLDİRİMLER   │    2. FIREBASE PUSH (FCM)   │
│ (flutter_local_notif)    │    (firebase_messaging)     │
├──────────────────────────┼─────────────────────────────┤
│ • Günlük Harcama Girişi  │ • Takıma Yeni Üye Katılımı  │
│   Hatırlatıcısı (Çevrim- │ • Takım Harcaması Eklendi/  │
│   dışı çalışabilir)      │   Güncellendi               │
│ • Yaklaşan Kart Kesim    │ • Bütçe Aşım Uyarısı        │
│   Tarihi Hatırlatıcısı   │ • Taksit Planı Tamamlandı   │
│ • Son Ödeme Vadesi       │ • Davet Kabul Edildi        │
└──────────────────────────┴─────────────────────────────┘
```

---

## 2. Günlük Harcama Hatırlatması Mantığı

1. **Kullanıcı Ayarı:**
   - Kullanıcı dilediği saatte (varsayılan: `21:00`) ve dilediği günlerde bildirim alma seçeneğine sahiptir.
   - Takım üyeliğinden tamamen bağımsızdır; bireysel kullanıcılar da faydalanır.
2. **Saat Dilimi Desteği:**
   - Bildirimler `timezone` ve `flutter_timezone` paketleriyle cihazın IANA saat dilimine (`Europe/Istanbul`) kilitlenir.
   - Yaz/kış saati veya saat dilimi değiştiğinde yerel bildirimler yeniden planlanır (`rescheduleLocalReminders()`).
3. **Deep Linking:**
   - Bildirime tıklandığında doğrudan `/expenses/add` (Hızlı Harcama Ekle) veya `/dashboard` ekranı açılır.

---

## 3. FCM ve Çoklu Cihaz Stratejisi

- Her kullanıcı cihazı `users/{uid}/devices/{deviceId}` altında FCM token'ı ile kaydedilir.
- Kullanıcı logout olduğunda token silinir.
- Cloud Functions takım etkinliklerinde (yeni harcama, üye katılımı) ilgili takım üyelerinin aktif cihazlarına FCM bildirimi gönderir. İşlemi yapan kullanıcının kendi cihazına bildirim gönderilmez (self-suppression).

---

## 4. İzin Yönetimi (Android & iOS)

- **Android 13+ (API 33+):** `POST_NOTIFICATIONS` runtime izni istenir.
- **Android Alarmlar:** `SCHEDULE_EXACT_ALARM` veya `USE_EXACT_ALARM` izni ekstre ve günlük hatırlatıcılar için tanımlanır.
- **iOS:** `UNUserNotificationCenter` ile alert, badge ve sound izinleri talep edilir.
- Kullanıcı bildirim iznini reddetmişse, ayarlar ekranında kırmızı bir uyarı çubuğu ve doğrudan sistem ayarlarına yönlendiren buton gösterilir.
