import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../domain/entities/admin_models.dart';
import 'auth_providers.dart';
import 'repository_providers.dart';

/// Oturumdaki kullanıcı yönetici mi? (Yalnızca arayüz içindir; gerçek yetki
/// Firestore kurallarında ve Cloud Functions'ta denetlenir.)
final isAdminProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider);
  return user != null &&
      user.emailVerified &&
      user.email.toLowerCase() == AppConstants.adminEmail;
});

/// Yönetici tanımlı kategoriler. Her güncellemede [CategoryRegistry] yenilenir;
/// okuma başarısız olursa yerleşik kategorilerle devam edilir.
final categoriesProvider = StreamProvider<List<CategoryItem>>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) {
    CategoryRegistry.update(const []);
    return Stream.value(CategoryRegistry.all);
  }
  return ref
      .watch(categoryRepositoryProvider)
      .watchAll()
      .transform(
        StreamTransformer<List<CategoryItem>, List<CategoryItem>>.fromHandlers(
          handleData: (remote, sink) {
            CategoryRegistry.update(remote);
            sink.add(CategoryRegistry.all);
          },
          handleError: (error, stack, sink) {
            debugPrint(
              '[Categories] Okunamadı, varsayılanlar kullanılıyor: $error',
            );
            CategoryRegistry.update(const []);
            sink.add(CategoryRegistry.all);
          },
        ),
      );
});

/// Firestore'da yönetici tanımlı kategori var mı? (Yoksa yerleşikler gösteriliyordur.)
final remoteCategoriesProvider = StreamProvider.autoDispose<List<CategoryItem>>(
  (ref) => ref.watch(categoryRepositoryProvider).watchAll(),
);

final reminderConfigProvider = StreamProvider.autoDispose<ReminderConfig>(
  (ref) => ref.watch(adminRepositoryProvider).watchReminderConfig(),
);

final campaignsProvider =
    StreamProvider.autoDispose<List<NotificationCampaign>>(
      (ref) => ref.watch(adminRepositoryProvider).watchCampaigns(),
    );

final adminLogsProvider = StreamProvider.autoDispose<List<AdminLogEntry>>(
  (ref) => ref.watch(adminRepositoryProvider).watchLogs(),
);

final adminUsersProvider = FutureProvider.autoDispose<List<AdminUserSummary>>(
  (ref) => ref.watch(adminRepositoryProvider).fetchUsers(),
);
