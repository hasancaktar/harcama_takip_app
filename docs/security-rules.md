# Firestore Güvenlik Kuralları

Kaynak: [`firestore.rules`](../firestore.rules) · Testler: [`firestore-tests/rules.test.js`](../firestore-tests/rules.test.js)

## İlkeler

1. **Varsayılan kapalı.** Açıkça izin verilmeyen hiçbir okuma/yazma yapılamaz.
2. **E-posta doğrulaması zorunlu.** `users/{uid}` profil belgesi dışındaki tüm koleksiyonlar
   `request.auth.token.email_verified == true` ister. Profil, kayıt akışında doğrulamadan önce
   oluşturulabilsin diye yalnızca sahibine açıktır.
3. **Kişisel veri yalnızca sahibine** (`ownerUid == request.auth.uid`).
4. **Takım verisi yalnızca takım üyelerine.** Üyelik, `teams/{teamId}.memberUids` listesinden
   `get()` ile doğrulanır.
5. **Şema doğrulaması.** Tutar tamsayı kuruş ve pozitif, başlık ≤ 100, not ≤ 500 karakter, dönem
   `YYYY-MM`, ödeme yöntemi izinli listede, kart son 4 hanesi yalnızca rakam, kesim günü 1–31.
6. **Sahiplik devredilemez.** Güncellemelerde `ownerUid` değiştirilemez.
7. **Yönetici yetkisi sunucuda denetlenir.** `isAdmin()`: e-postası doğrulanmış ve adresi
   yönetici adresiyle birebir aynı olan hesap. Arayüzdeki gizleme güvenlik sayılmaz; aynı
   denetim Cloud Functions'ta tekrarlanır ([admin-panel.md](admin-panel.md)).

## Koleksiyonlar

| Koleksiyon | Okuma | Yazma |
|---|---|---|
| `users/{uid}` | Kendisi; yönetici (kullanıcı listesi için) | Yalnızca kendisi (doğrulama gerekmez). `pushEnabled` bool, `language` yalnızca `tr`/`en` |
| `teams/{id}` | Üyeler | Oluşturma: kendini sahip ve tek üye olarak. Güncelleme: sahip (ad/renk/arşiv, üye çıkarma), davetli (yalnızca kendini ekleme), üye (yalnızca kendini çıkarma). Silme yok (arşiv). |
| `teams/{id}/members/{uid}` | Üyeler | Oluşturma: takımı kuran sahip veya kendi e-postasına ait geçerli daveti kullanan kişi. Silme: kendisi (sahip hariç) veya sahip. |
| `teams/{id}/invites/{kod}` | Sahip veya davet edilen e-posta | Oluşturma: yalnızca sahip, en fazla 8 gün geçerli, rol `member`. Güncelleme: davetli kabul/ret, sahip iptal. |
| `{path=**}/invites` (collectionGroup) | Yalnızca `invitedEmail == token.email` | — |
| `expenses` | Sahip; takım harcamasıysa takım üyeleri | Sahip; takım harcaması yalnızca üyesi olunan takıma |
| `creditCards` | Sahip; paylaşılan kartlar için takım üyeleri | Yalnızca sahip |
| `installmentPlans` | Sahip; takım planıysa üyeler | Yalnızca sahip |
| `budgets` | Sahip; takım bütçesiyse üyeler | Kanonik kimlikle: `user_{uid}_{dönem}` veya `team_{teamId}_{dönem}` |
| `categories/{id}` | Doğrulanmış herkes | Yalnızca yönetici; şema doğrulamalı (ad ≤ 40, renk `#RRGGBB`, sıra 0–1000). **Silme yok** (`isDeleted` ile işaretlenir) |
| `appConfig/dailyReminder` | Yalnızca yönetici | Yalnızca yönetici; saat 0–23, dakika 0–59, metin sınırları. `lastSentDate` istemciden değiştirilemez |
| `notificationCampaigns/{id}` | Yalnızca yönetici | Yönetici yalnızca **oluşturur**: `type: manual`, `status: queued`, `createdBy == uid`, sunucu zamanı. Güncelleme ve silme yok; sonucu Cloud Function (Admin SDK) yazar |
| `adminLogs/{id}` | Yalnızca yönetici | Yönetici yalnızca **ekler** (`adminUid == uid`, sunucu zamanı). Güncelleme ve silme yok |

## Önceki sürümde kapatılan açıklar

- `visibility == "team"` olan **tüm** harcamalar, planlar ve bütçeler, takım üyeliğine bakılmadan
  oturum açmış **herkese** okunabiliyor ve güncellenebiliyordu.
- `budgets` için `request.resource.data.visibility == "team"` yazan herkes başkasının bütçesini
  oluşturup üzerine yazabiliyordu.
- `teams/{id}/members` ve `invites` herkese okunur/yazılırdı: herhangi bir kullanıcı kendini
  herhangi bir takıma ekleyebiliyor, tüm davetleri (e-posta adresleriyle) listeleyebiliyordu.
- Takım üyeleri `ownerUid` ve `memberUids` alanlarını değiştirerek sahipliği ele geçirebiliyordu.
- `users/{uid}` profilleri (e-posta adresleri dahil) oturum açmış herkese açıktı.
- E-posta doğrulaması hiçbir yerde zorunlu değildi.

## Test

```bash
cd firestore-tests && npm install && npm test
```

40 test; doğrulanmamış hesap, sahiplik, takım üyeliği, davet (geçerli/süresi dolmuş/başka e-posta),
şema sınırları, sorgu düzeyi kuralları ve yönetim yetkisi kapsanır. Yönetim testleri: normal
kullanıcının yazamaması, e-postası doğrulanmamış yöneticinin ve benzer adresli hesabın yetkisiz
olması, bildirim sonuç alanlarının ve `lastSentDate` alanının istemciden yazılamaması, işlem
kayıtlarının değiştirilememesi.
