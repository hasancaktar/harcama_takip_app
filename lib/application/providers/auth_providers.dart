import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/app_user.dart';
import '../../domain/entities/user_profile.dart';
import 'repository_providers.dart';

/// Oturum durumu. `null` = oturum kapalı.
final authStateProvider = StreamProvider<AppUser?>((ref) {
  return ref.watch(authRepositoryProvider).userChanges();
});

/// Oturum açmış kullanıcı (doğrulanmış olsun ya da olmasın).
final currentUserProvider = Provider<AppUser?>(
  (ref) => ref.watch(authStateProvider).value,
);

/// Veri erişimi için kullanılacak kullanıcı kimliği.
///
/// Yalnızca e-postası DOĞRULANMIŞ kullanıcılar için dolu döner. Böylece doğrulanmamış
/// bir oturumda hiçbir Firestore sorgusu başlatılmaz (güvenlik kuralları da bunu reddeder).
final currentUserIdProvider = Provider<String?>((ref) {
  final user = ref.watch(currentUserProvider);
  return user != null && user.emailVerified ? user.uid : null;
});

final userProfileProvider = StreamProvider<UserProfile?>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return Stream.value(null);
  return ref.watch(userRepositoryProvider).watchProfile(uid);
});
