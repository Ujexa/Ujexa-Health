import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:ujexa_health/main.dart';

void main() {
  testWidgets('Ujexa Health app starts with its Material shell', (tester) async {
    await tester.pumpWidget(const UjexaHealthApp());
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('UJEXA HEALTH'), findsOneWidget);
  });
}
