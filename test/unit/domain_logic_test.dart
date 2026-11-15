import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harcama_takip/application/providers/budget_providers.dart';
import 'package:harcama_takip/application/providers/expense_providers.dart';
import 'package:harcama_takip/application/services/installment_posting_service.dart';
import 'package:harcama_takip/core/errors/error_messages.dart';
import 'package:harcama_takip/core/utils/statement_calculator.dart';
import 'package:harcama_takip/core/utils/stream_utils.dart';
import 'package:harcama_takip/core/utils/validators.dart';
import 'package:harcama_takip/domain/entities/app_user.dart';
import 'package:harcama_takip/domain/entities/budget.dart';
import 'package:harcama_takip/domain/entities/expense.dart';
import 'package:harcama_takip/domain/entities/installment_plan.dart';
import 'package:harcama_takip/domain/entities/team.dart';
import 'package:harcama_takip/domain/entities/team_invite.dart';
import 'package:harcama_takip/domain/entities/user_profile.dart';
import 'package:harcama_takip/presentation/navigation/auth_redirect.dart';

import '../helpers/fakes.dart';

Expense _expense(
  String id,
  int cents, {
  String category = 'market',
  String method = 'cash',
  String owner = 'u1',
  bool installment = false,
}) {
  final now = DateTime(2026, 11, 10);
  return Expense(
    id: id,
    ownerUid: owner,
    visibility: 'personal',
    title: id,
    amountInCents: cents,
    category: category,
    date: now,
    paymentMethod: method,
    isInstallment: installment,
    statementPeriod: '2026-11',
    createdBy: owner,
    createdAt: now,
    updatedAt: now,
  );
}

InstallmentPlan _plan({DateTime? start, String status = 'active'}) {
  final startDate = start ?? DateTime(2026, 9, 20);
  return InstallmentPlan(
    id: 'p1',
    ownerUid: 'u1',
    visibility: 'personal',
    title: 'Telefon',
    totalAmountInCents: 30000,
    totalInstallments: 3,
    cardId: 'c1',
    cardLast4: '1234',
    category: 'shopping',
    startDate: startDate,
    status: status,
    installmentSchedule: StatementCalculator.generateSchedule(
      startDate: startDate,
      cutoffDay: 15,
      totalInstallments: 3,
      installmentCentsList: const [10000, 10000, 10000],
    ),
    createdAt: startDate,
    updatedAt: startDate,
  );
}

void main() {
  group('Varlık ayrıştırma (fromMap)', () {
    test('Timestamp, ISO metin ve eksik alanlarla çökmeden ayrıştırır', () {
      final ts = Timestamp.fromDate(DateTime(2026, 11, 5, 10));
      final e = Expense.fromMap({
        'id': 'x',
        'ownerUid': 'u1',
        'title': 'Kahve',
        'amountInCents': 4500.0, // web istemcilerinde double gelebilir
        'date': ts, // bulut fonksiyonu Timestamp yazabilir
        'createdAt': '2026-11-05T10:00:00.000',
        'statementPeriod': '2026-11',
      });
      expect(e.amountInCents, 4500);
      expect(e.date, DateTime(2026, 11, 5, 10));
      expect(e.visibility, 'personal');
      expect(e.paymentMethod, 'cash');
      expect(e.tags, isEmpty);
    });

    test('REGRESYON: Expense.copyWith taksit sayısını sıfırlamaz', () {
      final e = Expense.fromMap({
        'id': 'p1_2_2026-12',
        'ownerUid': 'u1',
        'title': 'Telefon',
        'amountInCents': 100,
        'isInstallment': true,
        'installmentNumber': 2,
        'totalInstallments': 6,
        'statementPeriod': '2026-12',
      });
      expect(e.copyWith(title: 'Yeni').totalInstallments, 6);
    });

    test('Budget kanonik kimlik üretir ve kategori limitlerini okur', () {
      expect(
        Budget.idFor(ownerUid: 'u1', period: '2026-11'),
        'user_u1_2026-11',
      );
      expect(
        Budget.idFor(ownerUid: 'u1', teamId: 't1', period: '2026-11'),
        'team_t1_2026-11',
      );
      final b = Budget.fromMap({
        'categoryBudgetsInCents': {'market': 500.0, 'bad': 'x'},
      });
      expect(b.categoryBudgetsInCents, {'market': 500});
    });

    test('Team üye sayısını memberUids listesinden türetir', () {
      final t = Team.fromMap({
        'id': 't',
        'name': 'Ev',
        'ownerUid': 'a',
        'memberUids': ['a', 'b'],
        'memberCount': 9,
      });
      expect(t.memberCount, 2);
    });

    test('UserProfile hatırlatıcı günlerini temizler', () {
      final p = UserProfile.fromMap({
        'uid': 'u',
        'dailyReminderDays': [9, 3, 3, 1],
        'dailyReminderHour': 30,
      });
      expect(p.dailyReminderDays, [1, 3]);
      expect(p.dailyReminderHour, 23);
      expect(p.dailyReminderEnabled, isFalse);
    });

    test('TeamInvite süresi ve kullanılabilirliği', () {
      final invite = TeamInvite.fromMap({
        'inviteId': 'ABCD2345',
        'status': 'pending',
        'createdAt': Timestamp.fromDate(DateTime(2026, 11, 1)),
        'expiresAt': Timestamp.fromDate(DateTime(2026, 11, 8)),
      });
      expect(invite.code, 'ABCD2345');
      expect(invite.isUsable(DateTime(2026, 11, 7)), isTrue);
      expect(invite.isUsable(DateTime(2026, 11, 9)), isFalse);
    });

    test('InstallmentPlan bozuk takvim öğelerini atlar', () {
      final plan = InstallmentPlan.fromMap({
        'id': 'p',
        'totalInstallments': 2,
        'installmentSchedule': [
          {
            'installmentNumber': 1,
            'amountInCents': 10,
            'statementPeriod': '2026-11',
            'statementCutoffDate': '2026-11-15T23:59:59.000',
            'status': 'posted',
          },
          {'installmentNumber': 2, 'amountInCents': 10},
        ],
      });
      expect(plan.installmentSchedule, hasLength(1));
      expect(plan.postedCount, 1);
    });
  });

  group('İstatistik ve bütçe', () {
    test('ExpenseStats toplamları, dağılımları ve sıralamayı hesaplar', () {
      final stats = ExpenseStats.from([
        _expense('a', 1000, category: 'market'),
        _expense('b', 3000, category: 'bills', method: 'credit_card'),
        _expense(
          'c',
          2000,
          category: 'market',
          method: 'credit_card',
          installment: true,
          owner: 'u2',
        ),
      ]);
      expect(stats.totalCents, 6000);
      expect(stats.count, 3);
      expect(stats.averageCents, 2000);
      expect(stats.creditCardCents, 5000);
      expect(stats.installmentCents, 2000);
      expect(stats.byCategory.first.key, 'market');
      expect(stats.byCategory.first.cents, 3000);
      expect(stats.categoryCents('bills'), 3000);
      expect(stats.byMember.map((m) => m.key), ['u1', 'u2']);
      expect(stats.largest!.id, 'b');
      expect(ExpenseStats.from(const []).totalCents, 0);
    });

    test('BudgetStatus eşikleri', () {
      expect(
        const BudgetStatus(limitCents: 1000, spentCents: 500).level,
        BudgetLevel.safe,
      );
      expect(
        const BudgetStatus(limitCents: 1000, spentCents: 800).level,
        BudgetLevel.warning,
      );
      expect(
        const BudgetStatus(limitCents: 1000, spentCents: 950).level,
        BudgetLevel.critical,
      );
      expect(
        const BudgetStatus(limitCents: 1000, spentCents: 1001).level,
        BudgetLevel.exceeded,
      );
      expect(
        const BudgetStatus(limitCents: 1000, spentCents: 1200).remainingCents,
        -200,
      );
    });
  });

  group('Taksit işleme servisi', () {
    test('geçmiş tarihli planda vadesi gelen tüm taksitleri işler', () {
      final result = InstallmentPostingService.applyDuePostings(
        _plan(),
        now: DateTime(2026, 11, 20),
        actorUid: 'u1',
      );
      // 20 Eylül alışverişi, kesim 15 → dönemler 2026-10, 2026-11, 2026-12
      expect(result.postings.map((e) => e.statementPeriod), [
        '2026-10',
        '2026-11',
      ]);
      expect(result.postings.first.id, 'p1_1_2026-10');
      expect(result.postings.first.date, DateTime(2026, 9, 20));
      expect(
        result.postings.every(
          (e) => e.isInstallment && e.paymentMethod == 'credit_card',
        ),
        isTrue,
      );
      expect(result.plan.postedCount, 2);
      expect(result.plan.status, 'active');
    });

    test(
      'tüm taksitler işlenince plan tamamlanır; iptal edilmiş plan işlenmez',
      () {
        final done = InstallmentPostingService.applyDuePostings(
          _plan(),
          now: DateTime(2027, 1, 1),
          actorUid: 'u1',
        );
        expect(done.plan.status, 'completed');
        final cancelled = InstallmentPostingService.applyDuePostings(
          _plan(status: 'cancelled'),
          now: DateTime(2027, 1, 1),
          actorUid: 'u1',
        );
        expect(cancelled.hasChanges, isFalse);
      },
    );

    test('syncOwnPlans idempotenttir', () async {
      final repo = FakeInstallmentRepository()..plans.value = [_plan()];
      final service = InstallmentPostingService(repo);
      expect(await service.syncOwnPlans('u1', now: DateTime(2026, 11, 20)), 2);
      expect(await service.syncOwnPlans('u1', now: DateTime(2026, 11, 20)), 0);
      expect(repo.postedExpenses, hasLength(2));
    });
  });

  group('Doğrulayıcılar', () {
    test('e-posta', () {
      expect(Validators.email('ali@example.com'), isNull);
      expect(Validators.email(' ali@example.com '), isNull);
      expect(Validators.email('ali@'), isNotNull);
      expect(Validators.email(''), isNotNull);
    });

    test('yeni şifre en az 8 karakter, harf ve rakam içermeli', () {
      expect(Validators.newPassword('abc12345'), isNull);
      expect(Validators.newPassword('şifre2026'), isNull);
      expect(Validators.newPassword('abc123'), isNotNull);
      expect(Validators.newPassword('abcdefgh'), isNotNull);
      expect(Validators.newPassword('12345678'), isNotNull);
    });

    test('şifre tekrarı, tutar, son 4 hane, davet kodu', () {
      expect(Validators.confirmPassword(() => 'a')('b'), isNotNull);
      expect(Validators.confirmPassword(() => 'a')('a'), isNull);
      expect(Validators.amount('1.250'), isNull);
      expect(Validators.amount('12,505'), isNotNull);
      expect(Validators.amount('1250,50'), isNull);
      expect(Validators.optionalAmount(''), isNull);
      expect(Validators.last4Digits('12a4'), isNotNull);
      expect(Validators.last4Digits('1234'), isNull);
      expect(Validators.inviteCode('ABCD2345'), isNull);
      expect(Validators.inviteCode('ABC'), isNotNull);
      expect(
        Validators.requiredText('Başlık', maxLength: 3)('abcd'),
        isNotNull,
      );
    });
  });

  group('Hata mesajları', () {
    test('teknik hatalar kullanıcı dostu Türkçe mesaja çevrilir', () {
      expect(
        ErrorMessages.from(FirebaseAuthException(code: 'invalid-credential')),
        'E-posta veya şifre hatalı.',
      );
      expect(
        ErrorMessages.from(FirebaseAuthException(code: 'email-already-in-use')),
        contains('zaten bir hesap'),
      );
      expect(
        ErrorMessages.from(
          FirebaseException(
            plugin: 'cloud_firestore',
            code: 'permission-denied',
          ),
        ),
        contains('yetkiniz yok'),
      );
      expect(
        ErrorMessages.from(const AppException('Özel mesaj')),
        'Özel mesaj',
      );
      expect(ErrorMessages.from(StateError('x')), ErrorMessages.generic);
    });
  });

  group('Yönlendirme kuralları (e-posta doğrulama zorunluluğu)', () {
    test('oturum kapalıyken korumalı sayfalar girişe yönlenir ve dönüş adresi korunur', () {
      expect(
        resolveAuthRedirect(
          status: AuthStatus.signedOut,
          location: '/expenses',
        ),
        '/login?from=%2Fexpenses',
      );
      expect(
        resolveAuthRedirect(status: AuthStatus.signedOut, location: '/login'),
        isNull,
      );
      expect(
        resolveAuthRedirect(
          status: AuthStatus.signedOut,
          location: '/register',
        ),
        isNull,
      );
      expect(
        resolveAuthRedirect(
          status: AuthStatus.signedOut,
          location: '/verify-email',
        ),
        '/login',
      );
    });

    test('doğrulanmamış kullanıcı yalnızca doğrulama ekranını görebilir', () {
      expect(
        resolveAuthRedirect(
          status: AuthStatus.unverified,
          location: '/dashboard',
        ),
        '/verify-email',
      );
      expect(
        resolveAuthRedirect(status: AuthStatus.unverified, location: '/login'),
        '/verify-email',
      );
      expect(
        resolveAuthRedirect(
          status: AuthStatus.unverified,
          location: '/verify-email',
        ),
        isNull,
      );
    });

    test('doğrulanmış kullanıcı giriş sayfalarından uygulamaya yönlenir', () {
      expect(
        resolveAuthRedirect(status: AuthStatus.verified, location: '/login'),
        '/dashboard',
      );
      expect(
        resolveAuthRedirect(
          status: AuthStatus.verified,
          location: '/verify-email',
        ),
        '/dashboard',
      );
      expect(
        resolveAuthRedirect(
          status: AuthStatus.verified,
          location: '/login',
          from: '/budgets',
        ),
        '/budgets',
      );
      expect(
        resolveAuthRedirect(status: AuthStatus.verified, location: '/expenses'),
        isNull,
      );
    });

    test(
      'açık yönlendirme saldırılarına karşı yalnızca iç yollar kabul edilir',
      () {
        expect(
          resolveAuthRedirect(
            status: AuthStatus.verified,
            location: '/login',
            from: 'https://evil.com',
          ),
          '/dashboard',
        );
        expect(
          resolveAuthRedirect(
            status: AuthStatus.verified,
            location: '/login',
            from: '//evil.com',
          ),
          '/dashboard',
        );
        expect(
          resolveAuthRedirect(
            status: AuthStatus.verified,
            location: '/login',
            from: '/login',
          ),
          '/dashboard',
        );
      },
    );

    test('oturum yüklenirken açılış ekranı gösterilir', () {
      expect(
        resolveAuthRedirect(status: AuthStatus.loading, location: '/splash'),
        isNull,
      );
      expect(
        resolveAuthRedirect(status: AuthStatus.loading, location: '/reports'),
        '/splash?from=%2Freports',
      );
    });

    test('authStatusOf durumları doğru eşler', () {
      const u = AppUser(
        uid: 'u',
        email: 'e',
        displayName: 'd',
        emailVerified: false,
      );
      expect(authStatusOf(const AsyncLoading()), AuthStatus.loading);
      expect(authStatusOf(const AsyncData(null)), AuthStatus.signedOut);
      expect(authStatusOf(const AsyncData(u)), AuthStatus.unverified);
    });
  });

  group('Akış yardımcıları', () {
    test(
      'mergeListStreams kimliğe göre tekilleştirir ve güncellemeleri yayar',
      () async {
        final a = StreamController<List<String>>();
        final b = StreamController<List<String>>();
        final results = <List<String>>[];
        final sub = mergeListStreams<String>([
          a.stream,
          b.stream,
        ], idOf: (s) => s).listen(results.add);
        a.add(['x', 'y']);
        b.add(['y', 'z']);
        await Future<void>.delayed(Duration.zero);
        expect(results.last..sort(), ['x', 'y', 'z']);
        a.add(['x']);
        await Future<void>.delayed(Duration.zero);
        expect(results.last..sort(), ['x', 'y', 'z']);
        await sub.cancel();
        await a.close();
        await b.close();
      },
    );
  });

  test('AppUser baş harfleri', () {
    expect(AppUser.initialsOf('Ayşe Yılmaz'), 'AY');
    expect(AppUser.initialsOf('ali'), 'A');
    expect(AppUser.initialsOf('  '), '?');
  });
}
