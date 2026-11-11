import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harcama_takip/core/firebase/firebase_initialization.dart';
import 'package:harcama_takip/main.dart';

void main() {
  testWidgets('App smoke test when Firebase is uninitialized', (WidgetTester tester) async {
    const initResult = FirebaseInitResult(
      isSuccess: false,
      errorMessage: 'Test environment: no Firebase credentials',
    );

    await tester.pumpWidget(
      const ProviderScope(
        child: ExpenseTrackerApp(initResult: initResult),
      ),
    );

    // Rehber ekranının başlığının render edildiğini doğrula
    expect(find.text('Firebase Kurulum Yönergesi'), findsOneWidget);
    expect(find.text('Firebase Henüz Yapılandırılmadı'), findsOneWidget);
  });
}
