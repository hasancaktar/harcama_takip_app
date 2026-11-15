import 'package:flutter/widgets.dart';

/// Kimlik doğrulama sağlayıcısından bağımsız oturum kullanıcısı.
@immutable
class AppUser {
  final String uid;
  final String email;
  final String displayName;
  final bool emailVerified;

  const AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.emailVerified,
  });

  /// Avatarlarda gösterilecek baş harf(ler).
  String get initials =>
      initialsOf(displayName.isNotEmpty ? displayName : email);

  static String initialsOf(String text) {
    final parts = text
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }

  @override
  bool operator ==(Object other) =>
      other is AppUser &&
      other.uid == uid &&
      other.email == email &&
      other.displayName == displayName &&
      other.emailVerified == emailVerified;

  @override
  int get hashCode => Object.hash(uid, email, displayName, emailVerified);
}
