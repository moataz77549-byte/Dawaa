import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dawa_hayah/features/anatomy/viewer.dart';

void main() {
  testWidgets('missing WebView uses the local 2D fallback', (tester) async {
    const channel = MethodChannel('ye.moataz.dawa/storage');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => false);
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });
    await tester.pumpWidget(const MaterialApp(home: ModelViewer()));
    await tester.pumpAndSettle();
    expect(find.text('3D unavailable / تعذر عرض المجسم'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
