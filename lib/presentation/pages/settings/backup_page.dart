// Backup e Restauração: export every table to JSON or restore from a file.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/language_provider.dart';
import '../../../core/l10n/languages.dart';
import '../../../core/l10n/strings.dart';
import '../../../data/datasources/local/backup_data.dart';
import '../../controllers/data_controller.dart';
import '../../widgets/export_feedback.dart';

class BackupPage extends ConsumerWidget {
  const BackupPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(appLanguageProvider);
    final cs = Theme.of(context).colorScheme;

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
        ],
      ),
    );
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
