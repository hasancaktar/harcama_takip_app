import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:harcama_takip/application/providers/settings_providers.dart';
import 'package:harcama_takip/core/constants/app_constants.dart';
import 'package:harcama_takip/core/firebase/firebase_initialization.dart';
import 'package:harcama_takip/domain/entities/admin_models.dart';
import 'package:harcama_takip/domain/entities/app_user.dart';
import 'package:harcama_takip/domain/entities/user_profile.dart';
import 'package:harcama_takip/main.dart';
import 'package:harcama_takip/presentation/navigation/app_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fakes.dart';

const _user = AppUser(
  uid: 'u-ayse',
  email: 'ayse@example.com',
  displayName: 'Ayşe Yılmaz',
  emailVerified: true,
);
const _admin = AppUser(
  uid: 'u-admin',
  email: AppConstants.adminEmail,
  displayName: 'Yönetici',
  emailVerified: true,
);

class _Backend extends TestBackend {
  _Backend(AppUser user) : _auth = FakeAuthRepository(initialUser: user);
  final FakeAuthRepository _auth;

  @override
  FakeAuthRepository get auth => _auth;
}

Future<void> _settle(WidgetTester tester, {int frames = 12}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<GoRouter> _pump(
  WidgetTester tester,
  TestBackend backend, {
  SharedPreferences? prefs,
}) async {
  tester.view.physicalSize = const Size(420, 1000);
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
  await _settle(tester);
  return ProviderScope.containerOf(
    tester.element(find.byType(ExpenseTrackerApp)),
  ).read(appRouterProvider);
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 1));
}

UserProfile _profile(AppUser u, {DateTime? createdAt, bool disabled = false}) {
  final at = createdAt ?? DateTime(2026, 1, 1);
  return UserProfile(
    uid: u.uid,
    email: u.email,
    displayName: u.displayName,
    disabled: disabled,
    createdAt: at,
    updatedAt: at,
  );
}

void main() {
  setUpAll(() => initializeDateFormatting('tr_TR'));

  testWidgets(
    'kullanıcı öneri gönderir; yönetici panelde görür ve okundu yapar',
    (tester) async {
      final backend = _Backend(_user);
      final router = await _pump(tester, backend);
      router.go('/settings/feedback');
      await _settle(tester);

      await tester.enterText(
        find.byType(TextFormField),
        'Raporlarda yıllık görünüm olsun',
      );
      await tester.tap(find.text('Gönder'));
      await _settle(tester);
      expect(backend.appContent.sent, ['Raporlarda yıllık görünüm olsun']);
      final entry = backend.admin.feedback.value.single;
      expect(entry.uid, _user.uid);
      expect(entry.appVersion, AppConstants.appVersion);
      expect(entry.isNew, isTrue);
      await _unmount(tester);

      // Yönetici paneli
      final adminBackend = _Backend(_admin);
      adminBackend.admin.feedback.value = backend.admin.feedback.value;
      final adminRouter = await _pump(tester, adminBackend);
      adminRouter.go('/admin');
      await _settle(tester);
      expect(find.text('1 okunmamış öneri'), findsOneWidget);
      adminRouter.go('/admin/feedback');
      await _settle(tester);
      expect(find.text('Raporlarda yıllık görünüm olsun'), findsOneWidget);
      await tester.tap(find.text('Ayşe Yılmaz'));
      await _settle(tester);
      expect(adminBackend.admin.feedback.value.single.isNew, isFalse);
      await _unmount(tester);
    },
  );

  testWidgets(
    'pasife alınan hesap çıkış yapar ve giriş ekranında nedeni görünür',
    (tester) async {
      final backend = _Backend(_user);
      backend.users.seedProfile(_profile(_user, disabled: true));
      await _pump(tester, backend);

      expect(backend.auth.currentUser, isNull);
      expect(
        find.text(
          'Hesabınız devre dışı bırakıldı. Bilgi için: ${AppConstants.contactEmail}',
        ),
        findsOneWidget,
      );
      await _unmount(tester);
    },
  );

  testWidgets(
    'yönetici kullanıcıyı pasife alır; kendi hesabında bu seçenek yoktur',
    (tester) async {
      final backend = _Backend(_admin);
      backend.admin.users = const [
        AdminUserSummary(
          uid: 'u-ayse',
          email: 'ayse@example.com',
          displayName: 'Ayşe Yılmaz',
          hasPushToken: true,
          pushEnabled: true,
          language: 'tr',
        ),
        AdminUserSummary(
          uid: 'u-admin',
          email: AppConstants.adminEmail,
          displayName: 'Yönetici',
          hasPushToken: true,
          pushEnabled: true,
          language: 'tr',
        ),
      ];
      final router = await _pump(tester, backend);
      router.go('/admin/users');
      await _settle(tester);

      expect(find.byTooltip('Kullanıcı işlemleri'), findsOneWidget);
      await tester.tap(find.byTooltip('Kullanıcı işlemleri'));
      await _settle(tester);
      await tester.tap(find.text('Pasife al').last);
      await _settle(tester);
      // Onay penceresi
      await tester.tap(find.text('Pasife al').last);
      await _settle(tester);

      expect(backend.admin.disabledChanges, [('u-ayse', true)]);
      expect(find.text('Pasif'), findsOneWidget);
      await _unmount(tester);
    },
  );

  group('Yenilikler penceresi', () {
    ReleaseNotes notes({required DateTime publishedAt}) => ReleaseNotes(
      version: AppConstants.appVersion,
      addedTr: const ['Otomatik ödemeler'],
      fixedTr: const ['Günlük hatırlatıcı kaydedilmiyordu'],
      published: true,
      publishedAt: publishedAt,
    );

    testWidgets(
      'güncelleyen kullanıcıya bir kez gösterilir, sonra gösterilmez',
      (tester) async {
        SharedPreferences.setMockInitialValues({'language': 'tr'});
        final prefs = await SharedPreferences.getInstance();
        final backend = _Backend(_user);
        backend.users.seedProfile(_profile(_user));
        backend.admin.releaseNotes.value = [
          notes(publishedAt: DateTime(2026, 11, 19)),
        ];
        await _pump(tester, backend, prefs: prefs);
        await _settle(tester);

        expect(
          find.text('Yenilikler · ${AppConstants.appVersion}'),
          findsOneWidget,
        );
        expect(find.text('• Otomatik ödemeler'), findsOneWidget);
        expect(
          find.text('• Günlük hatırlatıcı kaydedilmiyordu'),
          findsOneWidget,
        );
        await tester.tap(find.text('Harika'));
        await _settle(tester);
        expect(
          prefs.getString('release_notes_seen_version'),
          AppConstants.appVersion,
        );
        await _unmount(tester);

        await _pump(tester, backend, prefs: prefs);
        expect(find.textContaining('Yenilikler ·'), findsNothing);
        await _unmount(tester);
      },
    );

    testWidgets('notlar yayınlandıktan sonra açılan hesaba gösterilmez', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({'language': 'tr'});
      final prefs = await SharedPreferences.getInstance();
      final backend = _Backend(_user);
      backend.users.seedProfile(
        _profile(_user, createdAt: DateTime(2026, 12, 1)),
      );
      backend.admin.releaseNotes.value = [
        notes(publishedAt: DateTime(2026, 11, 19)),
      ];
      await _pump(tester, backend, prefs: prefs);
      expect(find.textContaining('Yenilikler ·'), findsNothing);
      await _unmount(tester);
    });
  });
}
