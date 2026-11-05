// Injeção de Dependência com GetIt
import 'package:get_it/get_it.dart';

final getIt = GetIt.instance;

Future<void> setupDependencies() async {
  // Core
  // getIt.registerLazySingleton<AppConfig>(() => AppConfig());

  // Data Sources
  // getIt.registerLazySingleton<LocalDataSource>(() => LocalDataSourceImpl());
  // getIt.registerLazySingleton<RemoteDataSource>(() => RemoteDataSourceImpl());

  // Repositories
  // getIt.registerLazySingleton<RideRepository>(() => RideRepositoryImpl(
  //   localDataSource: getIt(),
  //   remoteDataSource: getIt(),
  // ));
  // getIt.registerLazySingleton<ExpenseRepository>(() => ExpenseRepositoryImpl(
  //   localDataSource: getIt(),
  //   remoteDataSource: getIt(),
  // ));

  // Use Cases
  // getIt.registerFactory(() => GetRidesUseCase(getIt()));
  // getIt.registerFactory(() => CreateRideUseCase(getIt()));
  // getIt.registerFactory(() => UpdateRideUseCase(getIt()));
  // getIt.registerFactory(() => DeleteRideUseCase(getIt()));
  // getIt.registerFactory(() => GetExpensesUseCase(getIt()));
  // getIt.registerFactory(() => CreateExpenseUseCase(getIt()));
  // getIt.registerFactory(() => UpdateExpenseUseCase(getIt()));
  // getIt.registerFactory(() => DeleteExpenseUseCase(getIt()));
  // getIt.registerFactory(() => GetFinancialSummaryUseCase(getIt()));
  // getIt.registerFactory(() => ExportDataUseCase(getIt()));

  // Database
  // getIt.registerLazySingleton<AppDatabase>(() => AppDatabase());
}
