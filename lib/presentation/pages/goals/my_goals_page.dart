// MyGoalsPage – profit goal for each month of a chosen year.
// Blank fields mean no goal for that month; only the fields the user edited
// are written when saving.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/l10n/currency_provider.dart' as currency_pkg;
import '../../../core/l10n/language_provider.dart';
import '../../../core/l10n/strings.dart';
import '../../controllers/controllers.dart';

class MyGoalsPage extends ConsumerStatefulWidget {
  const MyGoalsPage({super.key});

  @override
  ConsumerState<MyGoalsPage> createState() => _MyGoalsPageState();
}

class _MyGoalsPageState extends ConsumerState<MyGoalsPage> {
  int _year = DateTime.now().year;

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(appLanguageProvider);
    final goalsState = ref.watch(monthlyGoalsForYearProvider(_year));

    return Scaffold(
      appBar: AppBar(title: Text(lang.tr('goals.title'))),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => setState(() => _year--),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    '$_year',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => _year++),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
          Expanded(
            child: goalsState.when(
              data: (goals) => _GoalsForm(
                key: ValueKey(_year),
                year: _year,
                goals: goals,
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Text(
                  lang.tr('error.generic', args: {'error': '$error'}),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalsForm extends ConsumerStatefulWidget {
  const _GoalsForm({super.key, required this.year, required this.goals});

  final int year;
  final Map<int, double?> goals;

  @override
  ConsumerState<_GoalsForm> createState() => _GoalsFormState();
}

class _GoalsFormState extends ConsumerState<_GoalsForm> {
  late final Map<int, TextEditingController> _controllers;
  late final Map<int, String> _savedText;
  final Set<int> _invalid = {};

  @override
  void initState() {
    super.initState();
    _controllers = {
      for (final entry in widget.goals.entries)
        entry.key: TextEditingController(text: _format(entry.value)),
    };
    _savedText = {
      for (final entry in _controllers.entries) entry.key: entry.value.text,
    };
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  static String _format(double? value) =>
      value == null ? '' : value.toStringAsFixed(2).replaceAll('.', ',');

  static String _capitalize(String text) =>
      text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);

  Future<void> _save() async {
    final changes = <int, double?>{};
    final invalid = <int>{};

    for (final entry in _controllers.entries) {
      final text = entry.value.text.trim();
      if (text == _savedText[entry.key]) continue;
      if (text.isEmpty) {
        changes[entry.key] = null;
        continue;
      }
      final value = double.tryParse(text.replaceAll(',', '.'));
      if (value == null || value < 0) {
        invalid.add(entry.key);
      } else {
        changes[entry.key] = value;
      }
    }

    setState(() {
      _invalid
        ..clear()
        ..addAll(invalid);
    });
    if (invalid.isNotEmpty) return;

    await ref
        .read(monthlyGoalControllerProvider.notifier)
        .saveGoalsForYear(widget.year, changes);
    ref.invalidate(monthlyGoalsForYearProvider(widget.year));
    if (!mounted) return;

    setState(() {
      for (final entry in _controllers.entries) {
        _savedText[entry.key] = entry.value.text;
      }
    });
    final lang = ref.read(appLanguageProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(lang.tr('goals.saved'))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(appLanguageProvider);
    final locale = ref.watch(appLocaleProvider);
    final symbol = ref.watch(currency_pkg.appCurrencyProvider).symbol;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            children: [
              Text(
                lang.tr('goals.subtitle'),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              for (var month = 1; month <= 12; month++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: TextField(
                    controller: _controllers[month],
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: _capitalize(
                          DateFormat('MMMM', locale.toString())
                              .format(DateTime(widget.year, month))),
                      hintText: lang.tr('goals.notSet'),
                      prefixText: '$symbol ',
                      errorText: _invalid.contains(month)
                          ? lang.tr('goals.invalid')
                          : null,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _save,
                child: Text(lang.tr('dash.save')),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
