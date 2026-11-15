import 'money_formatter.dart';

/// Form doğrulayıcıları. Hepsi saf fonksiyondur ve birim testleri vardır.
abstract class Validators {
  static final RegExp _emailPattern = RegExp(
    r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9-]+(\.[a-zA-Z0-9-]+)*\.[a-zA-Z]{2,}$",
  );

  static const int minPasswordLength = 8;

  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'E-posta adresi gerekli';
    if (!_emailPattern.hasMatch(v)) return 'Geçerli bir e-posta adresi girin';
    return null;
  }

  /// Giriş ekranı için: yalnızca boş olmamasını kontrol eder (eski hesapları kilitlememek için).
  static String? loginPassword(String? value) {
    if (value == null || value.isEmpty) return 'Şifre gerekli';
    return null;
  }

  /// Yeni şifre için: en az 8 karakter, en az bir harf ve bir rakam.
  static String? newPassword(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Şifre gerekli';
    if (v.length < minPasswordLength) {
      return 'Şifre en az $minPasswordLength karakter olmalı';
    }
    if (!RegExp(r'[A-Za-zÇĞİÖŞÜçğıöşü]').hasMatch(v) ||
        !RegExp(r'\d').hasMatch(v)) {
      return 'Şifre en az bir harf ve bir rakam içermeli';
    }
    return null;
  }

  static String? Function(String?) confirmPassword(String Function() original) {
    return (value) {
      if (value == null || value.isEmpty) return 'Şifreyi tekrar girin';
      if (value != original()) return 'Şifreler eşleşmiyor';
      return null;
    };
  }

  static String? displayName(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Ad soyad gerekli';
    if (v.length < 2) return 'Ad soyad en az 2 karakter olmalı';
    if (v.length > 60) return 'Ad soyad en fazla 60 karakter olabilir';
    return null;
  }

  static String? Function(String?) requiredText(
    String fieldName, {
    int maxLength = 100,
  }) {
    return (value) {
      final v = value?.trim() ?? '';
      if (v.isEmpty) return '$fieldName gerekli';
      if (v.length > maxLength) {
        return '$fieldName en fazla $maxLength karakter olabilir';
      }
      return null;
    };
  }

  static String? Function(String?) optionalText(
    String fieldName, {
    int maxLength = 500,
  }) {
    return (value) {
      if ((value?.trim().length ?? 0) > maxLength) {
        return '$fieldName en fazla $maxLength karakter olabilir';
      }
      return null;
    };
  }

  static String? amount(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Tutar gerekli';
    if (MoneyFormatter.parseToCents(v) <= 0) {
      return 'Geçerli bir tutar girin (örn. 1250,50)';
    }
    return null;
  }

  static String? optionalAmount(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return null;
    return amount(v);
  }

  static String? last4Digits(String? value) {
    final v = value?.trim() ?? '';
    if (!RegExp(r'^\d{4}$').hasMatch(v)) return 'Kartın son 4 hanesini girin';
    return null;
  }

  static String? inviteCode(String? value) {
    final v = value?.trim() ?? '';
    if (!RegExp(r'^[A-Za-z0-9]{8}$').hasMatch(v)) {
      return 'Davet kodu 8 karakter olmalı';
    }
    return null;
  }
}
