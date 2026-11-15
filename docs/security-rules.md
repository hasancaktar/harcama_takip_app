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

## Koleksiyonlar

| Koleksiyon | Okuma | Yazma |
|---|---|---|
| `users/{uid}` | Yalnızca kendisi | Yalnızca kendisi (doğrulama gerekmez) |
| `teams/{id}` | Üyeler | Oluşturma: kendini sahip ve tek üye olarak. Güncelleme: sahip (ad/renk/arşiv, üye çıkarma), davetli (yalnızca kendini ekleme), üye (yalnızca kendini çıkarma). Silme yok (arşiv). |
| `teams/{id}/members/{uid}` | Üyeler | Oluşturma: takımı kuran sahip veya kendi e-postasına ait geçerli daveti kullanan kişi. Silme: kendisi (sahip hariç) veya sahip. |
| `teams/{id}/invites/{kod}` | Sahip veya davet edilen e-posta | Oluşturma: yalnızca sahip, en fazla 8 gün geçerli, rol `member`. Güncelleme: davetli kabul/ret, sahip iptal. |
| `{path=**}/invites` (collectionGroup) | Yalnızca `invitedEmail == token.email` | — |
| `expenses` | Sahip; takım harcamasıysa takım üyeleri | Sahip; takım harcaması yalnızca üyesi olunan takıma |
| `creditCards` | Sahip; paylaşılan kartlar için takım üyeleri | Yalnızca sahip |
| `installmentPlans` | Sahip; takım planıysa üyeler | Yalnızca sahip |
| `budgets` | Sahip; takım bütçesiyse üyeler | Kanonik kimlikle: `user_{uid}_{dönem}` veya `team_{teamId}_{dönem}` |

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

32 test; doğrulanmamış hesap, sahiplik, takım üyeliği, davet (geçerli/süresi dolmuş/başka e-posta),
şema sınırları ve sorgu düzeyi kuralları kapsanır.
