import 'dart:convert';

import 'package:carjobfinance/data/datasources/local/app_database.dart';
import 'package:carjobfinance/data/datasources/local/backup_data.dart';
import 'package:carjobfinance/data/datasources/local/daos.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late AppDao dao;

  setUp(() {
    db = AppDatabase.memory();
    dao = AppDao(db);
  });
  tearDown(() async => db.close());

  Future<void> seed() async {
    await dao.insertRide(RidesCompanion.insert(
      id: 'ride-1',
      date: DateTime(2026, 3, 5, 14, 30),
      platform: 'Uber',
      earnings: 42.5,
      distanceKm: 12.3,
      durationMinutes: 25,
      rideType: 'Normal',
      createdAt: DateTime(2026, 3, 5, 15),
    ));
    await dao.insertExpense(ExpensesCompanion.insert(
      id: 'expense-1',
      date: DateTime(2026, 3, 6),
      category: 'Combustível',
      amount: 150,
      createdAt: DateTime(2026, 3, 6),
    ));
    await dao.setSetting('app_country', 'BR');
    await dao.setSetting('monthly_goal', '5000');
    await dao.createCustom('BR', 'Minha Plataforma');
  }

  group('BackupData codec', () {
    test('encode then decode keeps every table', () async {
      await seed();
      final original = await dao.readBackupData();

      final json = original.encode(exportedAt: DateTime(2026, 3, 7));
      final decoded = BackupData.decode(json);

      expect(jsonDecode(json)['format'], kBackupFormat);
      expect(jsonDecode(json)['version'], kBackupVersion);
      expect(decoded.rides, original.rides);
      expect(decoded.expenses, original.expenses);
      expect(decoded.settings, original.settings);
      expect(decoded.countryPlatforms, original.countryPlatforms);
      expect(decoded.rides.single.earnings, 42.5);
      expect(decoded.settings['monthly_goal'], '5000');
    });

    test('rejects text that is not JSON', () {
      expect(() => BackupData.decode('not json'),
          throwsA(isA<BackupFormatException>()));
    });

    test('rejects JSON from another source', () {
      expect(() => BackupData.decode('{"rides": []}'),
          throwsA(isA<BackupFormatException>()));
      expect(() => BackupData.decode('[1, 2]'),
          throwsA(isA<BackupFormatException>()));
    });

    test('rejects a backup from a newer version', () {
      final json =
          jsonEncode({'format': kBackupFormat, 'version': kBackupVersion + 1});
      expect(
          () => BackupData.decode(json), throwsA(isA<BackupFormatException>()));
    });

    test('rejects rows with the wrong shape', () {
      final json = jsonEncode({
        'format': kBackupFormat,
        'version': kBackupVersion,
        'rides': [
          {'id': 'x'}
        ],
      });
      expect(
          () => BackupData.decode(json), throwsA(isA<BackupFormatException>()));
    });
  });

  group('AppDao backup operations', () {
    test('clearAllData empties every table', () async {
      await seed();

      await dao.clearAllData();

      final data = await dao.readBackupData();
      expect(data.rides, isEmpty);
      expect(data.expenses, isEmpty);
      expect(data.settings, isEmpty);
      expect(data.countryPlatforms, isEmpty);
    });

    test('restoreBackupData replaces current content with the backup',
        () async {
      await seed();
      final backup = BackupData.decode((await dao.readBackupData()).encode());

      await dao.deleteRide('ride-1');
      await dao.insertExpense(ExpensesCompanion.insert(
        id: 'expense-2',
        date: DateTime(2026, 4, 1),
        category: 'Pedágio',
        amount: 9.9,
        createdAt: DateTime(2026, 4, 1),
      ));
      await dao.setSetting('monthly_goal', '1');

      await dao.restoreBackupData(backup);

      final restored = await dao.readBackupData();
      expect(restored.rides, backup.rides);
      expect(restored.expenses, backup.expenses);
      expect(restored.settings, backup.settings);
      expect(restored.countryPlatforms, backup.countryPlatforms);
    });

    test('a failing restore leaves the previous data untouched', () async {
      await seed();
      final current = await dao.readBackupData();
      final ride = current.rides.single;
      final broken = BackupData(
        rides: [ride, ride],
        expenses: const [],
        settings: const {},
        countryPlatforms: const [],
      );

      await expectLater(dao.restoreBackupData(broken), throwsA(anything));

      final after = await dao.readBackupData();
      expect(after.rides, current.rides);
      expect(after.expenses, current.expenses);
      expect(after.settings, current.settings);
    });
  });
}
