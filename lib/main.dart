// Ponto de entrada da aplicação CarJobFinance
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

import 'core/auth/supabase_auth_repository.dart';
import 'core/config/env.dart';
import 'core/di/injection.dart';
import 'core/l10n/language_provider.dart';
import 'core/l10n/languages.dart';
import 'core/l10n/strings.dart';
import 'core/router/app_router.dart';
import 'core/settings/app_settings_notifier.dart';
import 'core/theme/app_theme.dart';
import 'presentation/controllers/session_controller.dart';

final getIt = GetIt.instance;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configurar dependências
  await setupDependencies();

  // Prepare intl date formatting for all supported locales (month/weekday names).
  await Strings.initIntlDateFormats();

  final env = await Env.load();

  // One container for start-up and for the app, so what is loaded here
  // (settings, language, saved session) is what the first frame sees.
  final container = ProviderContainer(
    overrides: [envProvider.overrideWithValue(env)],
  );
  await container.read(appSettingsProvider.notifier).initialize();
  await container.read(languageProvider.notifier).initialize();
  await container.read(sessionProvider.notifier).initialize();

  runApp(UncontrolledProviderScope(
    container: container,
    child: const CarJobFinanceApp(),
  ));
}

class CarJobFinanceApp extends ConsumerWidget {
  const CarJobFinanceApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(appLocaleProvider);

    return MaterialApp.router(
      title: 'CarJobFinance',
      debugShowCheckedModeBanner: false,
      locale: locale,
      supportedLocales: SUPPORTED_LANGUAGES.map((l) => l.locale).toList(),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
