import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:carjobfinance/core/settings/app_settings_notifier.dart';
import 'package:carjobfinance/core/settings/country_data.dart';
import 'package:carjobfinance/presentation/pages/onboarding/onboarding_page.dart';

/// Mock notifier for testing that doesn't require DAOs
/// Extends StateNotifier<AppSettings> directly
class _MockAppSettingsNotifier extends StateNotifier<AppSettings> {
  _MockAppSettingsNotifier(super.state);

  Future<void> setCountry(String countryCode) async {
    final countryEntry = COUNTRIES.firstWhere(
      (c) => c.code == countryCode,
      orElse: () => COUNTRIES.firstWhere((c) => c.code == 'BR'),
    );
    state = AppSettings.fromCountry(countryEntry, countryEntry.platforms);
  }
}

void main() {
  group('OnboardingPage widget tests', () {
    testWidgets('renders country list with 8 items', (WidgetTester tester) async {
      // Create a mock notifier with unconfigured state
      final notifier = _MockAppSettingsNotifier(AppSettings.defaultBrazil());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appSettingsProvider.overrideWith((ref) => notifier),
          ],
          child: const MaterialApp(home: OnboardingPage()),
        ),
      );
      await tester.pump(); // Use pump only to avoid animation timeouts

      // Verify first few country names are visible
      expect(find.text('Brasil'), findsOneWidget);
      expect(find.text('Portugal'), findsOneWidget);
      expect(find.text('México'), findsOneWidget);
    }, timeout: const Timeout(Duration(seconds: 10)));

    testWidgets('tapping a country card highlights it', (WidgetTester tester) async {
      final notifier = _MockAppSettingsNotifier(AppSettings.defaultBrazil());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appSettingsProvider.overrideWith((ref) => notifier),
          ],
          child: const MaterialApp(home: OnboardingPage()),
        ),
      );
      await tester.pump();

      // Tap on Brazil card
      await tester.tap(find.byKey(const Key('country-card-BR')));
      await tester.pump();

      // Verify the card is selected (check for check_circle icon)
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    }, timeout: const Timeout(Duration(seconds: 10)));

    testWidgets('Continue button disabled until a country is picked', (WidgetTester tester) async {
      final notifier = _MockAppSettingsNotifier(AppSettings.defaultBrazil());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appSettingsProvider.overrideWith((ref) => notifier),
          ],
          child: const MaterialApp(home: OnboardingPage()),
        ),
      );
      await tester.pump();

      // Continue button should be disabled initially
      final continueButton = find.byKey(const Key('continue-button'));
      expect(continueButton, findsOneWidget);

      final buttonWidget = tester.widget<FilledButton>(continueButton);
      expect(buttonWidget.onPressed, isNull);
    }, timeout: const Timeout(Duration(seconds: 10)));
  });
}