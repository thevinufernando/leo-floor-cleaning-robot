// This is a basic Flutter widget test for the Leo Robot Vacuum application.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package.

import 'package:flutter_test/flutter_test.dart';

import 'package:first_app_test/main.dart';

void main() {
  testWidgets('Leo Robot Vacuum app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that the greetings and robot name are present.
    expect(find.text('Hello'), findsOneWidget);
    expect(find.text('LEO'), findsOneWidget);

    // Verify that the Home Screen placeholder is initially displayed.
    expect(find.text('Ready to Clean'), findsOneWidget);
    expect(find.text('BATTERY'), findsOneWidget);
    expect(find.text('85%'), findsOneWidget);
    expect(find.text('MODE'), findsOneWidget);
    expect(find.text('Auto Mode'), findsOneWidget);
    expect(find.text('Quick Actions'), findsOneWidget);
    expect(find.text('Pause'), findsOneWidget);
    expect(find.text('Dock'), findsOneWidget);
    expect(find.text('Spot Clean'), findsOneWidget);
    expect(find.text('Map Screen'), findsNothing);

    // Tap on the 'Map' navigation item.
    await tester.tap(find.text('Map'));
    await tester.pump();

    // Verify that the placeholder content has updated to Map Screen.
    expect(find.text('Ready to Clean'), findsNothing);
    expect(find.text('Map Screen'), findsOneWidget);
  });
}
