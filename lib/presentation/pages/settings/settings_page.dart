// ignore_for_file: deprecated_member_use
// Settings Page - Configurações
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/currencies.dart';
import '../../../core/l10n/currency_provider.dart';
import '../../../core/l10n/language_provider.dart';
import '../../../core/l10n/languages.dart';
import '../../../core/l10n/platforms_provider.dart';
import '../../../core/l10n/strings.dart';
import '../../../core/theme/app_theme.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(appLanguageProvider);
    String tr(String key) => lang.tr(key);

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('settings.title')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Aparência
          _SectionHeader(tr('settings.appearance')),
          Card(
            child: Column(
              children: [
                Consumer(
                  builder: (context, ref, _) {
                    final themeMode = ref.watch(themeModeProvider);
                    return ListTile(
                      leading: Icon(
                        Icons.palette_outlined,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      title: Text(tr('settings.theme')),
                      subtitle: Text(_themeModeToString(themeMode, tr)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _showThemeDialog(context, ref, tr),
                    );
                  },
                ),
                const Divider(height: 1, indent: 72),
                Consumer(
                  builder: (context, ref, _) {
                    final currentLang = ref.watch(appLanguageProvider);
                    return ListTile(
                      leading: Icon(
                        Icons.language_outlined,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      title: Text(tr('settings.language')),
                      subtitle: Text(currentLang.displayName),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _showLanguageDialog(context, ref, tr),
                    );
                  },
                ),
                const Divider(height: 1, indent: 72),
                Consumer(
                  builder: (context, ref, _) {
                    final currency = ref.watch(appCurrencyProvider);
                    return ListTile(
                      leading: Icon(
                        Icons.attach_money_outlined,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      title: Text(tr('settings.currency')),
                      subtitle: Text(
                        '${currency.symbol}  ${currency.displayName}',
                        style: const TextStyle(fontSize: 13),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _showCurrencyDialog(context, ref, tr),
                    );
                  },
                ),
                const Divider(height: 1, indent: 72),
                Consumer(
                  builder: (context, ref, _) {
                    final platforms = ref.watch(platformsProvider);
                    final activeNames = platforms.activeNames;
                    final subtitle = activeNames.isEmpty
                        ? tr('platforms.none')
                        : _activeNamesSubtitle(activeNames, activeNames.length);
                    return ListTile(
                      leading: Icon(
                        Icons.apps_outlined,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      title: Text(tr('settings.platforms')),
                      subtitle: Text(subtitle, style: const TextStyle(fontSize: 13)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.go('/settings/platforms'),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Dados
          _SectionHeader(tr('settings.data')),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    Icons.backup_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: Text(tr('settings.backup')),
                  subtitle: Text(tr('settings.backupSub')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // TODO: Navigate to backup page
                  },
                ),
                const Divider(height: 1, indent: 72),
                ListTile(
                  leading: Icon(
                    Icons.delete_outline,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  title: Text(tr('settings.clearData')),
                  subtitle: Text(tr('settings.clearDataSub')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showClearDataDialog(context, tr),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Notificações
          _SectionHeader(tr('settings.notifications')),
          Card(
            child: Column(
              children: [
                Consumer(
                  builder: (context, ref, _) {
                    // TODO: Connect to notification settings provider
                    return SwitchListTile(
                      secondary: Icon(
                        Icons.notifications_outlined,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      title: Text(tr('settings.notificationsActive')),
                      subtitle: Text(tr('settings.notificationsActiveSub')),
                      value: true, // TODO: actual value
                      onChanged: (value) {
                        // TODO: Toggle notifications
                      },
                    );
                  },
                ),
                const Divider(height: 1, indent: 72),
                ListTile(
                  leading: Icon(
                    Icons.schedule_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: Text(tr('settings.dailyReminder')),
                  subtitle: Text(tr('settings.dailyReminderSub')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // TODO: Show time picker for daily reminder
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Sobre
          _SectionHeader(tr('settings.about')),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    Icons.info_outline,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: Text(tr('settings.appVersion')),
                  subtitle: const Text('1.0.0'),
                ),
                const Divider(height: 1, indent: 72),
                ListTile(
                  leading: Icon(
                    Icons.article_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: Text(tr('settings.terms')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // TODO: Show terms
                  },
                ),
                const Divider(height: 1, indent: 72),
                ListTile(
                  leading: Icon(
                    Icons.privacy_tip_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: Text(tr('settings.privacy')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // TODO: Show privacy policy
                  },
                ),
                const Divider(height: 1, indent: 72),
                ListTile(
                  leading: Icon(
                    Icons.bug_report_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: Text(tr('settings.reportIssue')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // TODO: Open issue tracker/email
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _themeModeToString(ThemeMode mode, String Function(String) tr) {
    switch (mode) {
      case ThemeMode.light:
        return tr('settings.themeLight');
      case ThemeMode.dark:
        return tr('settings.themeDark');
      case ThemeMode.system:
        return tr('settings.themeSystem');
    }
  }

  void _showThemeDialog(
      BuildContext context, WidgetRef ref, String Function(String) tr) {
    showDialog(
      context: context,
      builder: (context) {
        final currentMode = ref.read(themeModeProvider);
        return AlertDialog(
          title: Text(tr('settings.chooseTheme')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<ThemeMode>(
                title: Text(tr('settings.themeLight')),
                value: ThemeMode.light,
                groupValue: currentMode,
                onChanged: (value) {
                  if (value != null) {
                    ref.read(themeModeProvider.notifier).state = value;
                    Navigator.pop(context);
                  }
                },
              ),
              RadioListTile<ThemeMode>(
                title: Text(tr('settings.themeDark')),
                value: ThemeMode.dark,
                groupValue: currentMode,
                onChanged: (value) {
                  if (value != null) {
                    ref.read(themeModeProvider.notifier).state = value;
                    Navigator.pop(context);
                  }
                },
              ),
              RadioListTile<ThemeMode>(
                title: Text(tr('settings.themeSystem')),
                value: ThemeMode.system,
                groupValue: currentMode,
                onChanged: (value) {
                  if (value != null) {
                    ref.read(themeModeProvider.notifier).state = value;
                    Navigator.pop(context);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showLanguageDialog(
      BuildContext context, WidgetRef ref, String Function(String) tr) {
    final currentLang = ref.read(appLanguageProvider);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(tr('settings.language')),
          content: DropdownButtonFormField<AppLanguage>(
            value: currentLang,
            // No explicit width: inside a dialog the form field must
            // shrink-wrap, and a full-width Row with an Expanded child
            // inside the dropdown menu overflowed the unbounded
            // horizontal menu constraint ("RenderFlex children have
            // non-zero flex but incoming width constraints are unbounded").
            decoration: InputDecoration(
              labelText: tr('settings.language'),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              isDense: true,
            ),
            items: SUPPORTED_LANGUAGES
                .map((l) => DropdownMenuItem(
                      value: l,
                      child: Text(
                        l.flag != null
                            ? '${l.flag}  ${l.displayName}'
                            : l.displayName,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ))
                .toList(),
            onChanged: (lang) {
              if (lang != null && lang != currentLang) {
                ref.read(languageProvider.notifier).setLanguage(lang);
              }
              Navigator.pop(context);
            },
          ),
        );
      },
    );
  }

  String _activeNamesSubtitle(List<String> activeNames, int total) {
    if (activeNames.isEmpty) return '';
    const shown = 3;
    final names = activeNames.take(shown).join(', ');
    final extra = activeNames.length - shown;
    return extra > 0 ? '$names, +$extra' : names;
  }

  void _showCurrencyDialog(
      BuildContext context, WidgetRef ref, String Function(String) tr) {
    final current = ref.read(appCurrencyProvider);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(tr('settings.chooseCurrency')),
          content: DropdownButtonFormField<AppCurrency>(
            value: current,
            decoration: InputDecoration(
              labelText: tr('settings.currency'),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              isDense: true,
            ),
            items: SUPPORTED_CURRENCIES
                .map((c) => DropdownMenuItem(
                      value: c,
                      child: Text(
                        '${c.symbol}  ${c.displayName}',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ))
                .toList(),
            onChanged: (currency) {
              if (currency != null && currency != current) {
                ref.read(currencyProvider.notifier).setCurrency(currency);
              }
              Navigator.pop(context);
            },
          ),
        );
      },
    );
  }

  void _showClearDataDialog(BuildContext context, String Function(String) tr) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('settings.clearDataConfirm')),
        content: Text(tr('settings.clearDataMsg')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr('dash.cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () {
              // TODO: Clear all data
              Navigator.pop(context);
            },
            child: Text(tr('settings.deleteAll')),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
