# Tasarım Sistemi (Design System: Emerald & Slate Trust)

Bu doküman, uygulamanın görsel kimliğini, renk paletini, tipografi hiyerarşisini, bileşen standartlarını ve erişilebilirlik kurallarını tanımlar.

---

## 1. Tasarım Yönleri Değerlendirmesi

1. **Yön 1 (Seçilen): Sakin Zümrüt & Finans Güveni (Emerald & Slate Trust)**
   - *Karakter:* Finansal güven, sakinlik, bütçe berraklığı ve aile sıcaklığı.
   - *Birincil Vurgu:* Derin Zümrüt Yeşili (`#0F5132` / `#10B981`).
   - *Kart/Gider Vurgusu:* Koyu Arduvaz & Yumuşak Mercan Borç Vurgusu.
   - *Neden Seçildi:* Aile ve kişisel harcama takibinde hem pozitif bütçe hissini hem de borç/taksit ciddiyetini en iyi dengeleyen, gözü yormayan renk uyumu.

2. **Yön 2: İskandinav Minimalizm (Nordic Slate & Sky)**
   - *Karakter:* Bol beyaz alan, donanma mavisi ve açık gri yüzeyler.

3. **Yön 3: Neo-Bank Estetiği (Indigo & Mint Dynamic)**
   - *Karakter:* Çok canlı mor-mavi ve neon nane vurguları; genç ve dinamik fintech tarzı.

---

## 2. Renk Paleti (Color Palette)

### 2.1. Açık Tema (Light Theme)
- **Primary:** `#0F5132` (Derin Zümrüt Yeşili - güven ve bütçe)
- **On Primary:** `#FFFFFF`
- **Primary Container:** `#D1E7DD`
- **On Primary Container:** `#08321E`
- **Secondary:** `#1E3A8A` (Derin Gece Mavisi - kredi kartları ve taksitler)
- **Secondary Container:** `#DBEAFE`
- **Background:** `#F8F9FA` (Yumuşak açık gri/kemik, gözü almaz)
- **Surface:** `#FFFFFF` (Kartlar ve sheet'ler)
- **Surface Variant:** `#F1F3F5` (Giriş kutuları, chip'ler)
- **Error:** `#DC2626` (Bütçe aşımı, gecikmiş taksit)
- **Warning:** `#D97706` (Yaklaşan kesim tarihi veya bütçe %90 eşiği)
- **Success:** `#16A34A` (Ödenmiş taksit, bütçe içi durum)
- **Text Primary:** `#1A1D20`
- **Text Secondary:** `#6C757D`
- **Divider/Border:** `#E9ECEF`

### 2.2. Koyu Tema (Dark Theme)
- **Primary:** `#10B981` (Canlı Zümrüt)
- **On Primary:** `#022C22`
- **Primary Container:** `#064E3B`
- **Secondary:** `#60A5FA` (Açık Mavi)
- **Background:** `#0F172A` (Derin Arduvaz Gece)
- **Surface:** `#1E293B` (Yükseltilmiş kartlar)
- **Surface Variant:** `#334155`
- **Error:** `#EF4444`
- **Warning:** `#F59E0B`
- **Success:** `#22C55E`
- **Text Primary:** `#F8FAFC`
- **Text Secondary:** `#94A3B8`
- **Divider/Border:** `#334155`

---

## 3. Tipografi Hiyerarşisi

Font ailesi: Modern sans-serif (`Inter` veya sistem Material Font ailesi). Rakamlar tabular formatta (`FontFeature.tabularFigures()`) gösterilir:

- **Display (Büyük Bütçe/Harcama Tutarı):** 32sp, Semi-Bold / Bold, letter-spacing: -0.5px
- **Headline Medium (Kart Başlıkları):** 20sp, Semi-Bold
- **Title Medium (Liste Başlıkları, Harcama Adı):** 16sp, Medium
- **Body Large (Form Metinleri, Detaylar):** 15sp, Regular
- **Body Medium (İkincil Bilgiler, Tarih):** 13sp, Regular, Text Secondary
- **Label Small (Kategori Etiketleri, Rozetler):** 11sp, Bold, Uppercase

---

## 4. Spacing, Radius ve Gölgeler

- **Grid Spacing:** 4px tabanlı ölçek: `4px`, `8px`, `12px`, `16px` (varsayılan sayfa kenar boşluğu), `24px`, `32px`.
- **Corner Radius:**
  - Butonlar: `12px`
  - Harcama & Kart Kartları: `16px`
  - Bottom Sheet & Dialog'lar: `24px` (üst köşeler)
  - Kategori Çipleri: `20px` (tam yuvarlak hap)
- **Gölgeler (Elevations):**
  - Kartlar: `box-shadow: 0 2px 8px rgba(0, 0, 0, 0.04)` (yumuşak, doğal derinlik)
  - FAB / Aksiyon Butonu: `box-shadow: 0 4px 16px rgba(15, 81, 50, 0.25)`

---

## 5. Grafik ve Kategori Renkleri (Erişilebilir)

Grafiklerde renk körlüğünü engellemek için yüksek kontrastlı ve ayırt edilebilir renkler kullanılır:
- **Market:** Yeşil `#10B981`
- **Restoran:** Turuncu `#F97316`
- **Ulaşım:** Mavi `#3B82F6`
- **Fatura:** Kırmızı/Mercan `#EF4444`
- **Kira:** Mor `#8B5CF6`
- **Sağlık:** Camgöbeği `#06B6D4`
- **Eğlence:** Pembe `#EC4899`
- **Alışveriş:** Sarı/Amber `#F59E0B`
- **Diğer:** Nötr Gri `#6B7280`

---

## 6. Animasyon Kuralları

- Sayfa geçişleri: `250ms`, `Curves.easeInOutCubic`.
- Harcama ekleme FAB açılışı: `200ms`, `Curves.easeOutBack`.
- Taksit tamamlama/onay kutusu animasyonu: `300ms` hafif haptik geri bildirim eşliğinde.
