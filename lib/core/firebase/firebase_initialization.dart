import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../../firebase_options.dart';

class FirebaseInitResult {
  final bool isSuccess;
  final String? errorMessage;

  const FirebaseInitResult({required this.isSuccess, this.errorMessage});
}

/// Firebase'i başlatır. Yerel geliştirme ve uçtan uca testler için emülatör desteği:
///
/// ```
/// flutter run --dart-define=USE_FIREBASE_EMULATOR=true [--dart-define=FIREBASE_EMULATOR_HOST=10.0.2.2]
/// ```
abstract class FirebaseInitialization {
  static const bool useEmulator = bool.fromEnvironment('USE_FIREBASE_EMULATOR');
  static const String emulatorHost = String.fromEnvironment(
    'FIREBASE_EMULATOR_HOST',
    defaultValue: 'localhost',
  );

  static Future<FirebaseInitResult> initialize() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      if (!kIsWeb) {
        // Mobilde çevrimdışı kalıcılık açık; önbellek boyutunu sınırlı tut.
        // Not: ayarlar, emülatör yapılandırmasından ÖNCE verilmelidir.
        FirebaseFirestore.instance.settings = const Settings(
          persistenceEnabled: true,
          cacheSizeBytes: 50 * 1024 * 1024,
        );
      }

      if (useEmulator) {
        if (kIsWeb) {
          // Web'de kayıtlı oturum, Auth örneği oluşturulur oluşturulmaz (emülatöre
          // bağlanmadan önce) gerçek sunucuda doğrulanmaya çalışılır ve
          // connectAuthEmulator sessizce başarısız olur. Bunu önlemek için emülatör
          // modunda Auth örneği kalıcılıksız (bellek içi) başlatılır.
          // setPersistence() bu sorunu çözmez (geri yükleme ondan önce başlar); bu yüzden
          // kullanımdan kaldırılmış olsa da başlangıç parametresi bilinçli olarak kullanılır.
          FirebaseAuth.instanceFor(
            app: Firebase.app(),
            // ignore: deprecated_member_use
            persistence: Persistence.NONE,
          );
        }
        await FirebaseAuth.instance.useAuthEmulator(emulatorHost, 9099);
        FirebaseFirestore.instance.useFirestoreEmulator(emulatorHost, 8080);
        debugPrint('[FirebaseInit] Emülatörler kullanılıyor: $emulatorHost');
      }
      return const FirebaseInitResult(isSuccess: true);
    } catch (e) {
      debugPrint('[FirebaseInit] Başlatma hatası: $e');
      return FirebaseInitResult(isSuccess: false, errorMessage: e.toString());
    }
  }
}
