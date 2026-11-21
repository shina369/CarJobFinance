import 'package:carjobfinance/data/datasources/local/app_database.dart';
import 'package:carjobfinance/data/datasources/local/daos.dart';
import 'package:carjobfinance/data/repositories/repositories_impl.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late AppDao dao;
  late SettingsRepositoryImpl repository;

  setUp(() {
    db = AppDatabase.memory();
    dao = AppDao(db);
    repository = SettingsRepositoryImpl(dao);
  });
  tearDown(() async => db.close());

  group('SettingsRepositoryImpl monthly goals', () {
    test('months without a goal are null when there is no legacy goal',
        () async {
      final goals = await repository.getGoalsForYear(2026);

      expect(goals.keys, List.generate(12, (i) => i + 1));
      expect(goals.values, everyElement(isNull));
    });

    test('legacy monthly_goal is the fallback for every month', () async {
      await dao.setSetting('monthly_goal', '4000');

      final goals = await repository.getGoalsForYear(2026);

      expect(goals.values, everyElement(4000.0));
    });

    test('a saved month overrides the legacy goal and leaves others alone',
        () async {
      await dao.setSetting('monthly_goal', '4000');

      await repository.setGoalsForYear(2026, {3: 6500.5});
      final goals = await repository.getGoalsForYear(2026);

      expect(goals[3], 6500.5);
      expect(goals[4], 4000.0);
    });

    test('null clears a saved month', () async {
      await repository.setGoalsForYear(2026, {3: 6500});

      await repository.setGoalsForYear(2026, {3: null});

      expect((await repository.getGoalsForYear(2026))[3], isNull);
    });

    test('goals are stored per year', () async {
      await repository.setGoalsForYear(2026, {5: 1000});

      expect((await repository.getGoalsForYear(2027))[5], isNull);
    });

    test('getMonthlyGoal and setMonthlyGoal work on the current month',
        () async {
      final now = DateTime.now();
      expect(await repository.getMonthlyGoal(), 5000.0);

      await repository.setMonthlyGoal(7000);

      expect(await repository.getMonthlyGoal(), 7000.0);
      expect((await repository.getGoalsForYear(now.year))[now.month], 7000.0);
    });
  });
}
