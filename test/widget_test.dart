// Test básico para StemBosque
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:stem_bosque/main.dart';

void main() {
  testWidgets('StemBosque app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const StemBosqueApp());

    // Verify that the app title is present
    expect(find.text('StemBosque IDE'), findsOneWidget);
  });
}
