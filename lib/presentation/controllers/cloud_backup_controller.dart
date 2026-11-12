// Cloud backup: upload, automatic daily upload and restore.
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/backup/cloud_backup_repository.dart';
import '../../core/storage/device_store.dart';
import '../../data/datasources/local/backup_data.dart';
import 'controllers.dart';
import 'data_controller.dart';

class CloudBackupController {
  CloudBackupController(this._ref);

  static const String lastBackupKey = 'cloud_backup_at';
  static const String lastHashKey = 'cloud_backup_hash';
  static const Duration autoBackupInterval = Duration(hours: 24);

  final Ref _ref;

  DeviceStore get _store => _ref.read(deviceStoreProvider);
  CloudBackupRepository get _cloud => _ref.read(cloudBackupRepositoryProvider);

  /// Fingerprint of the content, independent of when it was exported.
  static String fingerprint(BackupData data) {
    final stable = data.encode(exportedAt: DateTime.utc(2000));
    return sha256.convert(utf8.encode(stable)).toString();
  }

  static bool hasUserData(BackupData data) =>
      data.rides.isNotEmpty || data.expenses.isNotEmpty;

  Future<bool> hasLocalData() async =>
      hasUserData(await _ref.read(appDaoProvider).readBackupData());

  /// When this device last uploaded a backup.
  Future<DateTime?> lastBackupAt() async {
    final saved = await _store.read(lastBackupKey);
    return saved == null ? null : DateTime.tryParse(saved);
  }

  /// When the account's cloud backup was written, from any device.
  Future<DateTime?> remoteBackupAt() => _cloud.lastBackupAt();

  Future<DateTime> backupNow() async {
    final data = await _ref.read(appDaoProvider).readBackupData();
    return _upload(data);
  }

  Future<DateTime> _upload(BackupData data) async {
    final uploadedAt = await _cloud.upload(data.encode());
    await _remember(uploadedAt, fingerprint(data));
    return uploadedAt;
  }

  Future<void> _remember(DateTime at, String hash) async {
    await _store.write(lastBackupKey, at.toIso8601String());
    await _store.write(lastHashKey, hash);
  }

  /// Uploads when the last backup is older than [autoBackupInterval] and the
  /// data changed since. Never throws: a failure (e.g. offline) is retried
  /// the next time the app opens.
  Future<bool> autoBackupIfDue({DateTime? now}) async {
    try {
      final last = await lastBackupAt();
      final current = now ?? DateTime.now();
      if (last != null && current.difference(last) < autoBackupInterval) {
        return false;
      }
      final data = await _ref.read(appDaoProvider).readBackupData();
      // An empty device must not replace a backup that holds real data.
      if (!hasUserData(data)) return false;
      if (fingerprint(data) == await _store.read(lastHashKey)) return false;
      await _upload(data);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Replaces the local data with the cloud backup. Returns false when the
  /// account has no backup; throws [BackupFormatException] if it is invalid.
  Future<bool> restoreFromCloud() async {
    final content = await _cloud.download();
    if (content == null) return false;
    final data = BackupData.decode(content);
    await _ref.read(dataControllerProvider).restore(data);
    final restored = await _ref.read(appDaoProvider).readBackupData();
    await _remember(DateTime.now().toUtc(), fingerprint(restored));
    return true;
  }
}

final cloudBackupControllerProvider =
    Provider<CloudBackupController>((ref) => CloudBackupController(ref));

final lastCloudBackupProvider = FutureProvider<DateTime?>(
  (ref) => ref.watch(cloudBackupControllerProvider).lastBackupAt(),
);
