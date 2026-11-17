import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harcama_takip/application/providers/repository_providers.dart';
import 'package:harcama_takip/application/services/account_service.dart';
import 'package:harcama_takip/application/services/notification_service.dart';
import 'package:harcama_takip/application/services/push_token_service.dart';
import 'package:harcama_takip/domain/entities/app_user.dart';

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
}
