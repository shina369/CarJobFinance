import 'package:carjobfinance/core/time/part_of_day.dart';
import 'package:carjobfinance/presentation/widgets/sky_backdrop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _cardWidth = 330.0;

Future<void> _pump(WidgetTester tester, DateTime now) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [clockProvider.overrideWithValue(() => now)],
      child: const MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: _cardWidth,
              height: 170,
              child: SkyBackdrop(),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('day: faded sun on the right third with clouds', (tester) async {
    await _pump(tester, DateTime(2026, 11, 19, 10));

    expect(find.text('☀️'), findsOneWidget);
    expect(find.text('☁️'), findsWidgets);
    expect(find.byIcon(Icons.star_rounded), findsNothing);

    final emoji = tester.getRect(find.byKey(const Key('sky.emoji')));
    expect(emoji.width, greaterThanOrEqualTo(_cardWidth / 3));
    expect(emoji.center.dx, greaterThan(_cardWidth * 2 / 3));

    final opacity = tester.widget<Opacity>(find
        .ancestor(of: find.text('☀️'), matching: find.byType(Opacity))
        .first);
    expect(opacity.opacity, lessThan(1));
  });

  testWidgets('night: faded moon with stars and no clouds', (tester) async {
    await _pump(tester, DateTime(2026, 11, 19, 22));

    expect(find.text('🌙'), findsOneWidget);
    expect(find.byIcon(Icons.star_rounded), findsWidgets);
    expect(find.text('☁️'), findsNothing);
    expect(find.text('☀️'), findsNothing);
  });
}
