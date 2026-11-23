import 'package:carjobfinance/data/datasources/local/app_database.dart';
import 'package:carjobfinance/data/datasources/local/backup_data.dart';
import 'package:carjobfinance/core/purchases/purchases_gateway.dart';
import 'package:carjobfinance/presentation/controllers/cloud_backup_controller.dart';
import 'package:carjobfinance/presentation/controllers/data_controller.dart';
import 'package:carjobfinance/presentation/controllers/entitlement_controller.dart';
import 'package:carjobfinance/presentation/controllers/session_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

class _RestoringDataController implements DataController {
  BackupData? restored;

  @override
  Future<void> restore(BackupData data) async {
    restored = data;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('RestoringDataController');
}

void main() {
  late AuthHarness h;
  late CloudBackupController backup;

  Future<CloudBackupController> signedInBackup(
    AuthHarness harness, {
    Duration resolveTimeout = const Duration(seconds: 5),
    DataController? data,
  }) async {
    harness.auth.current = testAccount;
    final container = ProviderContainer(overrides: [
      ...harness.overrides,
      if (data != null) dataControllerProvider.overrideWithValue(data),
      entitlementProvider.overrideWith(
        (ref) => EntitlementController(
          ref.watch(purchasesGatewayProvider),
          ref.watch(sessionProvider.select((s) => s.user?.id)),
          resolveTimeout: resolveTimeout,
        ),
      ),
    ]);
    addTearDown(container.dispose);
    await container.read(sessionProvider.notifier).initialize();
    await Future<void>.delayed(Duration.zero);
    return container.read(cloudBackupControllerProvider);
  }

  setUp(() async {
    h = AuthHarness();
    backup = await signedInBackup(h);
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

  group('without the subscription', () {
    late AuthHarness free;
    late CloudBackupController freeBackup;
    late _RestoringDataController data;

    setUp(() async {
      free = AuthHarness()..premium = false;
      data = _RestoringDataController();
      freeBackup = await signedInBackup(free, data: data);
      free.dao.data = _withData;
    });

    test('backupNow throws PremiumRequiredException and never uploads',
        () async {
      await expectLater(
        freeBackup.backupNow(),
        throwsA(isA<PremiumRequiredException>()),
      );
      expect(free.cloud.uploads, isEmpty);
      expect(
          await free.store.read(CloudBackupController.lastBackupKey), isNull);
    });

    test('autoBackupIfDue returns quietly without uploading', () async {
      expect(await freeBackup.autoBackupIfDue(), isFalse);
      expect(free.cloud.uploads, isEmpty);
      expect(await free.store.read(CloudBackupController.lastHashKey), isNull);
    });

    test('restoreFromCloud, remoteBackupAt and hasLocalData stay free',
        () async {
      free.cloud.remoteAt = DateTime.utc(2026, 1, 2);
      free.cloud.content = _withData.encode();

      expect(await freeBackup.remoteBackupAt(), DateTime.utc(2026, 1, 2));
      expect(await freeBackup.hasLocalData(), isTrue);
      expect(await freeBackup.restoreFromCloud(), isTrue);
      expect(data.restored?.expenses, hasLength(1));
    });
  });

  test('a store that answers after the timeout counts as not premium',
      () async {
    final slow = AuthHarness();
    slow.purchases.delay = const Duration(milliseconds: 300);
    final slowBackup = await signedInBackup(
      slow,
      resolveTimeout: const Duration(milliseconds: 20),
    );
    slow.dao.data = _withData;

    await expectLater(
      slowBackup.backupNow(),
      throwsA(isA<PremiumRequiredException>()),
    );
    expect(await slowBackup.autoBackupIfDue(), isFalse);
    expect(slow.cloud.uploads, isEmpty);
  });
}
