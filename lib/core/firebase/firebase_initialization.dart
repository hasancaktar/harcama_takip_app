import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class FirebaseInitResult {
  final bool isSuccess;
  final String? errorMessage;

  const FirebaseInitResult({required this.isSuccess, this.errorMessage});
}

abstract class FirebaseInitialization {
  static Future<FirebaseInitResult> initialize() async {
    try {
      await Firebase.initializeApp();
      debugPrint('[FirebaseInit] Firebase başarıyla başlatıldı.');
      return const FirebaseInitResult(isSuccess: true);
    } catch (e) {
      debugPrint('[FirebaseInit] Başlatma uyarısı / hatası: $e');
      return FirebaseInitResult(
        isSuccess: false,
        errorMessage: e.toString(),
      );
    }
  }
}
