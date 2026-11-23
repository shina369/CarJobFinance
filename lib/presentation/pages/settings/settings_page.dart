// ignore_for_file: deprecated_member_use
// Settings Page - Configurações
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/l10n/currency_provider.dart';
import '../../../core/l10n/language_provider.dart';
import '../../../core/l10n/platforms_provider.dart';
import '../../../core/l10n/strings.dart';
import '../../../core/notifications/notification_settings.dart';
import '../../../core/settings/app_settings_notifier.dart';
import '../../../core/settings/country_data.dart';
import '../../../core/theme/app_theme.dart';
import '../../controllers/session_controller.dart';
import '../../widgets/export_actions.dart';
import 'clear_data_dialog.dart';
import 'delete_account_dialog.dart';
import 'profile_edit_dialog.dart';

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
                      onTap: () => context.push('/settings/language'),
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
                      onTap: () => context.push('/settings/currency'),
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
                      subtitle:
                          Text(subtitle, style: const TextStyle(fontSize: 13)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.go('/settings/platforms'),
                    );
                  },
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
                    final prefs = ref.watch(notificationSettingsProvider);
                    return SwitchListTile(
                      secondary: Icon(
                        Icons.notifications_outlined,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      title: Text(tr('settings.notificationsActive')),
                      subtitle: Text(tr('settings.notificationsActiveSub')),
                      value: prefs.enabled,
                      onChanged: (value) =>
                          _setNotificationsEnabled(context, ref, tr, value),
                    );
                  },
                ),
                const Divider(height: 1, indent: 72),
                Consumer(
                  builder: (context, ref, _) {
                    final active = ref.watch(notificationSettingsProvider
                        .select((p) => p.enabled ? p.activeCount : 0));
                    return ListTile(
                      key: const Key('settings-reminders'),
                      leading: Icon(
                        Icons.alarm_outlined,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      title: Text(tr('settings.reminders')),
                      subtitle: Text(active == 0
                          ? tr('reminders.none')
                          : lang.tr('reminders.active',
                              args: {'count': '$active'})),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/settings/reminders'),
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
                  onTap: () => context.push('/settings/backup'),
                ),
                const Divider(height: 1, indent: 72),
                const ExportTiles(),
                const Divider(height: 1, indent: 72),
                ListTile(
                  leading: Icon(
                    Icons.delete_outline,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  title: Text(tr('settings.clearData')),
                  subtitle: Text(tr('settings.clearDataSub')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showClearDataDialog(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Conta
          _SectionHeader(tr('settings.account')),
          Card(
            child: Column(
              children: [
                const _ProfileSection(),
                const Divider(height: 1, indent: 72),
                ListTile(
                  key: const Key('settings-sign-out'),
                  leading: Icon(
                    Icons.logout,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  title: Text(tr('settings.signOut')),
                  onTap: () => _showSignOutDialog(context, ref, tr),
                ),
                const Divider(height: 1, indent: 72),
                ListTile(
                  key: const Key('settings-delete-account'),
                  leading: Icon(
                    Icons.delete_forever_outlined,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  title: Text(
                    tr('settings.deleteAccount'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  onTap: () => _showDeleteAccountDialog(context),
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
                  subtitle: const Text(AppConstants.appVersion),
                ),
                const Divider(height: 1, indent: 72),
                ListTile(
                  leading: Icon(
                    Icons.article_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: Text(tr('settings.terms')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/settings/terms'),
                ),
                const Divider(height: 1, indent: 72),
                ListTile(
                  leading: Icon(
                    Icons.privacy_tip_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: Text(tr('settings.privacy')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/settings/privacy'),
                ),
                const Divider(height: 1, indent: 72),
                ListTile(
                  leading: Icon(
                    Icons.bug_report_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: Text(tr('settings.reportIssue')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showReportIssueDialog(context, tr),
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

  String _activeNamesSubtitle(List<String> activeNames, int total) {
    if (activeNames.isEmpty) return '';
    const shown = 3;
    final names = activeNames.take(shown).join(', ');
    final extra = activeNames.length - shown;
    return extra > 0 ? '$names, +$extra' : names;
  }

  Future<void> _setNotificationsEnabled(BuildContext context, WidgetRef ref,
      String Function(String) tr, bool enabled) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await ref
        .read(notificationSettingsProvider.notifier)
        .setEnabled(enabled, reminderTextFor(tr));
    if (!ok) {
      messenger.showSnackBar(
          SnackBar(content: Text(tr('settings.notificationsUnavailable'))));
    }
  }

  void _showReportIssueDialog(
      BuildContext context, String Function(String) tr) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('settings.reportIssue')),
        content: Text(tr('settings.reportIssueMsg')),
        actions: [
          TextButton(
            key: const Key('settings-report-issue-close'),
            onPressed: () => Navigator.pop(context),
            child: Text(tr('dash.close')),
          ),
        ],
      ),
    );
  }

  Future<void> _showSignOutDialog(
      BuildContext context, WidgetRef ref, String Function(String) tr) async {
    final session = ref.read(sessionProvider.notifier);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('settings.signOutConfirm')),
        content: Text(tr('settings.signOutMsg')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr('dash.cancel')),
          ),
          FilledButton(
            key: const Key('settings-sign-out-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(tr('settings.signOut')),
          ),
        ],
      ),
    );
    if (confirmed == true) await session.signOut();
  }

  void _showDeleteAccountDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const DeleteAccountDialog(),
    );
  }

  void _showClearDataDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const ClearDataDialog(),
    );
  }
}

class _ProfileSection extends ConsumerWidget {
  const _ProfileSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(appLanguageProvider);
    final user = ref.watch(sessionProvider.select((s) => s.user));
    final countryCode =
        ref.watch(appSettingsProvider.select((s) => s.countryCode));
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final countries = COUNTRIES.where((c) => c.code == countryCode);
    final countryName =
        countries.isEmpty ? countryCode : countries.first.namePt;

    ListTile row(IconData icon, String title, String value) => ListTile(
          leading: Icon(icon, color: primary),
          title: Text(title),
          subtitle: Text(value),
        );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, right: 8, top: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  lang.tr('settings.profile'),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton.icon(
                key: const Key('settings-profile-edit'),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: Text(lang.tr('settings.profileEdit')),
                onPressed: user == null
                    ? null
                    : () => showDialog<void>(
                          context: context,
                          barrierDismissible: false,
                          builder: (_) => const ProfileEditDialog(),
                        ),
              ),
            ],
          ),
        ),
        row(Icons.person_outline, lang.tr('auth.firstName'),
            user?.firstName ?? '—'),
        const Divider(height: 1, indent: 72),
        row(Icons.person_outline, lang.tr('auth.lastName'),
            user?.lastName ?? '—'),
        const Divider(height: 1, indent: 72),
        row(Icons.account_circle_outlined, lang.tr('auth.email'),
            user?.email ?? ''),
        const Divider(height: 1, indent: 72),
        row(Icons.flag_outlined, lang.tr('onboarding.country'), countryName),
      ],
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
