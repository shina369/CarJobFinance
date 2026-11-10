import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:carjobfinance/presentation/pages/onboarding/onboarding_page.dart';

void main() {
  testWidgets('simple onboarding page render', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: OnboardingPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Bem-vindo ao CarJobFinance'), findsOneWidget);
  }, timeout: const Timeout(Duration(seconds: 10)));
}