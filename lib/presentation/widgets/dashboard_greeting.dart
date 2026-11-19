// One-line greeting above the dashboard's today card: "Boa noite, Ana 🌙".
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/language_provider.dart';
import '../../core/l10n/strings.dart';
import '../../core/time/part_of_day.dart';
import '../controllers/session_controller.dart';

class DashboardGreeting extends ConsumerStatefulWidget {
  const DashboardGreeting({super.key});

  @override
  ConsumerState<DashboardGreeting> createState() => _DashboardGreetingState();
}

class _DashboardGreetingState extends ConsumerState<DashboardGreeting> {
  late final Timer _ticker;

  @override
  void initState() {
    super.initState();
    // Re-checks the clock so the greeting turns over while the app stays open.
    _ticker =
        Timer.periodic(const Duration(minutes: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ts = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final lang = ref.watch(appLanguageProvider);
    final period = PartOfDay.of(ref.watch(clockProvider)());
    final name = ref.watch(sessionProvider.select((s) => s.user?.firstName));

    final greeting = lang.tr(period.greetingKey);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(
          '${period.emoji} ${name == null ? greeting : '$greeting, $name'}',
          key: const Key('dash.greeting'),
          textAlign: TextAlign.center,
          style: ts.titleLarge?.copyWith(
            color: cs.onSurface,
            fontWeight: FontWeight.w700,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
