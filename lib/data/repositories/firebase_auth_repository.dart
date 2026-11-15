import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/entities/app_user.dart';
import '../../domain/repositories/i_auth_repository.dart';

class FirebaseAuthRepository implements IAuthRepository {
  final FirebaseAuth _auth;
  final StreamController<AppUser?> _manualUpdates =
      StreamController<AppUser?>.broadcast();

  FirebaseAuthRepository({FirebaseAuth? auth})
    : _auth = auth ?? FirebaseAuth.instance;

  static AppUser? _map(User? user) {
    if (user == null) return null;
    return AppUser(
      uid: user.uid,
      email: user.email ?? '',
      displayName: user.displayName ?? '',
      emailVerified: user.emailVerified,
    );
  }

  User _requireUser() {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'Oturum bulunamadı.',
      );
    }
    return user;
  }

  @override
  Stream<AppUser?> userChanges() {
    // Dinleyici iptal edildiğinde onCancel içinde kapatılır.
    // ignore: close_sinks
    late StreamController<AppUser?> controller;
    StreamSubscription<User?>? authSub;
    StreamSubscription<AppUser?>? manualSub;
    controller = StreamController<AppUser?>(
      onListen: () {
        authSub = _auth.userChanges().listen(
          (u) => controller.add(_map(u)),
          onError: controller.addError,
        );
        manualSub = _manualUpdates.stream.listen(controller.add);
      },
      onCancel: () async {
        await authSub?.cancel();
        await manualSub?.cancel();
        await controller.close();
      },
    );
    return controller.stream.distinct();
  }

  @override
  AppUser? get currentUser => _map(_auth.currentUser);

  @override
  Future<void> signIn({required String email, required String password}) async {
    await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  @override
  Future<AppUser> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = cred.user!;
    await user.updateDisplayName(displayName.trim());
    try {
      await user.sendEmailVerification();
    } on FirebaseAuthException {
      // Hesap oluşturuldu; e-posta gönderimi başarısız olsa bile kullanıcı
      // doğrulama ekranından tekrar gönderebilir.
    }
    await user.reload();
    return _map(_auth.currentUser) ?? _map(user)!;
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.setLanguageCode('tr');
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  @override
  Future<void> sendEmailVerification() async {
    final user = _requireUser();
    if (user.emailVerified) return;
    await _auth.setLanguageCode('tr');
    await user.sendEmailVerification();
  }

  @override
  Future<AppUser?> reloadUser() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    await user.reload();
    final refreshed = _auth.currentUser;
    if (refreshed != null && refreshed.emailVerified) {
      // Yeni ID token "email_verified: true" içerir; güvenlik kuralları buna bakar.
      await refreshed.getIdToken(true);
    }
    final mapped = _map(_auth.currentUser);
    _manualUpdates.add(mapped);
    return mapped;
  }

  @override
  Future<void> updateDisplayName(String displayName) async {
    final user = _requireUser();
    await user.updateDisplayName(displayName.trim());
    await user.reload();
    _manualUpdates.add(_map(_auth.currentUser));
  }

  @override
  Future<void> reauthenticate(String password) async {
    final user = _requireUser();
    final credential = EmailAuthProvider.credential(
      email: user.email ?? '',
      password: password,
    );
    await user.reauthenticateWithCredential(credential);
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await reauthenticate(currentPassword);
    await _requireUser().updatePassword(newPassword);
  }

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Future<void> deleteCurrentUser() async {
    await _requireUser().delete();
  }
}
