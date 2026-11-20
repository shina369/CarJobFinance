// One-line greeting above the dashboard's today card: "🌙 Boa noite, Ana".
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/language_provider.dart';
import '../../core/l10n/strings.dart';
import '../controllers/session_controller.dart';
import 'part_of_day_builder.dart';

class DashboardGreeting extends ConsumerWidget {
  const DashboardGreeting({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ts = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final lang = ref.watch(appLanguageProvider);
    final name = ref.watch(sessionProvider.select((s) => s.user?.firstName));

    return PartOfDayBuilder(
      builder: (context, period) {
        final greeting = lang.tr(period.greetingKey);
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final label = name == null ? greeting : '$greeting, $name';
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              isDark ? label : '${period.emoji} $label',
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
      },
    );
  }
}
