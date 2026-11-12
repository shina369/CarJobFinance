import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/currencies.dart';
import '../../../core/l10n/currency_provider.dart';
import '../../../core/l10n/language_provider.dart';
import '../../../core/l10n/languages.dart';
import '../../../core/l10n/strings.dart';

class OptionPickerPage<T> extends StatelessWidget {
  const OptionPickerPage({
    super.key,
    required this.title,
    required this.options,
    required this.selected,
    required this.labelOf,
    required this.onSelected,
  });

  final String title;
  final List<T> options;
  final T selected;
  final String Function(T option) labelOf;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: options.length,
        itemBuilder: (context, index) {
          final option = options[index];
          final isSelected = option == selected;
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              selected: isSelected,
              title: Text(labelOf(option)),
              trailing: isSelected
                  ? Icon(Icons.check_circle, color: cs.primary)
                  : Icon(Icons.radio_button_unchecked,
                      color: cs.onSurface.withValues(alpha: 0.3)),
              onTap: () => onSelected(option),
            ),
          );
        },
      ),
    );
  }
}

class LanguagePickerPage extends ConsumerWidget {
  const LanguagePickerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(appLanguageProvider);
    return OptionPickerPage<AppLanguage>(
      title: current.tr('settings.language'),
      options: SUPPORTED_LANGUAGES,
      selected: current,
      labelOf: (lang) => lang.flag != null
          ? '${lang.flag}  ${lang.displayName}'
          : lang.displayName,
      onSelected: (lang) =>
          ref.read(languageProvider.notifier).setLanguage(lang),
    );
  }
}

class CurrencyPickerPage extends ConsumerWidget {
  const CurrencyPickerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(appLanguageProvider);
    final current = ref.watch(appCurrencyProvider);
    return OptionPickerPage<AppCurrency>(
      title: lang.tr('settings.chooseCurrency'),
      options: SUPPORTED_CURRENCIES,
      selected: current,
      labelOf: (currency) => '${currency.symbol}  ${currency.displayName}',
      onSelected: (currency) =>
          ref.read(currencyProvider.notifier).setCurrency(currency),
    );
  }
}
