// Onboarding / Country Selection Page
// Allows users to select their country during first-time setup
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/languages.dart';
import '../../../core/l10n/language_provider.dart';
import '../../../core/l10n/strings.dart';
import '../../../core/settings/app_settings_notifier.dart';
import '../../../core/settings/country_data.dart';
import '../../widgets/flag_icon.dart';

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  String? _selectedCountryCode;
  bool _navigated = false;

  void _checkAutoSkip() {
    // Schedules the auto-navigate timer at most once, when first observed configured.
    if (_navigated) return;
    final settings = ref.read(appSettingsProvider);
    if (settings.configured) {
      _navigated = true;
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
          context.go('/');
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    _checkAutoSkip();

    // If already configured, show brief message (auto-navigation scheduled above)
    if (settings.configured) {
      final lang = ref.watch(appLanguageProvider);
      return Scaffold(
        body: Center(
          child: Text(
            lang.tr('onboarding.alreadyConfigured'),
            style: const TextStyle(fontSize: 18),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final selectedCode = _selectedCountryCode;
    final selectedCountry = selectedCode != null
        ? COUNTRIES.firstWhere((c) => c.code == selectedCode)
        : null;
    final previewLang = selectedCountry != null
        ? defaultLanguageForCountry(selectedCountry.code)
        : defaultLanguageForCountry('BR');

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // App icon
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.directions_car_rounded,
                      size: 40,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Title
                  Text(
                    previewLang.tr('onboarding.welcome'),
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  // Subtitle
                  Text(
                    previewLang.tr('onboarding.subtitle'),
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 36),
                  // Country dropdown
                  ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 360),
                      child: DropdownButtonFormField<String>(
                        key: const Key('country-dropdown'),
                        decoration: InputDecoration(
                          labelText: previewLang.tr('onboarding.country'),
                          filled: true,
                          fillColor: colorScheme.surfaceContainerHighest,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          isDense: true,
                        ),
                        items: COUNTRIES
                            .map((c) => DropdownMenuItem(
                                  key: Key('country-option-${c.code}'),
                                  value: c.code,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      FlagIcon(c.code),
                                      const SizedBox(width: 10),
                                      Text(
                                        c.namePt,
                                        style: theme.textTheme.bodyLarge,
                                      ),
                                    ],
                                  ),
                                ))
                            .toList(),
                        initialValue: selectedCode,
                        onChanged: (code) =>
                            setState(() => _selectedCountryCode = code),
                      )),
                  // Selected country preview
                  if (selectedCountry != null) ...[
                    const SizedBox(height: 24),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 16),
                      decoration: BoxDecoration(
                        color:
                            colorScheme.primaryContainer.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(14),
                        border:
                            Border.all(color: colorScheme.primary, width: 1.5),
                      ),
                      child: Row(
                        children: [
                          FlagIcon(selectedCountry.code, width: 48),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  selectedCountry.namePt,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.primary,
                                  ),
                                ),
                                Text(
                                  previewLang.tr(
                                    'onboarding.currencyAndPlatforms',
                                    args: {
                                      'currency':
                                          selectedCountry.currencySymbol,
                                      'code': selectedCountry.currencyCode,
                                      'platforms':
                                          selectedCountry.platforms.join(', '),
                                    },
                                  ),
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  // Continue button
                  const SizedBox(height: 32),
                  SizedBox(
                    width: 280,
                    child: FilledButton(
                      key: const Key('continue-button'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: selectedCode != null
                          ? () => _onContinuePressed(selectedCode)
                          : null,
                      child: Text(
                        previewLang.tr('onboarding.continue'),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _onContinuePressed(String countryCode) async {
    // Read before setCountry: it rebuilds the language provider.
    final pickedOnSignIn =
        ref.read(languageProvider.notifier).hasChosenLanguage;
    final current = ref.read(appLanguageProvider);
    final target = defaultLanguageForCountry(countryCode);

    await ref.read(appSettingsProvider.notifier).setCountry(countryCode);

    // The language follows the country, unless the driver picked another one
    // on the sign-in page. A pick of the same language (e.g. Spanish) still
    // moves to the country's variant, which sets number and date formats.
    final sameLanguage =
        current.locale.languageCode == target.locale.languageCode;
    if (!pickedOnSignIn || sameLanguage) {
      await ref.read(languageProvider.notifier).setLanguage(target);
    }

    // Mark the manual navigation so the auto-skip timer (scheduled by the
    // rebuild that follows setCountry's state change) can't double-fire
    _navigated = true;

    if (mounted) {
      context.go('/');
    }
  }
}
