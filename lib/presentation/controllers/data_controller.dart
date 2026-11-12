// Whole-database operations: full backup, restore and "clear all data".
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/export/file_exporter.dart';
import '../../core/l10n/currency_provider.dart';
import '../../core/l10n/language_provider.dart';
import '../../core/l10n/platforms_provider.dart';
import '../../core/notifications/notification_settings.dart';
import '../../core/settings/app_settings_notifier.dart';
import '../../data/datasources/local/backup_data.dart';
import 'controllers.dart';

String exportFileName(String prefix, String extension, [DateTime? now]) {
  final d = now ?? DateTime.now();
  String two(int v) => v.toString().padLeft(2, '0');
  return 'carjobfinance_${prefix}_${d.year}${two(d.month)}${two(d.day)}'
      '_${two(d.hour)}${two(d.minute)}.$extension';
}

class DataController {
  DataController(this._ref);

  final Ref _ref;

  /// Exports every table as a JSON file. Returns false if the user
  /// cancelled the save/share dialog.
  Future<bool> exportBackup() async {
    final data = await _ref.read(appDaoProvider).readBackupData();
    return _ref.read(fileExporterProvider).export(
          fileName: exportFileName('backup', 'json'),
          bytes: Uint8List.fromList(utf8.encode(data.encode())),
          mimeType: 'application/json',
        );
  }

  /// Lets the user pick a backup file and parses it. Returns null if the
  /// user cancelled; throws [BackupFormatException] for invalid files.
  Future<BackupData?> pickBackup() async {
    final content =
        await _ref.read(backupFilePickerProvider).pickBackupContent();
    return content == null ? null : BackupData.decode(content);
  }

  Future<void> restore(BackupData data) async {
    await _ref.read(appDaoProvider).restoreBackupData(data);
    await _reloadPreferences();
  }

  Future<void> clearAll() async {
    await _ref.read(notificationSettingsProvider.notifier).cancelAll();
    await _ref.read(appDaoProvider).clearAllData();
    await _reloadPreferences();
  }

  /// Settings-backed providers cache what they read at start-up, so they
  /// must be rebuilt after the settings table is replaced or wiped.
  Future<void> _reloadPreferences() async {
    await _ref.read(appSettingsProvider.notifier).initialize();
    _ref.invalidate(languageProvider);
    _ref.invalidate(currencyProvider);
    _ref.invalidate(platformsProvider);
    _ref.invalidate(monthlyGoalControllerProvider);
    _ref.invalidate(notificationSettingsProvider);
  }
}

final dataControllerProvider =
    Provider<DataController>((ref) => DataController(ref));
