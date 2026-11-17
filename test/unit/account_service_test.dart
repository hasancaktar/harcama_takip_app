import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harcama_takip/application/providers/auth_providers.dart';
import 'package:harcama_takip/application/providers/repository_providers.dart';
import 'package:harcama_takip/application/providers/team_providers.dart';
import 'package:harcama_takip/application/services/account_service.dart';
import 'package:harcama_takip/application/services/notification_service.dart';
import 'package:harcama_takip/application/services/push_token_service.dart';
import 'package:harcama_takip/domain/entities/app_user.dart';
import 'package:harcama_takip/domain/entities/team.dart';
import 'package:harcama_takip/domain/entities/team_member.dart';

import '../helpers/fakes.dart';

class FailingPushTokenService extends PushTokenService {
  FailingPushTokenService(super.userRepository);

  @override
  Future<void> unregister() async {
    throw Exception('Push token servisi hatası');
  }
}

class FailingNotificationService extends NotificationService {
  FailingNotificationService() : super.forTesting();

  @override
  Future<void> cancelReminders() async {
    throw Exception('Hatırlatıcı iptal platform hatası');
  }
}

void main() {
  group('AccountService.signOut dayanıklılık testleri', () {
    test('Normal koşullarda çıkış başarılı olur', () async {
      final backend = TestBackend();
      await backend.auth.register(
        email: 'user@test.com',
        password: 'password',
        displayName: 'Test',
      );

      final container = ProviderContainer(overrides: backend.overrides);
      addTearDown(container.dispose);

      final service = container.read(accountServiceProvider);
      await expectLater(service.signOut(), completes);
      expect(backend.auth.currentUser, isNull);
    });

    test('PushTokenService unregister hata fırlatsa bile çıkış tamamlanır ve hata fırlatmaz', () async {
      final backend = TestBackend();
      final container = ProviderContainer(
        overrides: [
          ...backend.overrides,
          pushTokenServiceProvider.overrideWithValue(
            FailingPushTokenService(backend.users),
          ),
        ],
      );
      addTearDown(container.dispose);

      final user = AppUser(
        uid: 'u-1',
        email: 'u1@test.com',
        displayName: 'U1',
        emailVerified: true,
      );
      await backend.auth.register(
        email: user.email,
        password: 'password123',
        displayName: user.displayName,
      );

      final service = container.read(accountServiceProvider);
      await expectLater(service.signOut(), completes);
      expect(backend.auth.currentUser, isNull);
    });

    test('NotificationService cancelReminders hata fırlatsa bile çıkış tamamlanır ve hata fırlatmaz', () async {
      final backend = TestBackend();
      final container = ProviderContainer(
        overrides: [
          ...backend.overrides,
          notificationServiceProvider.overrideWithValue(
            FailingNotificationService(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final service = container.read(accountServiceProvider);
      await expectLater(service.signOut(), completes);
      expect(backend.auth.currentUser, isNull);
    });

    test('Hem Push hem Bildirim servisi hata verse bile kullanıcı başarıyla çıkış yapar', () async {
      final backend = TestBackend();
      final container = ProviderContainer(
        overrides: [
          ...backend.overrides,
          pushTokenServiceProvider.overrideWithValue(
            FailingPushTokenService(backend.users),
          ),
          notificationServiceProvider.overrideWithValue(
            FailingNotificationService(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final service = container.read(accountServiceProvider);
      await expectLater(service.signOut(), completes);
      expect(backend.auth.currentUser, isNull);
    });
  });

  group('AccountService.updateDisplayName ve üye adı güncelleme', () {
    test('İsim güncellendiğinde auth, profil ve takım üyelerindeki isim güncellenir', () async {
      final backend = TestBackend();
      final user = await backend.auth.register(
        email: 'hasan@test.com',
        password: 'password123',
        displayName: 'Eski İsim',
      );
      backend.auth.verifyOnReload = true;
      await backend.auth.reloadUser();
      await backend.users.ensureProfile(
        uid: user.uid,
        email: user.email,
        displayName: 'Eski İsim',
      );
      final now = DateTime.now();
      backend.teams.teams.value = [
        Team(
          id: 'team-1',
          name: 'Aile',
          ownerUid: user.uid,
          memberUids: [user.uid],
          createdAt: now,
          updatedAt: now,
        ),
      ];
      backend.teams.members.value = [
        TeamMember(
          uid: user.uid,
          teamId: 'team-1',
          displayName: 'Eski İsim',
          email: user.email,
          role: 'owner',
          joinedAt: now,
          invitedBy: user.uid,
        ),
      ];

      final container = ProviderContainer(overrides: backend.overrides);
      addTearDown(container.dispose);
      final sub = container.listen(currentUserProvider, (_, __) {});
      addTearDown(sub.close);
      final profileSub = container.listen(userProfileProvider, (_, __) {});
      addTearDown(profileSub.close);
      await container.read(authStateProvider.future);
      await container.read(userProfileProvider.future);

      final service = container.read(accountServiceProvider);
      await service.updateDisplayName('Yeni İsim');
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(backend.auth.currentUser?.displayName, 'Yeni İsim');
      final updatedProfile = await backend.users.getProfile(user.uid);
      expect(updatedProfile?.displayName, 'Yeni İsim');
      expect(backend.teams.members.value.first.displayName, 'Yeni İsim');

      // memberNamesProvider oturumdaki kullanıcının güncel adını yansıtır
      final memberNames = container.read(memberNamesProvider);
      expect(memberNames[user.uid], 'Yeni İsim');
    });
  });
}
