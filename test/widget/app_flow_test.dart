import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harcama_takip/core/firebase/firebase_initialization.dart';
import 'package:harcama_takip/core/utils/statement_calculator.dart';
import 'package:harcama_takip/domain/entities/app_user.dart';
import 'package:harcama_takip/domain/entities/team_invite.dart';
import 'package:harcama_takip/main.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../helpers/fakes.dart';

const _verifiedUser = AppUser(
  uid: 'u-ayse',
  email: 'ayse@example.com',
  displayName: 'Ayşe Yılmaz',
  emailVerified: true,
);

/// Sonsuz animasyonlu göstergeler nedeniyle pumpAndSettle yerine sınırlı sayıda kare ilerletir.
Future<void> settle(WidgetTester tester, {int frames = 12}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> pumpApp(
  WidgetTester tester,
  TestBackend backend, {
  Size size = const Size(400, 860),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: backend.overrides,
      child: const ExpenseTrackerApp(
        initResult: FirebaseInitResult(isSuccess: true),
      ),
    ),
  );
  await settle(tester);
}

/// Zamanlayıcıların test sonunda temizlenmesi için ağacı kaldırır.
Future<void> unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  setUpAll(() => initializeDateFormatting('tr_TR'));

  testWidgets(
    'Firebase başlatılamazsa kullanıcı dostu hata ekranı gösterilir',
    (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: ExpenseTrackerApp(
            initResult: FirebaseInitResult(
              isSuccess: false,
              errorMessage: 'test',
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Uygulama başlatılamadı'), findsOneWidget);
    },
  );

  testWidgets('Oturum kapalıyken giriş ekranı açılır ve form doğrulanır', (
    tester,
  ) async {
    final backend = TestBackend();
    await pumpApp(tester, backend);

    expect(find.text('Tekrar hoş geldiniz'), findsOneWidget);
    await tester.tap(find.text('Giriş yap').last);
    await settle(tester, frames: 3);
    expect(find.text('E-posta adresi gerekli'), findsOneWidget);
    expect(find.text('Şifre gerekli'), findsOneWidget);

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'ayse@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'yanlis123');
    await tester.tap(find.text('Giriş yap').last);
    await settle(tester, frames: 3);
    expect(find.text('E-posta veya şifre hatalı.'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets(
    'Kayıt sonrası e-posta doğrulanmadan korumalı alanlara erişilemez',
    (tester) async {
      final backend = TestBackend();
      await pumpApp(tester, backend);

      await tester.tap(find.text('Hesap oluştur'));
      await settle(tester);
      expect(find.text('Hesap oluşturun'), findsOneWidget);

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Ayşe Yılmaz');
      await tester.enterText(fields.at(1), 'ayse@example.com');
      await tester.enterText(fields.at(2), 'zayif');
      await tester.enterText(fields.at(3), 'zayif');
      await tester.ensureVisible(find.text('Hesap oluştur').last);
      await tester.tap(find.text('Hesap oluştur').last);
      await settle(tester, frames: 3);
      expect(find.text('Şifre en az 8 karakter olmalı'), findsOneWidget);

      await tester.enterText(fields.at(2), 'GucluSifre1');
      await tester.enterText(fields.at(3), 'GucluSifre1');
      await tester.tap(find.byType(CheckboxListTile));
      await tester.ensureVisible(find.text('Hesap oluştur').last);
      await tester.tap(find.text('Hesap oluştur').last);
      await settle(tester);

      // Doğrulama ekranına yönlendirildi; doğrulama e-postası gönderildi.
      expect(find.text('E-postanızı doğrulayın'), findsOneWidget);
      expect(find.text('ayse@example.com'), findsOneWidget);
      expect(backend.auth.verificationEmailsSent, 1);

      // Henüz doğrulanmadı: uyarı gösterilir, ekran değişmez.
      await tester.tap(find.text('E-postamı doğruladım'));
      await settle(tester, frames: 3);
      expect(find.textContaining('henüz doğrulanmamış'), findsOneWidget);

      // Tekrar gönder düğmesi bekleme süresinde pasif.
      final resend = tester.widget<OutlinedButton>(
        find.ancestor(
          of: find.textContaining('Tekrar gönder'),
          matching: find.byType(OutlinedButton),
        ),
      );
      expect(resend.onPressed, isNull);

      // E-posta doğrulandı → otomatik olarak özete yönlenir.
      backend.auth.verifyOnReload = true;
      await tester.tap(find.text('E-postamı doğruladım'));
      await settle(tester);
      expect(find.text('Merhaba, Ayşe'), findsOneWidget);
      await unmount(tester);
    },
  );

  testWidgets('Nakit harcama içinde bulunulan aya yazılır ve özette görünür', (
    tester,
  ) async {
    final backend = _BackendWithUser(
      FakeAuthRepository(initialUser: _verifiedUser),
    );
    await pumpApp(tester, backend);

    expect(find.text('Merhaba, Ayşe'), findsOneWidget);
    expect(find.text('Bu dönem harcama yok'), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await settle(tester);
    expect(find.text('Yeni harcama'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), '250,75');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'Pazar alışverişi',
    );
    // Odaktaki alan imleci görünür tutmak için sayfayı geri kaydırmasın.
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await tester.ensureVisible(find.text('Nakit'));
    await tester.pump();
    await tester.tap(find.text('Nakit'));
    await tester.pump();
    await tester.ensureVisible(find.text('Harcamayı kaydet'));
    await tester.pump();
    await tester.tap(find.text('Harcamayı kaydet'));
    await settle(tester);

    expect(backend.expenses.all, hasLength(1));
    final expense = backend.expenses.all.single;
    expect(expense.amountInCents, 25075);
    expect(expense.paymentMethod, 'cash');
    expect(
      expense.statementPeriod,
      StatementCalculator.periodOf(DateTime.now()),
    );
    expect(expense.visibility, 'personal');

    // Özete dönüldü ve harcama listede.
    expect(find.text('Pazar alışverişi'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets(
    'Bütçe kanonik kimlikle kaydedilir ve özet ekranında ilerleme gösterilir',
    (tester) async {
      final backend = _BackendWithUser(
        FakeAuthRepository(initialUser: _verifiedUser),
      );
      await pumpApp(tester, backend);

      await tester.tap(find.byTooltip('Bütçe'));
      await settle(tester);
      expect(find.text('Bu ay için bütçe belirlenmedi'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).first, '10.000');
      await tester.ensureVisible(find.text('Bütçeyi kaydet'));
      await tester.tap(find.text('Bütçeyi kaydet'));
      await settle(tester);

      final period = StatementCalculator.periodOf(DateTime.now());
      expect(backend.budgets.budgets.value.map((b) => b.id), [
        'user_${_verifiedUser.uid}_$period',
      ]);
      expect(backend.budgets.budgets.value.single.totalBudgetInCents, 1000000);
      expect(find.text('Bütçe kontrol altında'), findsOneWidget);
      await unmount(tester);
    },
  );

  testWidgets(
    'REGRESYON: davet kabul edilince takım aktif çalışma alanı olur',
    (tester) async {
      final backend = _BackendWithUser(
        FakeAuthRepository(initialUser: _verifiedUser),
      );
      final now = DateTime.now();
      backend.teams.myInvites.value = [
        TeamInvite(
          id: 'ABCD2345',
          teamId: 'team-1',
          teamName: 'Evimiz',
          invitedEmail: _verifiedUser.email,
          createdBy: 'owner-1',
          createdByName: 'Ali',
          createdAt: now,
          expiresAt: now.add(const Duration(days: 7)),
        ),
      ];
      await pumpApp(tester, backend);

      expect(find.text('Takım davetiniz var'), findsOneWidget);
      await tester.tap(find.text('Davetleri görüntüle'));
      await settle(tester);
      await tester.tap(find.text('Katıl'));
      await settle(tester);

      final profile = await backend.users.getProfile(_verifiedUser.uid);
      expect(profile?.activeTeamId, 'team-1');
      expect(find.textContaining('takımına katıldınız'), findsOneWidget);
      await unmount(tester);
    },
  );

  testWidgets(
    'REGRESYON: davet sorgusu hata verse de Özet ve Ayarlar çizilir (gri ekran yok)',
    (tester) async {
      final backend = _BackendWithUser(
        FakeAuthRepository(initialUser: _verifiedUser),
      );
      backend.teams.invitesError = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'failed-precondition',
      );
      await pumpApp(tester, backend);
      expect(tester.takeException(), isNull);
      expect(find.text('Merhaba, Ayşe'), findsOneWidget);

      await tester.tap(find.text('Ayarlar'));
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Takımlar ve aile'), findsOneWidget);
      await unmount(tester);
    },
  );

  testWidgets(
    'Geniş ekranda yan gezinme rayı, dar ekranda alt çubuk kullanılır',
    (tester) async {
      final backend = _BackendWithUser(
        FakeAuthRepository(initialUser: _verifiedUser),
      );
      await pumpApp(tester, backend, size: const Size(1280, 800));
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      await unmount(tester);

      final phone = _BackendWithUser(
        FakeAuthRepository(initialUser: _verifiedUser),
      );
      await pumpApp(tester, phone, size: const Size(390, 844));
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);

      // Sekmeler arası geçiş
      await tester.tap(find.text('Raporlar'));
      await settle(tester);
      expect(find.text('Son 6 ay'), findsOneWidget);
      await tester.tap(find.text('Kartlar'));
      await settle(tester);
      expect(find.text('Henüz kart eklemediniz'), findsOneWidget);
      await unmount(tester);
    },
  );
}

/// Belirli bir oturum kullanıcısıyla başlayan test ortamı.
class _BackendWithUser extends TestBackend {
  final FakeAuthRepository _auth;

  _BackendWithUser(this._auth);

  @override
  FakeAuthRepository get auth => _auth;
}
