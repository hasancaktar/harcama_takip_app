import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:harcama_takip/application/providers/settings_providers.dart';
import 'package:harcama_takip/core/constants/app_constants.dart';
import 'package:harcama_takip/core/firebase/firebase_initialization.dart';
import 'package:harcama_takip/core/l10n/app_locale.dart';
import 'package:harcama_takip/domain/entities/app_user.dart';
import 'package:harcama_takip/main.dart';
import 'package:harcama_takip/presentation/screens/admin/admin_home_screen.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fakes.dart';

const _adminUser = AppUser(
  uid: 'u-admin',
  email: AppConstants.adminEmail,
  displayName: 'Yönetici',
  emailVerified: true,
);

const _regularUser = AppUser(
  uid: 'u-ayse',
  email: 'ayse@example.com',
  displayName: 'Ayşe Yılmaz',
  emailVerified: true,
);

class _Backend extends TestBackend {
  final FakeAuthRepository _auth;

  _Backend(AppUser? user) : _auth = FakeAuthRepository(initialUser: user);

  @override
  FakeAuthRepository get auth => _auth;
}

Future<void> settle(WidgetTester tester, {int frames = 12}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> pumpApp(
  WidgetTester tester,
  TestBackend backend, {
  Size size = const Size(400, 860),
  SharedPreferences? prefs,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...backend.overrides,
        if (prefs != null) sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const ExpenseTrackerApp(
        initResult: FirebaseInitResult(isSuccess: true),
      ),
    ),
  );
  await settle(tester);
}

Future<void> unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 1));
}

/// Kaydırılabilir alanda görünür hâle getirip dokunur.
Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
}

/// Uygulama içi yönlendiriciyle bir yola gider (adres çubuğuna yazmak gibi).
Future<void> goTo(WidgetTester tester, String location) async {
  GoRouter.of(tester.element(find.byType(Scaffold).first)).go(location);
  await settle(tester);
}

Future<SharedPreferences> prefsWith(Map<String, Object> values) {
  SharedPreferences.setMockInitialValues(values);
  return SharedPreferences.getInstance();
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr_TR');
    await initializeDateFormatting('en_US');
  });

  // Dil ve kategori kaydı süreç geneli durumdur; testler birbirini etkilemesin.
  tearDown(() {
    AppLocale.set(AppLocale.fallback);
    CategoryRegistry.update(const []);
  });

  group('Dil desteği', () {
    testWidgets(
      'İngilizce seçiliyken giriş ekranı ve doğrulama mesajları İngilizcedir',
      (tester) async {
        final prefs = await prefsWith({'language': 'en'});
        await pumpApp(tester, _Backend(null), prefs: prefs);

        expect(find.text('Welcome back'), findsOneWidget);
        expect(find.text('Tekrar hoş geldiniz'), findsNothing);

        await tester.tap(find.text('Sign in').last);
        await settle(tester, frames: 3);
        expect(find.text('Email address is required'), findsOneWidget);
        expect(find.text('Password is required'), findsOneWidget);
        await unmount(tester);
      },
    );

    testWidgets(
      'dil ayarlardan değiştirilir, anında uygulanır ve cihazda saklanır',
      (tester) async {
        final prefs = await prefsWith({'language': 'tr'});
        final backend = _Backend(_regularUser);
        await pumpApp(tester, backend, prefs: prefs);

        expect(find.text('Özet'), findsWidgets);
        await tester.tap(find.text('Ayarlar'));
        await settle(tester);
        await tester.tap(find.text('Görünüm ve dil'));
        await settle(tester);

        await tester.tap(find.text('English'));
        await settle(tester);

        // Hem açık sayfa hem alttaki gezinme çubuğu yeni dilde.
        expect(find.text('Appearance and language'), findsOneWidget);
        expect(find.text('Görünüm ve dil'), findsNothing);
        expect(prefs.getString('language'), 'en');
        expect(AppLocale.code, 'en');

        await tester.tap(find.text('Türkçe'));
        await settle(tester);
        expect(find.text('Görünüm ve dil'), findsOneWidget);
        expect(prefs.getString('language'), 'tr');
        await unmount(tester);
      },
    );

    testWidgets('İngilizcede gezinme, özet ve harcama formu çevrilmiştir', (
      tester,
    ) async {
      final prefs = await prefsWith({'language': 'en'});
      await pumpApp(tester, _Backend(_regularUser), prefs: prefs);

      for (final label in [
        'Overview',
        'Expenses',
        'Cards',
        'Reports',
        'Settings',
      ]) {
        expect(find.text(label), findsWidgets, reason: label);
      }
      for (final label in [
        'Özet',
        'Harcamalar',
        'Kartlar',
        'Raporlar',
        'Ayarlar',
      ]) {
        expect(find.text(label), findsNothing, reason: label);
      }

      await goTo(tester, '/expenses/new');
      expect(find.text('New expense'), findsOneWidget);
      // Kategoriler ve ödeme yöntemleri de etkin dilde.
      expect(find.text('Groceries'), findsWidgets);
      expect(find.text('Market'), findsNothing);
      expect(find.text('Cash'), findsWidgets);
      await unmount(tester);
    });
  });

  group('Yönetim paneli erişimi', () {
    testWidgets('normal kullanıcı paneli görmez ve adresle de açamaz', (
      tester,
    ) async {
      await pumpApp(tester, _Backend(_regularUser));

      await tester.tap(find.text('Ayarlar'));
      await settle(tester);
      expect(find.text('Yönetim paneli'), findsNothing);

      await goTo(tester, '/admin');
      expect(find.byType(AdminHomeScreen), findsNothing);
      await goTo(tester, '/admin/send');
      expect(find.text('Bildirimi gönder'), findsNothing);
      await goTo(tester, '/admin/categories');
      expect(find.text('Kategori yönetimi'), findsNothing);
      await unmount(tester);
    });

    testWidgets('yönetici e-postası doğrulanmamışsa panel açılmaz', (
      tester,
    ) async {
      const unverifiedAdmin = AppUser(
        uid: 'u-admin',
        email: AppConstants.adminEmail,
        displayName: 'Yönetici',
        emailVerified: false,
      );
      await pumpApp(tester, _Backend(unverifiedAdmin));
      expect(find.text('E-postanızı doğrulayın'), findsOneWidget);
      await goTo(tester, '/admin');
      expect(find.byType(AdminHomeScreen), findsNothing);
      await unmount(tester);
    });

    testWidgets('yönetici paneli ayarlardan açar ve tüm bölümleri görür', (
      tester,
    ) async {
      await pumpApp(tester, _Backend(_adminUser));

      await tester.tap(find.text('Ayarlar'));
      await settle(tester);
      await tester.tap(find.text('Yönetim paneli'));
      await settle(tester);

      expect(find.byType(AdminHomeScreen), findsOneWidget);
      for (final title in [
        'Bildirim gönder',
        'Günlük hatırlatma',
        'Bildirim geçmişi',
        'Kategori yönetimi',
      ]) {
        expect(find.text(title), findsOneWidget, reason: title);
      }
      await unmount(tester);
    });
  });

  group('Yönetim paneli işlemleri', () {
    testWidgets('bildirim onaydan sonra kuyruğa alınır ve işlem kaydı oluşur', (
      tester,
    ) async {
      final backend = _Backend(_adminUser);
      await pumpApp(tester, backend);
      await goTo(tester, '/admin/send');

      // Boş form gönderilemez.
      await tapVisible(tester, find.text('Bildirimi gönder'));
      await settle(tester, frames: 3);
      expect(backend.admin.campaigns.value, isEmpty);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Başlık'),
        'Bakım duyurusu',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Mesaj'),
        'Bu gece 02:00-03:00 arasında kısa bir kesinti olacak.',
      );
      await tapVisible(tester, find.text('Bildirimi gönder'));
      await settle(tester, frames: 4);

      // Onay istenir; vazgeçilirse hiçbir şey gönderilmez.
      expect(find.text('Bildirim gönderilsin mi?'), findsOneWidget);
      await tester.tap(find.text('Vazgeç'));
      await settle(tester, frames: 4);
      expect(backend.admin.campaigns.value, isEmpty);

      await tapVisible(tester, find.text('Bildirimi gönder'));
      await settle(tester, frames: 4);
      await tester.tap(find.text('Gönder'));
      await settle(tester);

      final campaign = backend.admin.campaigns.value.single;
      expect(campaign.titleTr, 'Bakım duyurusu');
      expect(campaign.target, 'all');
      expect(backend.admin.logs.value.single.action, 'notification.send');
      // Gönderim sonrası geçmiş ekranı açılır.
      expect(find.text('Bildirim geçmişi'), findsOneWidget);
      expect(find.text('Bakım duyurusu'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('kategori silinince kayıt korunur ve geri yüklenebilir', (
      tester,
    ) async {
      final backend = _Backend(_adminUser);
      await pumpApp(tester, backend);
      await goTo(tester, '/admin/categories');

      expect(find.text('Yerleşik kategoriler kullanılıyor'), findsOneWidget);
      await tester.tap(find.text('Varsayılanları içe aktar'));
      await settle(tester);

      final count = AppConstants.defaultCategories.length;
      expect(backend.categories.categories.value, hasLength(count));
      expect(find.text('Market'), findsOneWidget);

      // "Market" kategorisini sil.
      await tester.tap(find.byTooltip('Kategori işlemleri').first);
      await settle(tester, frames: 4);
      await tester.tap(find.text('Sil').last);
      await settle(tester, frames: 4);
      expect(find.text('Kategori silinsin mi?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Sil'));
      await settle(tester);

      // Belge silinmez; yalnızca işaretlenir. Geçmiş harcamalar adını çözebilir.
      final stored = backend.categories.categories.value;
      expect(stored, hasLength(count));
      final market = stored.firstWhere((c) => c.id == 'market');
      expect(market.isDeleted, isTrue);
      expect(AppConstants.getCategoryById('market').nameTr, 'Market');
      expect(AppConstants.categories.any((c) => c.id == 'market'), isFalse);

      await tapVisible(tester, find.text('Geri yükle'));
      await settle(tester);
      expect(
        backend.categories.categories.value
            .firstWhere((c) => c.id == 'market')
            .isDeleted,
        isFalse,
      );
      expect(
        backend.admin.logs.value.map((l) => l.action),
        containsAll([
          'category.import_defaults',
          'category.delete',
          'category.restore',
        ]),
      );
      await unmount(tester);
    });
  });
}
