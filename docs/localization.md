# Dil Desteği

Uygulama Türkçe ve İngilizce çalışır. Dil **Ayarlar > Görünüm ve dil** ekranından değiştirilir;
değişiklik anında uygulanır, cihazda saklanır ve sunucu bildirimlerinin doğru dilde gitmesi için
profile (`users/{uid}.language`) yazılır. İlk açılışta cihaz dili Türkçe değilse İngilizce seçilir.

## Nasıl çalışır

Kaynak dil Türkçedir. Arayüz metinleri kodda Türkçe yazılır ve `.tr` ile etkin dile çevrilir
(gettext yaklaşımı). Çevirisi bulunmayan metin Türkçe olarak gösterilir.

```dart
Text('Kaydet'.tr)
Text('{0} gün kaldı'.trArgs([gun]))   // değişkenli metinlerde yer tutucu kullanın
```

| Dosya | Görev |
|---|---|
| [`lib/core/l10n/app_locale.dart`](../lib/core/l10n/app_locale.dart) | Merkezi dil yönetimi: desteklenen diller, etkin dil, `.tr` / `.trArgs` |
| [`lib/core/l10n/translations_en.dart`](../lib/core/l10n/translations_en.dart) | Türkçe → İngilizce çeviri tablosu |
| `localeProvider` (`settings_providers.dart`) | Seçimi saklar ve arayüzü yeniden çizer |

Tarih ve ay adları `intl` ile etkin dilde biçimlenir (`DateFormats`). Para birimi ve tutar biçimi
dile göre değişmez (TRY, `1.250,50 ₺`).

## Kurallar

- Değişken içeren metinlerde `'Merhaba, $ad'.tr` **yazmayın**; anahtar her seferinde değişir ve
  çeviri bulunamaz. `'Merhaba, {0}'.trArgs([ad])` kullanın.
- `const` bir ifadede `.tr` kullanılamaz. Sabit listeleri getter'a çevirin
  (`static List<String> get _gunler => ['Pzt'.tr, ...]`) ya da varsayılan parametreyi
  `null` bırakıp kullanım yerinde `etiket ?? 'Tutar'.tr` yazın.
- Kategori adları çeviri tablosunda değil, kategorinin kendi `nameTr` / `nameEn` alanlarındadır
  (yönetim panelinden düzenlenir).
- Veritabanına yazılan metinler (ör. taksit harcaması başlığı, işlem kaydı özeti) çevrilmez.

## Yeni metin eklemek

1. Kodda Türkçe metni `.tr` veya `.trArgs([...])` ile yazın.
2. Aynı metni anahtar olarak `translations_en.dart` içine ekleyin.
3. `flutter test test/unit/translations_test.dart` çalıştırın.

Test şunları doğrular ve eksik olanı dosya/satır ile raporlar:

- koddaki her metnin İngilizce karşılığı var,
- tabloda kodda kullanılmayan anahtar yok,
- yer tutucular (`{0}`, `{1}`) ve baş/son boşluklar kaynakla aynı,
- `$değişken` içeren hiçbir metin `.tr` ile sarılmamış.

Çok sayıda eski metni toplu sarmak için `python tool/l10n_wrap.py apply` kullanılabilir
(tekrar çalıştırmak güvenlidir); ardından `dart format lib` ve testi çalıştırın.

## Yeni dil eklemek

1. `lib/core/l10n/translations_xx.dart` oluşturun (`translations_en.dart` dosyasını kopyalayıp
   değerleri çevirin).
2. `AppLocale` içinde `supportedLocales`, `languageNames` ve `_tables` listelerine ekleyin;
   `intlLocale` içine dilin `intl` kodunu yazın ve `main.dart` içinde `initializeDateFormatting`
   çağrısını ekleyin.
3. Kategoriler ve sunucu bildirimleri için ayrı alan gerekir (`nameXx`, `titleXx` / `bodyXx`);
   `firestore.rules` içindeki `language in ['tr', 'en']` denetimine yeni kodu ekleyin.
4. `translations_test.dart` içindeki tablo denetimlerini yeni tablo için de çalıştırın.
