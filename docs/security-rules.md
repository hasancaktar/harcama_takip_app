# Firestore Güvenlik Kuralları (Security Rules Guide)

Bu doküman, Firestore veritabanının yetkilendirme ve veri bütünlüğü kurallarını, rol tabanlı erişim kontrolünü (RBAC) ve test stratejisini açıklar.

---

## 1. Temel Güvenlik Prensipleri

1. **Varsayılan Olarak Reddet (Deny by Default):** Açıkça izin verilmeyen hiçbir okuma ve yazma işlemine izin verilmez.
2. **Kimlik Doğrulama Zorunluluğu:** `request.auth != null` kuralı tüm operasyonlar için asgari şarttır.
3. **Kişisel Gizlilik:** Bir kullanıcının `visibility == "personal"` olan harcamaları, kartları veya bütçeleri, aynı takımda olsa dahi diğer üyeler tarafından kesinlikle **okunamaz**.
4. **Takım Yetki Matrisi:**
   - `owner`: Takımı silebilir, üyeleri çıkarabilir, yönetici atayabilir, tüm takım verilerini düzenleyebilir.
   - `admin`: Harcama/taksit/bütçe ekleyebilir, düzenleyebilir, yeni üye davet edebilir.
   - `member`: Harcama/taksit ekleyebilir, kendi eklediği kayıtları düzenleyebilir.
   - `viewer`: Yalnızca takım harcamalarını ve raporlarını okuyabilir; yazma hakkı yoktur.
5. **Finansal Bütünlük:**
   - `amountInCents` alanı tamsayı (`is int`) ve sıfırdan büyük olmalıdır (`> 0`).
   - `currency` zorunlu ve 3 karakterli ISO kodudur.
   - Hassas kart bilgileri (CVV, 16 hane) veritabanına yazılamaz.

---

## 2. Güvenlik Kuralları Taslağı (`firestore.rules`)

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // Yardımcı Fonksiyonlar
    function isAuthenticated() {
      return request.auth != null;
    }
    
    function isOwner(userId) {
      return isAuthenticated() && request.auth.uid == userId;
    }

    function isTeamMember(teamId) {
      return isAuthenticated() && 
        exists(/databases/$(database)/documents/teams/$(teamId)/members/$(request.auth.uid)) &&
        get(/databases/$(database)/documents/teams/$(teamId)/members/$(request.auth.uid)).data.status == "accepted";
    }

    function getTeamMemberRole(teamId) {
      return get(/databases/$(database)/documents/teams/$(teamId)/members/$(request.auth.uid)).data.role;
    }

    function isTeamAdminOrOwner(teamId) {
      return isTeamMember(teamId) && 
        (getTeamMemberRole(teamId) == "owner" || getTeamMemberRole(teamId) == "admin");
    }

    // Kullanıcı Profili
    match /users/{uid} {
      allow read: if isAuthenticated();
      allow create, update: if isOwner(uid);
      allow delete: if false; // Kullanıcı silme Cloud Function üzerinden güvenle yapılır
    }

    // Takımlar
    match /teams/{teamId} {
      allow read: if isTeamMember(teamId);
      allow create: if isAuthenticated() && request.resource.data.ownerUid == request.auth.uid;
      allow update: if isTeamAdminOrOwner(teamId);
      allow delete: if isAuthenticated() && resource.data.ownerUid == request.auth.uid;

      // Takım Üyeleri
      match /members/{memberUid} {
        allow read: if isTeamMember(teamId);
        // İlk üye (owner) oluşturma veya yetkili daveti
        allow write: if isTeamAdminOrOwner(teamId) || (isAuthenticated() && request.auth.uid == memberUid);
      }

      // Takım Davetleri
      match /invites/{inviteId} {
        allow read: if isAuthenticated();
        allow write: if isTeamAdminOrOwner(teamId);
      }
    }

    // Harcamalar
    match /expenses/{expenseId} {
      // Kişisel harcamayı yalnızca sahibi okuyabilir.
      // Takım harcamasını ilgili takımın aktif üyeleri okuyabilir.
      allow read: if isAuthenticated() && (
        (resource.data.visibility == "personal" && resource.data.ownerUid == request.auth.uid) ||
        (resource.data.visibility == "team" && resource.data.teamId != null && isTeamMember(resource.data.teamId))
      );

      // Harcama ekleme
      allow create: if isAuthenticated() && (
        (request.resource.data.visibility == "personal" && request.resource.data.ownerUid == request.auth.uid) ||
        (request.resource.data.visibility == "team" && isTeamMember(request.resource.data.teamId))
      ) && request.resource.data.amountInCents is int && request.resource.data.amountInCents > 0;

      // Harcama düzenleme ve silme (soft-delete)
      allow update: if isAuthenticated() && (
        (resource.data.ownerUid == request.auth.uid) ||
        (resource.data.visibility == "team" && isTeamAdminOrOwner(resource.data.teamId))
      );

      allow delete: if false; // Fiziksel silme yerine soft delete zorunludur
    }

    // Kredi Kartları
    match /creditCards/{cardId} {
      allow read: if isAuthenticated() && (
        resource.data.ownerUid == request.auth.uid ||
        (resource.data.isSharedWithTeam == true && resource.data.teamId != null && isTeamMember(resource.data.teamId))
      );
      allow create: if isAuthenticated() && request.resource.data.ownerUid == request.auth.uid;
      allow update, delete: if isAuthenticated() && resource.data.ownerUid == request.auth.uid;
    }

    // Taksit Planları
    match /installmentPlans/{planId} {
      allow read: if isAuthenticated() && (
        resource.data.ownerUid == request.auth.uid ||
        (resource.data.visibility == "team" && resource.data.teamId != null && isTeamMember(resource.data.teamId))
      );
      allow create: if isAuthenticated() && request.resource.data.ownerUid == request.auth.uid;
      allow update: if isAuthenticated() && (
        resource.data.ownerUid == request.auth.uid ||
        (resource.data.visibility == "team" && isTeamAdminOrOwner(resource.data.teamId))
      );
      allow delete: if isAuthenticated() && resource.data.ownerUid == request.auth.uid;
    }

    // Bütçeler
    match /budgets/{budgetId} {
      allow read: if isAuthenticated() && (
        resource.data.ownerUid == request.auth.uid ||
        (resource.data.visibility == "team" && resource.data.teamId != null && isTeamMember(resource.data.teamId))
      );
      allow create, update: if isAuthenticated() && (
        (request.resource.data.visibility == "personal" && request.resource.data.ownerUid == request.auth.uid) ||
        (request.resource.data.visibility == "team" && isTeamAdminOrOwner(request.resource.data.teamId))
      );
      allow delete: if isAuthenticated() && (
        resource.data.ownerUid == request.auth.uid ||
        (resource.data.visibility == "team" && isTeamAdminOrOwner(resource.data.teamId))
      );
    }
  }
}
```
