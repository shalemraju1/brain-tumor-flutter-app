import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:brain_tumor_app/home_shell.dart';
import 'package:brain_tumor_app/main.dart';
import 'package:brain_tumor_app/login_screen.dart';

void main() {
  testWidgets('App renders login screen when no session exists', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const BrainTumorApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Secure medical login'), findsOneWidget);
  });

  testWidgets('App renders home shell when valid session exists', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'session_user_id': 7,
      'session_email': 'demo@brain.ai',
    });

    await tester.pumpWidget(const BrainTumorApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(HomeShell), findsOneWidget);
    expect(find.text('Dashboard'), findsOneWidget);
  });
}
