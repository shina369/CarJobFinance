import 'package:carjobfinance/data/datasources/local/app_database.dart';
import 'package:carjobfinance/data/datasources/local/backup_data.dart';
import 'package:carjobfinance/presentation/controllers/cloud_backup_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/auth_test_support.dart';

final _expense = Expense(
  id: 'e1',
  date: DateTime(2026, 1, 1),
  category: 'Combustivel',
  amount: 50,
  isRecurring: false,
  isSynced: false,
  createdAt: DateTime(2026, 1, 1),
);

final _withData = BackupData(
  rides: const [],
  expenses: [_expense],
  settings: const {},
  countryPlatforms: const [],
);

void main() {
  late AuthHarness h;
  late CloudBackupController backup;

  setUp(() {
    h = AuthHarness();
    final container = h.container();
    addTearDown(container.dispose);
    backup = container.read(cloudBackupControllerProvider);
  });

  group('fingerprint', () {
    test('is the same for the same content', () {
      expect(
        CloudBackupController.fingerprint(_withData),
        CloudBackupController.fingerprint(_withData),
      );
    });

    test('changes when the content changes', () {
      final changed = BackupData(
        rides: const [],
        expenses: [_expense.copyWith(amount: 99)],
        settings: const {},
        countryPlatforms: const [],
      );
      expect(
        CloudBackupController.fingerprint(changed),
        isNot(CloudBackupController.fingerprint(_withData)),
      );
    });
  });

  group('autoBackupIfDue', () {
    test('does nothing on an empty device', () async {
      expect(await backup.autoBackupIfDue(), isFalse);
      expect(h.cloud.uploads, isEmpty);
    });

    test('uploads when there is data and no earlier backup', () async {
      h.dao.data = _withData;

      expect(await backup.autoBackupIfDue(), isTrue);
      expect(h.cloud.uploads, hasLength(1));
      expect(await backup.lastBackupAt(), isNotNull);
    });

    test('waits for the 24 hour interval', () async {
      h.dao.data = _withData;
      final now = DateTime.now();
      await backup.autoBackupIfDue(now: now);

      h.dao.data = BackupData(
        rides: const [],
        expenses: [_expense.copyWith(amount: 99)],
        settings: const {},
        countryPlatforms: const [],
      );
      expect(
        await backup.autoBackupIfDue(now: now.add(const Duration(hours: 23))),
        isFalse,
      );
      expect(h.cloud.uploads, hasLength(1));
    });

    test('skips an unchanged backup even when the interval has passed',
        () async {
      h.dao.data = _withData;
      final now = DateTime.now();
      await backup.autoBackupIfDue(now: now);

      expect(
        await backup.autoBackupIfDue(now: now.add(const Duration(hours: 25))),
        isFalse,
      );
      expect(h.cloud.uploads, hasLength(1));
    });

    test('uploads again once the data changed after the interval', () async {
      h.dao.data = _withData;
      final now = DateTime.now();
      await backup.autoBackupIfDue(now: now);

      h.dao.data = BackupData(
        rides: const [],
        expenses: [_expense.copyWith(amount: 99)],
        settings: const {},
        countryPlatforms: const [],
      );
      expect(
        await backup.autoBackupIfDue(now: now.add(const Duration(hours: 25))),
        isTrue,
      );
      expect(h.cloud.uploads, hasLength(2));
    });

    test('a failed upload is swallowed and retried later', () async {
      h.dao.data = _withData;
      h.cloud.error = Exception('offline');

      expect(await backup.autoBackupIfDue(), isFalse);
      expect(await h.store.read(CloudBackupController.lastHashKey), isNull);
    });
  });

  group('restoreFromCloud', () {
    test('reports false when the account has no backup', () async {
      expect(await backup.restoreFromCloud(), isFalse);
    });
  });

  test('backupNow uploads the device data and records the time', () async {
    h.dao.data = _withData;
    await backup.backupNow();

    expect(h.cloud.uploads, hasLength(1));
    expect(await h.store.read(CloudBackupController.lastBackupKey), isNotNull);
  });
}
