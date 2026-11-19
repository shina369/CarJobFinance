import 'package:carjobfinance/core/auth/auth_repository.dart';
import 'package:carjobfinance/core/l10n/language_provider.dart';
import 'package:carjobfinance/core/l10n/languages.dart';
import 'package:carjobfinance/core/time/part_of_day.dart';
import 'package:carjobfinance/presentation/controllers/session_controller.dart';
import 'package:carjobfinance/presentation/widgets/dashboard_greeting.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(
  WidgetTester tester, {
  required DateTime now,
  AuthUser? user,
  String languageTag = 'pt_BR',
}) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        clockProvider.overrideWithValue(() => now),
        appLanguageProvider.overrideWithValue(languageForTag(languageTag)!),
        sessionProvider.overrideWith(
          (ref) => SessionController(ref, SessionState(user: user)),
        ),
      ],
      child: const MaterialApp(home: Scaffold(body: DashboardGreeting())),
    ),
  );
}

String _text(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(Key(key))).data!;

const _ana = AuthUser(id: 'u1', email: 'ana@example.com', firstName: 'Ana');

void main() {
  testWidgets('morning: Bom dia, name and a sun on one line', (tester) async {
    await _pump(tester, now: DateTime(2026, 11, 19, 8), user: _ana);
    expect(_text(tester, 'dash.greeting'), 'Bom dia, Ana ☀️');
    expect(find.textContaining('Bem-vindo'), findsNothing);
  });

  testWidgets('afternoon: Boa tarde with a sun', (tester) async {
    await _pump(tester, now: DateTime(2026, 11, 19, 15), user: _ana);
    expect(_text(tester, 'dash.greeting'), 'Boa tarde, Ana ☀️');
  });

  testWidgets('night: Boa noite with a moon', (tester) async {
    await _pump(tester, now: DateTime(2026, 11, 19, 22), user: _ana);
    expect(_text(tester, 'dash.greeting'), 'Boa noite, Ana 🌙');
  });

  testWidgets('without a first name shows only the greeting', (tester) async {
    await _pump(tester, now: DateTime(2026, 11, 19, 8));
    expect(_text(tester, 'dash.greeting'), 'Bom dia ☀️');
  });

  testWidgets('follows the app language', (tester) async {
    await _pump(tester,
        now: DateTime(2026, 11, 19, 22), user: _ana, languageTag: 'en_US');
    expect(_text(tester, 'dash.greeting'), 'Good evening, Ana 🌙');
  });
}
