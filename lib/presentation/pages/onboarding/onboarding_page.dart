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
    final selectedCountry = _selectedCountryCode != null
        ? COUNTRIES.firstWhere((c) => c.code == _selectedCountryCode)
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
                                      Text(
                                        flagEmojiFor(c.code),
                                        style: const TextStyle(fontSize: 22),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        c.namePt,
                                        style: theme.textTheme.bodyLarge,
                                      ),
                                    ],
                                  ),
                                ))
                            .toList(),
                        initialValue: _selectedCountryCode,
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
                          Text(
                            flagEmojiFor(selectedCountry.code),
                            style: const TextStyle(fontSize: 32),
                          ),
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
                      onPressed: _selectedCountryCode != null
                          ? _onContinuePressed
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

  Future<void> _onContinuePressed() async {
    if (_selectedCountryCode == null) return;

    // Call setCountry on the notifier
    await ref
        .read(appSettingsProvider.notifier)
        .setCountry(_selectedCountryCode!);

    // Set the language to the country default (first-time)
    final lang = defaultLanguageForCountry(_selectedCountryCode!);
    await ref.read(languageProvider.notifier).setLanguage(lang);

    // Mark the manual navigation so the auto-skip timer (scheduled by the
    // rebuild that follows setCountry's state change) can't double-fire
    _navigated = true;

    // Navigate to home after successful country selection
    if (mounted) {
      context.go('/');
    }
  }
}

/// Flag emoji for a country code, with a fallback.
String flagEmojiFor(String countryCode) {
  switch (countryCode) {
    case 'BR':
      return '🇧🇷';
    case 'PT':
      return '🇵🇹';
    case 'MX':
      return '🇲🇽';
    case 'CO':
      return '🇨🇴';
    case 'CL':
      return '🇨🇱';
    case 'AR':
      return '🇦🇷';
    case 'ES':
      return '🇪🇸';
    case 'US':
      return '🇺🇸';
    case 'ID':
      return '🇮🇩';
    case 'IN':
      return '🇮🇳';
    default:
      return '🏳️';
  }
}
