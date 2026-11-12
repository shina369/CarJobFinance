// Backup e Restauração: export every table to JSON or restore from a file.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/l10n/language_provider.dart';
import '../../../core/l10n/languages.dart';
import '../../../core/l10n/strings.dart';
import '../../../data/datasources/local/backup_data.dart';
import '../../controllers/cloud_backup_controller.dart';
import '../../controllers/data_controller.dart';
import '../../widgets/export_feedback.dart';
import '../auth/auth_widgets.dart';

class BackupPage extends ConsumerWidget {
  const BackupPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(appLanguageProvider);
    final cs = Theme.of(context).colorScheme;
    final lastCloud = ref.watch(lastCloudBackupProvider).valueOrNull;
    final lastCloudText = lastCloud == null
        ? lang.tr('cloud.never')
        : lang.tr('cloud.last', args: {
            'date':
                DateFormat.yMd(lang.tag).add_Hm().format(lastCloud.toLocal()),
          });

    return Scaffold(
      appBar: AppBar(title: Text(lang.tr('settings.backup'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.upload_file_outlined, color: cs.primary),
                  title: Text(lang.tr('backup.exportTitle')),
                  subtitle: Text(lang.tr('backup.exportSub')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => runExport(
                    context,
                    lang,
                    ref.read(dataControllerProvider).exportBackup,
                  ),
                ),
                const Divider(height: 1, indent: 72),
                ListTile(
                  leading: Icon(Icons.restore_outlined, color: cs.tertiary),
                  title: Text(lang.tr('backup.restoreTitle')),
                  subtitle: Text(lang.tr('backup.restoreSub')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _restore(context, ref, lang),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.only(bottom: 8, left: 4),
            child: Text(
              lang.tr('cloud.section'),
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          Card(
            child: Column(
              children: [
                ListTile(
                  key: const Key('cloud-status'),
                  leading: Icon(Icons.cloud_done_outlined, color: cs.primary),
                  title: Text(lastCloudText),
                  subtitle: Text(lang.tr('cloud.autoInfo')),
                ),
                const Divider(height: 1, indent: 72),
                ListTile(
                  key: const Key('cloud-backup-now'),
                  leading: Icon(Icons.cloud_upload_outlined, color: cs.primary),
                  title: Text(lang.tr('cloud.backupNow')),
                  subtitle: Text(lang.tr('cloud.backupNowSub')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _cloudBackup(context, ref, lang),
                ),
                const Divider(height: 1, indent: 72),
                ListTile(
                  key: const Key('cloud-restore'),
                  leading:
                      Icon(Icons.cloud_download_outlined, color: cs.tertiary),
                  title: Text(lang.tr('cloud.restore')),
                  subtitle: Text(lang.tr('cloud.restoreSub')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _cloudRestore(context, ref, lang),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _cloudBackup(
      BuildContext context, WidgetRef ref, AppLanguage lang) async {
    final messenger = ScaffoldMessenger.of(context);
    void notify(String text) =>
        messenger.showSnackBar(SnackBar(content: Text(text)));
    try {
      await ref.read(cloudBackupControllerProvider).backupNow();
      ref.invalidate(lastCloudBackupProvider);
      notify(lang.tr('cloud.done'));
    } catch (e) {
      notify(authErrorMessage(lang, e));
    }
  }

  Future<void> _cloudRestore(
      BuildContext context, WidgetRef ref, AppLanguage lang) async {
    final messenger = ScaffoldMessenger.of(context);
    final cloud = ref.read(cloudBackupControllerProvider);
    void notify(String text) =>
        messenger.showSnackBar(SnackBar(content: Text(text)));

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(lang.tr('cloud.restore')),
        content: Text(lang.tr('cloud.restoreSub')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(lang.tr('dash.cancel')),
          ),
          FilledButton(
            key: const Key('cloud-restore-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(lang.tr('backup.restore')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final restored = await cloud.restoreFromCloud();
      ref.invalidate(lastCloudBackupProvider);
      notify(lang.tr(restored ? 'backup.restored' : 'cloud.none'));
    } on BackupFormatException {
      notify(lang.tr('backup.invalid'));
    } catch (e) {
      notify(authErrorMessage(lang, e));
    }
  }

  Future<void> _restore(
      BuildContext context, WidgetRef ref, AppLanguage lang) async {
    final messenger = ScaffoldMessenger.of(context);
    final controller = ref.read(dataControllerProvider);
    void notify(String key, {Map<String, String>? args}) => messenger
        .showSnackBar(SnackBar(content: Text(lang.tr(key, args: args))));

    final BackupData? data;
    try {
      data = await controller.pickBackup();
    } on BackupFormatException {
      notify('backup.invalid');
      return;
    } catch (e) {
      notify('export.failed', args: {'error': '$e'});
      return;
    }
    if (data == null || !context.mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(lang.tr('backup.restoreConfirm')),
        content: Text(lang.tr('backup.restoreMsg', args: {
          'rides': '${data!.rides.length}',
          'expenses': '${data.expenses.length}',
        })),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(lang.tr('dash.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(lang.tr('backup.restore')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await controller.restore(data);
      notify('backup.restored');
    } catch (e) {
      notify('export.failed', args: {'error': '$e'});
    }
  }
}
