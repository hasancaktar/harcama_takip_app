import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harcama_takip/application/providers/repository_providers.dart';
import 'package:harcama_takip/application/providers/settings_providers.dart';
import 'package:harcama_takip/application/services/notification_service.dart';
import 'package:harcama_takip/application/services/push_token_service.dart';
import 'package:harcama_takip/core/constants/app_constants.dart';
import 'package:harcama_takip/core/utils/statement_calculator.dart';
import 'package:harcama_takip/domain/entities/admin_models.dart';
import 'package:harcama_takip/domain/entities/app_user.dart';
import 'package:harcama_takip/domain/entities/budget.dart';
import 'package:harcama_takip/domain/entities/credit_card.dart';
import 'package:harcama_takip/domain/entities/expense.dart';
import 'package:harcama_takip/domain/entities/installment_plan.dart';
import 'package:harcama_takip/domain/entities/team.dart';
import 'package:harcama_takip/domain/entities/team_invite.dart';
import 'package:harcama_takip/domain/entities/team_member.dart';
import 'package:harcama_takip/domain/entities/user_profile.dart';
import 'package:harcama_takip/domain/repositories/i_admin_repository.dart';
import 'package:harcama_takip/domain/repositories/i_auth_repository.dart';
import 'package:harcama_takip/domain/repositories/i_budget_repository.dart';
import 'package:harcama_takip/domain/repositories/i_card_repository.dart';
import 'package:harcama_takip/domain/repositories/i_expense_repository.dart';
import 'package:harcama_takip/domain/repositories/i_installment_repository.dart';
import 'package:harcama_takip/domain/repositories/i_team_repository.dart';
import 'package:harcama_takip/domain/repositories/i_user_repository.dart';

/// Son değeri hatırlayan basit akış (BehaviorSubject benzeri).
class ValueStream<T> {
  T _value;
  final _controller = StreamController<T>.broadcast();

  ValueStream(this._value);

  T get value => _value;
  set value(T v) {
    _value = v;
    _controller.add(v);
  }

  Stream<T> get stream async* {
    yield _value;
    yield* _controller.stream;
  }
}

class FakeAuthRepository implements IAuthRepository {
  final ValueStream<AppUser?> _user;
  final Map<String, String> passwords = {};
  bool verifyOnReload = false;
  int verificationEmailsSent = 0;
  int reloadCalls = 0;
  Object? signInError;

  FakeAuthRepository({AppUser? initialUser}) : _user = ValueStream(initialUser);

  @override
  Stream<AppUser?> userChanges() => _user.stream;

  @override
  AppUser? get currentUser => _user.value;

  @override
  Future<void> signIn({required String email, required String password}) async {
    if (signInError != null) throw signInError!;
    final normalized = email.trim().toLowerCase();
    if (passwords[normalized] != password) {
      throw FirebaseAuthException(code: 'invalid-credential');
    }
    _user.value = AppUser(
      uid: 'uid-$normalized',
      email: normalized,
      displayName: 'Test Kullanıcı',
      emailVerified: false,
    );
  }

  @override
  Future<AppUser> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final normalized = email.trim().toLowerCase();
    if (passwords.containsKey(normalized)) {
      throw FirebaseAuthException(code: 'email-already-in-use');
    }
    passwords[normalized] = password;
    verificationEmailsSent++;
    final user = AppUser(
      uid: 'uid-$normalized',
      email: normalized,
      displayName: displayName,
      emailVerified: false,
    );
    _user.value = user;
    return user;
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {}

  @override
  Future<void> sendEmailVerification() async => verificationEmailsSent++;

  @override
  Future<AppUser?> reloadUser() async {
    reloadCalls++;
    final u = _user.value;
    if (u != null && verifyOnReload && !u.emailVerified) {
      _user.value = AppUser(
        uid: u.uid,
        email: u.email,
        displayName: u.displayName,
        emailVerified: true,
      );
    }
    return _user.value;
  }

  @override
  Future<void> updateDisplayName(String displayName) async {
    final u = _user.value!;
    _user.value = AppUser(
      uid: u.uid,
      email: u.email,
      displayName: displayName,
      emailVerified: u.emailVerified,
    );
  }

  @override
  Future<void> reauthenticate(String password) async {}

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {}

  @override
  Future<void> signOut() async => _user.value = null;

  @override
  Future<void> deleteCurrentUser() async => _user.value = null;
}

class FakeUserRepository implements IUserRepository {
  final Map<String, ValueStream<UserProfile?>> _profiles = {};

  ValueStream<UserProfile?> _of(String uid) =>
      _profiles.putIfAbsent(uid, () => ValueStream(null));

  @override
  Stream<UserProfile?> watchProfile(String uid) => _of(uid).stream;

  @override
  Future<UserProfile?> getProfile(String uid) async => _of(uid).value;

  @override
  Future<void> ensureProfile({
    required String uid,
    required String email,
    required String displayName,
  }) async {
    if (_of(uid).value != null) return;
    final now = DateTime.now();
    _of(uid).value = UserProfile(
      uid: uid,
      email: email,
      displayName: displayName,
      createdAt: now,
      updatedAt: now,
    );
  }

  UserProfile _require(String uid) {
    final p = _of(uid).value;
    if (p != null) return p;
    final now = DateTime.now();
    return UserProfile(
      uid: uid,
      email: '',
      displayName: '',
      createdAt: now,
      updatedAt: now,
    );
  }

  UserProfile _copy(
    UserProfile p, {
    String? displayName,
    String? activeTeamId,
    bool clearTeam = false,
  }) {
    return UserProfile(
      uid: p.uid,
      email: p.email,
      displayName: displayName ?? p.displayName,
      dailyReminderEnabled: p.dailyReminderEnabled,
      dailyReminderHour: p.dailyReminderHour,
      dailyReminderMinute: p.dailyReminderMinute,
      dailyReminderDays: p.dailyReminderDays,
      activeTeamId: clearTeam ? null : (activeTeamId ?? p.activeTeamId),
      createdAt: p.createdAt,
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<void> updateDisplayName(String uid, String displayName) async =>
      _of(uid).value = _copy(_require(uid), displayName: displayName);

  @override
  Future<void> updateReminderSettings({
    required String uid,
    required bool enabled,
    required int hour,
    required int minute,
    required List<int> days,
  }) async {}

  @override
  Future<void> setActiveTeam(String uid, String? teamId) async =>
      _of(uid).value = _copy(
        _require(uid),
        activeTeamId: teamId,
        clearTeam: teamId == null,
      );

  @override
  Future<void> setPushEnabled(String uid, bool enabled) async {}

  @override
  Future<void> setLanguage(String uid, String languageCode) async {}

  @override
  Future<void> addPushToken(String uid, String token) async {}

  @override
  Future<void> removePushToken(String uid, String token) async {}
}

class FakeExpenseRepository implements IExpenseRepository {
  final ValueStream<List<Expense>> _all = ValueStream(const []);

  List<Expense> get all => _all.value;

  void seed(List<Expense> expenses) => _all.value = [...expenses];

  Stream<List<Expense>> _where(bool Function(Expense) test) => _all.stream.map(
    (list) =>
        list.where((e) => e.status == 'active' && test(e)).toList()
          ..sort((a, b) => b.date.compareTo(a.date)),
  );

  @override
  Stream<List<Expense>> watchPersonalExpenses({
    required String uid,
    required List<String> periods,
  }) => _where(
    (e) =>
        e.ownerUid == uid &&
        e.visibility == 'personal' &&
        periods.contains(e.statementPeriod),
  );

  @override
  Stream<List<Expense>> watchTeamExpenses({
    required String teamId,
    required List<String> periods,
  }) => _where(
    (e) =>
        e.teamId == teamId &&
        e.visibility == 'team' &&
        periods.contains(e.statementPeriod),
  );

  @override
  Stream<List<Expense>> watchCardExpenses({
    required String cardId,
    required String uid,
    String? sharedTeamId,
    required String period,
  }) => _where(
    (e) =>
        e.cardId == cardId && e.statementPeriod == period && e.ownerUid == uid,
  );

  @override
  Stream<Expense?> watchExpense(String expenseId) => _all.stream.map((list) {
    for (final e in list) {
      if (e.id == expenseId && e.status == 'active') return e;
    }
    return null;
  });

  @override
  Future<void> createExpense(Expense expense) async =>
      _all.value = [..._all.value, expense];

  @override
  Future<void> updateExpense(Expense expense) async => _all.value = [
    for (final e in _all.value) e.id == expense.id ? expense : e,
  ];

  @override
  Future<void> softDeleteExpense(String expenseId, String deletedByUid) async =>
      _all.value = [
        for (final e in _all.value)
          e.id == expenseId ? e.copyWith(status: 'deleted') : e,
      ];
}

class FakeCardRepository implements ICardRepository {
  final ValueStream<List<CreditCard>> _cards = ValueStream(const []);

  void seed(List<CreditCard> cards) => _cards.value = cards;

  @override
  Stream<List<CreditCard>> watchOwnCards(String uid) => _cards.stream.map(
    (l) => l.where((c) => c.ownerUid == uid && c.isActive).toList(),
  );

  @override
  Stream<List<CreditCard>> watchTeamSharedCards(String teamId) =>
      _cards.stream.map(
        (l) =>
            l.where((c) => c.teamId == teamId && c.isSharedWithTeam).toList(),
      );

  @override
  Stream<CreditCard?> watchCard(String cardId) => _cards.stream.map((l) {
    for (final c in l) {
      if (c.id == cardId) return c;
    }
    return null;
  });

  @override
  Future<void> saveCard(CreditCard card) async =>
      _cards.value = [..._cards.value.where((c) => c.id != card.id), card];

  @override
  Future<void> deactivateCard(String cardId) async =>
      _cards.value = _cards.value.where((c) => c.id != cardId).toList();
}

class FakeInstallmentRepository implements IInstallmentRepository {
  final ValueStream<List<InstallmentPlan>> plans = ValueStream(const []);
  final List<Expense> postedExpenses = [];

  @override
  Stream<List<InstallmentPlan>> watchOwnPlans(String uid) =>
      plans.stream.map((l) => l.where((p) => p.ownerUid == uid).toList());

  @override
  Stream<List<InstallmentPlan>> watchTeamPlans(String teamId) =>
      plans.stream.map((l) => l.where((p) => p.teamId == teamId).toList());

  @override
  Stream<InstallmentPlan?> watchPlan(String planId) => plans.stream.map((l) {
    for (final p in l) {
      if (p.id == planId) return p;
    }
    return null;
  });

  @override
  Future<List<InstallmentPlan>> getActiveOwnPlans(String uid) async =>
      plans.value.where((p) => p.ownerUid == uid && p.isActive).toList();

  @override
  Future<void> savePlanWithPostings(
    InstallmentPlan plan,
    List<Expense> postings,
  ) async {
    plans.value = [...plans.value.where((p) => p.id != plan.id), plan];
    postedExpenses.addAll(postings);
  }

  @override
  Future<void> cancelPlan(
    InstallmentPlan plan, {
    required String actorUid,
    DateTime? now,
  }) async {
    // Gerçek depo gibi: ekstreye yansımamış taksit harcamaları silinir.
    final at = now ?? DateTime.now();
    final removed = <String>{};
    final schedule = [
      for (final item in plan.installmentSchedule)
        if (item.isPosted && !InstallmentPlan.isBilledAt(item, at))
          () {
            removed.add(InstallmentPostingPolicy.expenseIdFor(plan.id, item));
            return item.copyWith(status: 'upcoming');
          }()
        else
          item,
    ];
    cancelledExpenseIds.addAll(removed);
    plans.value = [
      for (final p in plans.value)
        p.id == plan.id
            ? p.copyWith(status: 'cancelled', installmentSchedule: schedule)
            : p,
    ];
  }

  /// İptalde silinen taksit harcamalarının kimlikleri.
  final Set<String> cancelledExpenseIds = {};
}

class FakeBudgetRepository implements IBudgetRepository {
  final ValueStream<List<Budget>> budgets = ValueStream(const []);

  @override
  Stream<Budget?> watchBudget({
    required String ownerUid,
    String? teamId,
    required String period,
  }) {
    final id = Budget.idFor(ownerUid: ownerUid, teamId: teamId, period: period);
    return budgets.stream.map((l) {
      for (final b in l) {
        if (b.id == id) return b;
      }
      return null;
    });
  }

  @override
  Future<void> saveBudget(Budget budget) async => budgets.value = [
    ...budgets.value.where((b) => b.id != budget.id),
    budget,
  ];

  @override
  Future<void> deleteBudget(String budgetId) async =>
      budgets.value = budgets.value.where((b) => b.id != budgetId).toList();
}

class FakeTeamRepository implements ITeamRepository {
  final ValueStream<List<Team>> teams = ValueStream(const []);
  final ValueStream<List<TeamInvite>> myInvites = ValueStream(const []);
  final ValueStream<List<TeamMember>> members = ValueStream(const []);

  @override
  Stream<List<Team>> watchUserTeams(String uid) => teams.stream.map(
    (l) => l.where((t) => t.memberUids.contains(uid)).toList(),
  );
  @override
  Stream<Team?> watchTeam(String teamId) => teams.stream.map((l) {
    for (final t in l) {
      if (t.id == teamId) return t;
    }
    return null;
  });
  @override
  Stream<List<TeamMember>> watchMembers(String teamId) => members.stream;
  @override
  Stream<List<TeamInvite>> watchPendingTeamInvites(String teamId) =>
      Stream.value(const []);

  /// Canlıdaki gibi sorgu hatası (ör. eksik dizin) simülasyonu.
  Object? invitesError;

  @override
  Stream<List<TeamInvite>> watchMyPendingInvites(String email) =>
      invitesError != null ? Stream.error(invitesError!) : myInvites.stream;
  @override
  Future<void> createTeam(Team team, TeamMember ownerMember) async =>
      teams.value = [...teams.value, team];
  @override
  Future<void> updateTeam({
    required String teamId,
    required String name,
    String? description,
    required String colorHex,
  }) async {}
  @override
  Future<TeamInvite> createInvite({
    required Team team,
    required String email,
    required AppUser invitedBy,
  }) => throw UnimplementedError();
  @override
  Future<void> revokeInvite({
    required String teamId,
    required String inviteId,
  }) async {}
  @override
  Future<void> acceptInvite({
    required TeamInvite invite,
    required AppUser user,
  }) async {
    // Gerçek Firestore davranışı gibi: davet listeden düşer, takım üyeliklere eklenir.
    myInvites.value = myInvites.value.where((i) => i.id != invite.id).toList();
    final now = DateTime.now();
    teams.value = [
      ...teams.value,
      Team(
        id: invite.teamId,
        name: invite.teamName,
        ownerUid: invite.createdBy,
        memberUids: [invite.createdBy, user.uid],
        createdAt: now,
        updatedAt: now,
      ),
    ];
    // Ağ gecikmesi: bu sırada davet kartı ağaçtan kaldırılır (gerçek uygulamadaki gibi).
    await Future<void>.delayed(const Duration(milliseconds: 150));
  }

  @override
  Future<void> declineInvite(TeamInvite invite) async {}
  @override
  Future<void> removeMember({
    required String teamId,
    required String memberUid,
  }) async {}
  @override
  Future<void> leaveTeam({required String teamId, required String uid}) async {}
  @override
  Future<void> updateMemberDisplayName({
    required String uid,
    required String displayName,
  }) async {
    members.value = [
      for (final m in members.value)
        if (m.uid == uid)
          TeamMember(
            uid: m.uid,
            teamId: m.teamId,
            displayName: displayName,
            email: m.email,
            role: m.role,
            status: m.status,
            joinedAt: m.joinedAt,
            invitedBy: m.invitedBy,
            inviteId: m.inviteId,
          )
        else
          m,
    ];
  }

  @override
  Future<void> archiveTeam(String teamId) async {}
}

class FakeNotificationService extends NotificationService {
  FakeNotificationService() : super.forTesting();

  @override
  bool get isSupported => false;
}

class FakePushTokenService extends PushTokenService {
  FakePushTokenService(super.userRepository);

  @override
  Future<void> register(String uid) async {}

  @override
  Future<void> unregister() async {}
}

class FakeCategoryRepository implements ICategoryRepository {
  final categories = ValueStream<List<CategoryItem>>(const []);

  @override
  Stream<List<CategoryItem>> watchAll() => categories.stream;
}

/// Yönetim paneli işlemlerini bellekte tutar; her yazma bir işlem kaydı ekler.
class FakeAdminRepository implements IAdminRepository {
  final FakeCategoryRepository _categoryRepo;
  final reminder = ValueStream<ReminderConfig>(const ReminderConfig());
  final campaigns = ValueStream<List<NotificationCampaign>>(const []);
  final logs = ValueStream<List<AdminLogEntry>>(const []);
  List<AdminUserSummary> users = const [];

  FakeAdminRepository(this._categoryRepo);

  void _log(AppUser admin, String action, String summary) {
    logs.value = [
      AdminLogEntry(
        id: 'log-${logs.value.length + 1}',
        action: action,
        summary: summary,
        adminEmail: admin.email,
        createdAt: DateTime.now(),
      ),
      ...logs.value,
    ];
  }

  void _setCategories(List<CategoryItem> list) {
    _categoryRepo.categories.value = [...list]
      ..sort((a, b) => a.order.compareTo(b.order));
  }

  @override
  Future<void> saveCategory(
    AppUser admin,
    CategoryItem category, {
    required bool isNew,
  }) async {
    _setCategories([
      for (final c in _categoryRepo.categories.value)
        if (c.id != category.id) c,
      category,
    ]);
    _log(admin, isNew ? 'category.create' : 'category.update', category.nameTr);
  }

  @override
  Future<void> saveCategoryOrder(
    AppUser admin,
    List<CategoryItem> ordered,
  ) async {
    _setCategories([
      for (var i = 0; i < ordered.length; i++) ordered[i].copyWith(order: i),
    ]);
    _log(admin, 'category.reorder', ordered.map((c) => c.nameTr).join(', '));
  }

  @override
  Future<void> setCategoryDeleted(
    AppUser admin,
    CategoryItem category, {
    required bool deleted,
  }) async {
    _setCategories([
      for (final c in _categoryRepo.categories.value)
        c.id == category.id ? c.copyWith(isDeleted: deleted) : c,
    ]);
    _log(
      admin,
      deleted ? 'category.delete' : 'category.restore',
      category.nameTr,
    );
  }

  @override
  Future<void> importDefaultCategories(AppUser admin) async {
    final defaults = AppConstants.defaultCategories;
    _setCategories([
      for (var i = 0; i < defaults.length; i++) defaults[i].copyWith(order: i),
    ]);
    _log(admin, 'category.import_defaults', '${defaults.length} kategori');
  }

  @override
  Stream<ReminderConfig> watchReminderConfig() => reminder.stream;

  @override
  Future<void> saveReminderConfig(AppUser admin, ReminderConfig config) async {
    reminder.value = config;
    _log(admin, 'reminder.update', config.enabled ? 'açık' : 'kapalı');
  }

  @override
  Stream<List<NotificationCampaign>> watchCampaigns({int limit = 50}) =>
      campaigns.stream;

  @override
  Future<void> createCampaign(
    AppUser admin, {
    required String titleTr,
    required String bodyTr,
    required String titleEn,
    required String bodyEn,
    required String target,
    required List<String> targetUids,
  }) async {
    campaigns.value = [
      NotificationCampaign(
        id: 'campaign-${campaigns.value.length + 1}',
        titleTr: titleTr,
        bodyTr: bodyTr,
        titleEn: titleEn,
        bodyEn: bodyEn,
        target: target,
        targetUids: targetUids,
        createdByEmail: admin.email,
        createdAt: DateTime.now(),
      ),
      ...campaigns.value,
    ];
    _log(admin, 'notification.send', titleTr);
  }

  @override
  Future<List<AdminUserSummary>> fetchUsers({int limit = 500}) async => users;

  @override
  Stream<List<AdminLogEntry>> watchLogs({int limit = 100}) => logs.stream;
}

/// Tüm Firebase bağımlılıklarını sahteleriyle değiştiren test ortamı.
class TestBackend {
  final auth = FakeAuthRepository();
  final users = FakeUserRepository();
  final expenses = FakeExpenseRepository();
  final cards = FakeCardRepository();
  final installments = FakeInstallmentRepository();
  final budgets = FakeBudgetRepository();
  final teams = FakeTeamRepository();
  final categories = FakeCategoryRepository();
  late final admin = FakeAdminRepository(categories);

  List<Override> get overrides => [
    authRepositoryProvider.overrideWithValue(auth),
    userRepositoryProvider.overrideWithValue(users),
    expenseRepositoryProvider.overrideWithValue(expenses),
    cardRepositoryProvider.overrideWithValue(cards),
    installmentRepositoryProvider.overrideWithValue(installments),
    budgetRepositoryProvider.overrideWithValue(budgets),
    teamRepositoryProvider.overrideWithValue(teams),
    categoryRepositoryProvider.overrideWithValue(categories),
    adminRepositoryProvider.overrideWithValue(admin),
    notificationServiceProvider.overrideWithValue(FakeNotificationService()),
    pushTokenServiceProvider.overrideWithValue(FakePushTokenService(users)),
    isOnlineProvider.overrideWith((ref) => Stream.value(true)),
  ];
}
