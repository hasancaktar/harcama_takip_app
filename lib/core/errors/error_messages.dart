import 'package:firebase_auth/firebase_auth.dart';

/// Uygulama içinde kullanıcıya gösterilebilecek, anlamlı mesaj taşıyan istisna.
class AppException implements Exception {
  final String message;
  final String? code;

  const AppException(this.message, {this.code});

  @override
  String toString() => message;
}

/// Teknik hataları kullanıcıya gösterilebilecek Türkçe mesajlara çevirir.
///
/// Ham istisna metinleri (ör. "[cloud_firestore/permission-denied] ...") asla
/// doğrudan kullanıcıya gösterilmez.
abstract class ErrorMessages {
  static const String generic =
      'Beklenmeyen bir hata oluştu. Lütfen tekrar deneyin.';

  static String from(Object error) {
    if (error is AppException) return error.message;
    if (error is FirebaseAuthException) return auth(error.code);
    if (error is FirebaseException) return firestore(error.code);
    return generic;
  }

  static String auth(String code) {
    switch (code) {
      case 'invalid-email':
        return 'E-posta adresi geçersiz.';
      case 'user-disabled':
        return 'Bu hesap devre dışı bırakılmış. Destek ile iletişime geçin.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
      case 'INVALID_LOGIN_CREDENTIALS':
        return 'E-posta veya şifre hatalı.';
      case 'email-already-in-use':
        return 'Bu e-posta adresiyle zaten bir hesap var. Giriş yapmayı deneyin.';
      case 'weak-password':
        return 'Şifre çok zayıf. En az 8 karakter, harf ve rakam kullanın.';
      case 'too-many-requests':
        return 'Çok fazla deneme yapıldı. Lütfen birkaç dakika sonra tekrar deneyin.';
      case 'network-request-failed':
        return 'İnternet bağlantısı kurulamadı. Bağlantınızı kontrol edin.';
      case 'requires-recent-login':
        return 'Güvenliğiniz için bu işlemden önce şifrenizi yeniden girmeniz gerekiyor.';
      case 'operation-not-allowed':
        return 'E-posta/şifre ile giriş bu projede etkin değil.';
      case 'missing-email':
        return 'E-posta adresi gerekli.';
      case 'expired-action-code':
      case 'invalid-action-code':
        return 'Bağlantının süresi dolmuş veya geçersiz. Yeni bir bağlantı isteyin.';
      case 'user-mismatch':
        return 'Girilen bilgiler mevcut oturumla eşleşmiyor.';
      default:
        return 'Kimlik doğrulama başarısız oldu. Lütfen tekrar deneyin.';
    }
  }

  static String firestore(String code) {
    switch (code) {
      case 'permission-denied':
        return 'Bu işlem için yetkiniz yok. E-posta adresinizin doğrulandığından emin olun.';
      case 'unavailable':
      case 'deadline-exceeded':
        return 'Sunucuya ulaşılamıyor. Bağlantınızı kontrol edip tekrar deneyin.';
      case 'not-found':
        return 'Kayıt bulunamadı veya silinmiş.';
      case 'already-exists':
        return 'Bu kayıt zaten mevcut.';
      case 'failed-precondition':
        return 'İşlem şu anda tamamlanamadı (veritabanı dizini eksik olabilir).';
      case 'resource-exhausted':
        return 'Kullanım kotası aşıldı. Lütfen daha sonra tekrar deneyin.';
      case 'unauthenticated':
        return 'Oturumunuzun süresi doldu. Lütfen tekrar giriş yapın.';
      case 'invalid-argument':
        return 'Gönderilen bilgiler geçersiz.';
      default:
        return generic;
    }
  }
}
