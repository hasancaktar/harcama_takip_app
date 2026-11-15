import '../entities/app_user.dart';

/// Kimlik doğrulama işlemleri. Hatalar `FirebaseAuthException` olarak fırlatılır ve
/// arayüzde `ErrorMessages.from` ile Türkçe mesaja çevrilir.
abstract class IAuthRepository {
  /// Oturum açma/kapama, profil güncelleme, token yenileme ve [reloadUser] çağrılarında yayın yapar.
  Stream<AppUser?> userChanges();
  AppUser? get currentUser;

  Future<void> signIn({required String email, required String password});

  /// Hesabı oluşturur, görünen adı ayarlar ve doğrulama e-postasını gönderir.
  Future<AppUser> register({
    required String email,
    required String password,
    required String displayName,
  });

  Future<void> sendPasswordResetEmail(String email);
  Future<void> sendEmailVerification();

  /// Sunucudan kullanıcı bilgisini tazeler. E-posta doğrulandıysa ID token'ı da
  /// yeniler (Firestore kurallarındaki `email_verified` alanının güncellenmesi için).
  Future<AppUser?> reloadUser();

  Future<void> updateDisplayName(String displayName);
  Future<void> reauthenticate(String password);
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });
  Future<void> signOut();

  /// Yalnızca kimlik doğrulama kaydını siler. Öncesinde [reauthenticate] çağrılmalıdır.
  Future<void> deleteCurrentUser();
}
