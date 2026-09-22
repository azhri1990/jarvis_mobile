import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis/main.dart';

void main() {
  testWidgets('renders the Jarvis HUD', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('J.A.R.V.I.S'), findsOneWidget);
    expect(find.text('JARVIS STANDBY'), findsOneWidget);
    expect(find.text('CORE'), findsOneWidget);
    expect(find.byIcon(Icons.mic_none), findsOneWidget);
  });
}
