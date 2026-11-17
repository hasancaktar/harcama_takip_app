import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/app_user.dart';

enum AuthStatus { loading, signedOut, unverified, verified }

AuthStatus authStatusOf(AsyncValue<AppUser?> auth) {
  if (auth.isLoading && !auth.hasValue) return AuthStatus.loading;
  final user = auth.valueOrNull;
  if (user == null) return AuthStatus.signedOut;
  return user.emailVerified ? AuthStatus.verified : AuthStatus.unverified;
}

abstract class AppRoutes {
  static const splash = '/splash';
  static const login = '/login';
  static const register = '/register';
  static const forgotPassword = '/forgot-password';
  static const verifyEmail = '/verify-email';
  static const dashboard = '/dashboard';

  static const publicRoutes = {login, register, forgotPassword};
}

/// Oturum durumuna göre yönlendirme kararı (saf fonksiyon; birim testi vardır).
///
/// - Oturum kontrol ediliyorsa: açılış ekranı.
/// - Oturum kapalıysa: yalnızca giriş/kayıt/şifre sıfırlama sayfaları.
/// - E-posta doğrulanmamışsa: yalnızca doğrulama ekranı (korumalı alanlara erişim yok).
/// - Doğrulanmışsa: giriş sayfaları yerine istenen sayfa veya özet.
///
/// [location] mevcut yol (sorgu parametresiz), [fullLocation] sorgu parametreleriyle
/// birlikte tam konum, [from] giriş sonrası dönülecek (iç) yol.
String? resolveAuthRedirect({
  required AuthStatus status,
  required String location,
  String? fullLocation,
  String? from,
  bool isAdmin = false,
}) {
  final target = fullLocation ?? location;
  final safeFrom = _sanitizeFrom(from);
  final isPublic = AppRoutes.publicRoutes.contains(location);
  final isSplash = location == AppRoutes.splash;
  final isVerify = location == AppRoutes.verifyEmail;

  switch (status) {
    case AuthStatus.loading:
      if (isSplash) return null;
      return _withFrom(
        AppRoutes.splash,
        (isPublic || isVerify) ? safeFrom : target,
      );
    case AuthStatus.signedOut:
      if (isPublic) return null;
      return _withFrom(
        AppRoutes.login,
        (isSplash || isVerify) ? safeFrom : target,
      );
    case AuthStatus.unverified:
      if (isVerify) return null;
      return AppRoutes.verifyEmail;
    case AuthStatus.verified:
      // Yönetim paneli yalnızca yöneticiye açıktır (asıl koruma Firestore kurallarındadır).
      if (location.startsWith('/admin') && !isAdmin) {
        return AppRoutes.dashboard;
      }
      if (isPublic || isSplash || isVerify) {
        return safeFrom ?? AppRoutes.dashboard;
      }
      return null;
  }
}

String _withFrom(String path, String? from) {
  if (from == null || from == '/' || from == AppRoutes.dashboard) return path;
  return Uri(path: path, queryParameters: {'from': from}).toString();
}

/// Açık yönlendirme (open redirect) saldırılarına karşı yalnızca uygulama içi yolları kabul eder.
String? _sanitizeFrom(String? from) {
  if (from == null || from.isEmpty) return null;
  if (!from.startsWith('/') || from.startsWith('//') || from.contains('://')) {
    return null;
  }
  final path = Uri.tryParse(from)?.path ?? '';
  if (AppRoutes.publicRoutes.contains(path) ||
      path == AppRoutes.splash ||
      path == AppRoutes.verifyEmail) {
    return null;
  }
  return from;
}
