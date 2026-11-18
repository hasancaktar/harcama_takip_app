import '../constants/app_constants.dart';

import 'package:harcama_takip/core/l10n/app_locale.dart';
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
  static String get generic =>
      'Beklenmeyen bir hata oluştu. Lütfen tekrar deneyin.'.tr;

  static String from(Object error) {
    if (error is AppException) return error.message;
    if (error is FirebaseAuthException) return auth(error.code);
    if (error is FirebaseException) return firestore(error.code);
    return generic;
  }

  /// Yönetici tarafından pasife alınan hesap için gösterilen mesaj.
  static String get accountDisabled =>
      'Hesabınız devre dışı bırakıldı. Bilgi için: {0}'.trArgs([
        AppConstants.contactEmail,
      ]);

  static String auth(String code) {
    switch (code) {
      case 'invalid-email':
        return 'E-posta adresi geçersiz.'.tr;
      case 'user-disabled':
        return accountDisabled;
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
      case 'INVALID_LOGIN_CREDENTIALS':
        return 'E-posta veya şifre hatalı.'.tr;
      case 'email-already-in-use':
        return 'Bu e-posta adresiyle zaten bir hesap var. Giriş yapmayı deneyin.'
            .tr;
      case 'weak-password':
        return 'Şifre çok zayıf. En az 8 karakter, harf ve rakam kullanın.'.tr;
      case 'too-many-requests':
        return 'Çok fazla deneme yapıldı. Lütfen birkaç dakika sonra tekrar deneyin.'
            .tr;
      case 'network-request-failed':
        return 'İnternet bağlantısı kurulamadı. Bağlantınızı kontrol edin.'.tr;
      case 'requires-recent-login':
        return 'Güvenliğiniz için bu işlemden önce şifrenizi yeniden girmeniz gerekiyor.'
            .tr;
      case 'operation-not-allowed':
        return 'E-posta/şifre ile giriş bu projede etkin değil.'.tr;
      case 'missing-email':
        return 'E-posta adresi gerekli.'.tr;
      case 'expired-action-code':
      case 'invalid-action-code':
        return 'Bağlantının süresi dolmuş veya geçersiz. Yeni bir bağlantı isteyin.'
            .tr;
      case 'user-mismatch':
        return 'Girilen bilgiler mevcut oturumla eşleşmiyor.'.tr;
      default:
        return 'Kimlik doğrulama başarısız oldu. Lütfen tekrar deneyin.'.tr;
    }
  }

  static String firestore(String code) {
    switch (code) {
      case 'permission-denied':
        return 'Bu işlem için yetkiniz yok. E-posta adresinizin doğrulandığından emin olun.'
            .tr;
      case 'unavailable':
      case 'deadline-exceeded':
        return 'Sunucuya ulaşılamıyor. Bağlantınızı kontrol edip tekrar deneyin.'
            .tr;
      case 'not-found':
        return 'Kayıt bulunamadı veya silinmiş.'.tr;
      case 'already-exists':
        return 'Bu kayıt zaten mevcut.'.tr;
      case 'failed-precondition':
        return 'İşlem şu anda tamamlanamadı (veritabanı dizini eksik olabilir).'
            .tr;
      case 'resource-exhausted':
        return 'Kullanım kotası aşıldı. Lütfen daha sonra tekrar deneyin.'.tr;
      case 'unauthenticated':
        return 'Oturumunuzun süresi doldu. Lütfen tekrar giriş yapın.'.tr;
      case 'invalid-argument':
        return 'Gönderilen bilgiler geçersiz.'.tr;
      default:
        return generic;
    }
  }
}
