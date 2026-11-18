import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harcama_takip/presentation/widgets/keyboard_lifecycle_guard.dart';

Future<FocusNode> _pumpField(
  WidgetTester tester, {
  required bool enabled,
}) async {
  final node = FocusNode();
  addTearDown(node.dispose);
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) =>
          KeyboardLifecycleGuard(enabledOverride: enabled, child: child!),
      home: Scaffold(body: TextField(focusNode: node)),
    ),
  );
  await tester.tap(find.byType(TextField));
  await tester.pump();
  expect(node.hasFocus, isTrue);
  return node;
}

void main() {
  testWidgets('uygulama arka plana geçerken klavye (odak) kapatılır', (
    tester,
  ) async {
    final node = await _pumpField(tester, enabled: true);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(node.hasFocus, isFalse);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(node.hasFocus, isFalse);
  });

  testWidgets('kapalıyken (web/iOS) odağa dokunulmaz', (tester) async {
    final node = await _pumpField(tester, enabled: false);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(node.hasFocus, isTrue);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
  });
}
