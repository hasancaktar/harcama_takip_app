# Firestore Veri Modeli ve Sorgu Desenleri (Data Model)

Bu doküman, Firestore veritabanı koleksiyon yapısını, doküman şemalarını, alan tiplerini, denormalizasyon stratejilerini ve composite index gereksinimlerini tanımlar.

---

## 1. Mimari Prensipler

1. **Integer Kuruş Kuralı:** Tüm para alanları kuruş cinsinden tamsayıdır (`amountInCents: int`). Asla `double` saklanmaz.
2. **UTC Timestamp:** Tüm tarihler Firestore `Timestamp` (UTC) olarak saklanır. Arayüzde kullanıcının IANA saat dilimi (varsayılan: `Europe/Istanbul`) ile biçimlendirilir.
3. **Soft Delete ve Audit:** Finansal kayıtlar fiziksel olarak silinmez; `status: "deleted"`, `deletedAt: Timestamp` ve `deletedBy: String` alanları eklenir.
4. **Kişisel vs. Takım Ayrımı:** Harcamalarda `visibility` alanı `"personal"` veya `"team"` olabilir. Takıma bağlı harcamalar `teamId` taşır; kişisel harcamalar ise `teamId: null` ve `ownerUid: <kullanıcı_uid>` taşır.

---

## 2. Koleksiyon Şemaları

### 2.1. `users/{uid}`
Kullanıcının profil bilgileri ve global ayarları.
```json
{
  "uid": "string",
  "email": "string",
  "displayName": "string",
  "firstName": "string",
  "lastName": "string",
  "photoUrl": "string?",
  "defaultCurrency": "TRY",
  "defaultTimezone": "Europe/Istanbul",
  "themeMode": "system | light | dark",
  "dailyReminderEnabled": true,
  "dailyReminderHour": 21,
  "dailyReminderMinute": 0,
  "dailyReminderDays": [1, 2, 3, 4, 5, 6, 7],
  "fcmTokens": ["token1", "token2"],
  "activeTeamId": "string?",
  "createdAt": "Timestamp",
  "updatedAt": "Timestamp"
}
```

### 2.2. `teams/{teamId}`
Takım/Aile bilgileri.
```json
{
  "id": "string",
  "name": "string (örn: Evimiz / Aile Bütçesi)",
  "description": "string?",
  "avatarUrl": "string?",
  "colorHex": "string (#2E7D32)",
  "ownerUid": "string",
  "defaultCurrency": "TRY",
  "defaultTimezone": "Europe/Istanbul",
  "isArchived": false,
  "memberCount": 2,
  "createdAt": "Timestamp",
  "updatedAt": "Timestamp"
}
```

### 2.3. `teams/{teamId}/members/{uid}`
Takım üyeliği ve rolü.
```json
{
  "uid": "string",
  "teamId": "string",
  "displayName": "string",
  "email": "string",
  "photoUrl": "string?",
  "role": "owner | admin | member | viewer",
  "status": "invited | accepted | left | removed",
  "joinedAt": "Timestamp",
  "invitedBy": "string"
}
```

### 2.4. `teams/{teamId}/invites/{inviteId}`
Takım davet bağlantıları ve kodları.
```json
{
  "inviteId": "string",
  "teamId": "string",
  "teamName": "string",
  "invitedEmail": "string?",
  "inviteCode": "string (6-8 haneli alfanümerik)",
  "role": "member",
  "status": "pending | accepted | expired | revoked",
  "createdBy": "string",
  "createdAt": "Timestamp",
  "expiresAt": "Timestamp"
}
```

### 2.5. `expenses/{expenseId}` (Root Koleksiyon - Hibrit Model)
> **Tasarım Kararı:** Harcamaları hem kişisel hem takım düzeyinde tek bir güvenli root koleksiyonda tutmak, tek sorguyla "Benim harcamalarım" veya "Takım harcamaları" veya "Seçili ayın tüm harcamaları" filtrelerini sağlamak için en optimize yapıdır.
```json
{
  "id": "string (UUID)",
  "teamId": "string?",
  "ownerUid": "string",
  "visibility": "personal | team",
  "title": "string",
  "amountInCents": 12550,
  "currency": "TRY",
  "category": "market | restaurant | transportation | bills | rent | health | education | shopping | entertainment | travel | subscription | home | personal_care | other",
  "subCategory": "string?",
  "date": "Timestamp",
  "paymentMethod": "cash | debit_card | credit_card | bank_transfer | auto_payment | other",
  "cardId": "string?",
  "cardLast4": "string?",
  "isInstallment": false,
  "installmentPlanId": "string?",
  "installmentNumber": 1,
  "totalInstallments": 1,
  "statementPeriod": "YYYY-MM (örn: 2026-11)",
  "notes": "string?",
  "tags": ["haftalık", "süpermarket"],
  "receiptUrl": "string?",
  "status": "active | deleted",
  "createdBy": "string",
  "createdAt": "Timestamp",
  "updatedAt": "Timestamp",
  "deletedAt": "Timestamp?",
  "deletedBy": "string?"
}
```

### 2.6. `creditCards/{cardId}` (veya `users/{uid}/cards` + takım paylaşımlı)
Kullanıcının kredi kartı tanımları.
```json
{
  "id": "string",
  "ownerUid": "string",
  "teamId": "string?",
  "isSharedWithTeam": false,
  "name": "string (örn: Bonus Platinum)",
  "bankName": "string (örn: Garanti BBVA)",
  "last4Digits": "1234",
  "colorHex": "#1E88E5",
  "cardType": "mastercard | visa | troy | amex",
  "limitInCents": 5000000,
  "cutoffDay": 15,
  "paymentDueDaysAfterCutoff": 10,
  "paymentDueDay": 25,
  "currency": "TRY",
  "isActive": true,
  "createdAt": "Timestamp",
  "updatedAt": "Timestamp"
}
```

### 2.7. `installmentPlans/{planId}`
Kullanıcının veya takımın ana taksit sözleşmesi/planı.
```json
{
  "id": "string",
  "ownerUid": "string",
  "teamId": "string?",
  "visibility": "personal | team",
  "title": "string (örn: Çamaşır Makinesi)",
  "totalAmountInCents": 1800000,
  "totalInstallments": 6,
  "cardId": "string",
  "cardLast4": "1234",
  "category": "home",
  "startDate": "Timestamp",
  "firstCutoffDate": "Timestamp",
  "currency": "TRY",
  "installmentSchedule": [
    {
      "installmentNumber": 1,
      "amountInCents": 300000,
      "statementPeriod": "2026-11",
      "statementCutoffDate": "Timestamp",
      "dueDate": "Timestamp",
      "status": "posted"
    },
    {
      "installmentNumber": 2,
      "amountInCents": 300000,
      "statementPeriod": "2026-12",
      "statementCutoffDate": "Timestamp",
      "dueDate": "Timestamp",
      "status": "upcoming"
    }
  ],
  "status": "active | completed | cancelled",
  "createdAt": "Timestamp",
  "updatedAt": "Timestamp"
}
```

### 2.8. `budgets/{budgetId}`
Aylık bütçe tanımları.
```json
{
  "id": "string",
  "ownerUid": "string",
  "teamId": "string?",
  "visibility": "personal | team",
  "period": "2026-11",
  "totalBudgetInCents": 3500000,
  "categoryBudgets": {
    "market": 1000000,
    "bills": 500000,
    "restaurant": 400000
  },
  "rolloverRemaining": false,
  "alertThresholds": [50, 75, 90, 100],
  "currency": "TRY",
  "createdAt": "Timestamp",
  "updatedAt": "Timestamp"
}
```

---

## 3. Gerekli Composite Index'ler (`firestore.indexes.json`)

Firestore sorgularında performans ve maliyet optimizasyonu için aşağıdaki bileşik dizinler tanımlanacaktır:

1. **Seçili Takımın Aylık Harcamaları:**
   - Collection: `expenses`
   - Fields: `teamId` (ASC), `status` (ASC), `date` (DESC)
2. **Kullanıcının Kişisel Aylık Harcamaları:**
   - Collection: `expenses`
   - Fields: `ownerUid` (ASC), `visibility` (ASC), `status` (ASC), `date` (DESC)
3. **Kredi Kartına Bağlı Ekstre Dönemi Harcamaları:**
   - Collection: `expenses`
   - Fields: `cardId` (ASC), `statementPeriod` (ASC), `status` (ASC)
4. **Aktif Taksit Planları:**
   - Collection: `installmentPlans`
   - Fields: `ownerUid` (ASC), `status` (ASC), `createdAt` (DESC)
