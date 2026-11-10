// Onboarding / Country Selection Page
// Allows users to select their country during first-time setup
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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

  @override
  void initState() {
    super.initState();
  }

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

    // Auto-navigate check runs on first build (or first rebuild after the
    // auto-skip message is shown), not in initState — Riverpod's ref is
    // not available there.
    _checkAutoSkip();

    // If already configured, show brief message (auto-navigation scheduled above)
    if (settings.configured) {
      return const Scaffold(
        body: Center(
          child: Text(
            'Você já está configurado',
            style: TextStyle(fontSize: 18),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bem-vindo ao CarJobFinance'),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Selecione seu país para configurar moeda, idioma e plataformas disponíveis.',
                style: TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
            // Country list
            Expanded(
              child: ListView.builder(
                key: const Key('country-list'),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: COUNTRIES.length,
                itemBuilder: (context, index) {
                  final country = COUNTRIES[index];
                  final isSelected = _selectedCountryCode == country.code;
                  return _CountryCard(
                    key: Key('country-card-${country.code}'),
                    country: country,
                    isSelected: isSelected,
                    onTap: () => setState(() => _selectedCountryCode = country.code),
                  );
                },
              ),
            ),
            // Continue button
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const Key('continue-button'),
                  onPressed: _selectedCountryCode != null ? _onContinuePressed : null,
                  child: const Text('Continuar'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onContinuePressed() async {
    if (_selectedCountryCode == null) return;

    // Call setCountry on the notifier
    await ref.read(appSettingsProvider.notifier).setCountry(_selectedCountryCode!);

    // Mark the manual navigation so the auto-skip timer (scheduled by the
    // rebuild that follows setCountry's state change) can't double-fire
    _navigated = true;

    // Navigate to home after successful country selection
    if (mounted) {
      context.go('/');
    }
  }
}

/// Internal country card widget
class _CountryCard extends StatelessWidget {
  const _CountryCard({
    super.key,
    required this.country,
    required this.isSelected,
    required this.onTap,
  });

  final CountryEntry country;
  final bool isSelected;
  final VoidCallback onTap;

  // Flag emoji mapping for each country code
  static const Map<String, String> _flagEmojis = {
    'BR': '🇧🇷',
    'PT': '🇵🇹',
    'MX': '🇲🇽',
    'CO': '🇨🇴',
    'CL': '🇨🇱',
    'AR': '🇦🇷',
    'ES': '🇪🇸',
    'US': '🇺🇸',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final flag = _flagEmojis[country.code] ?? '🏳️';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? colorScheme.primary : colorScheme.outlineVariant,
          width: isSelected ? 3 : 1,
        ),
        color: isSelected ? colorScheme.primaryContainer.withValues(alpha: 0.3) : colorScheme.surface,
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: colorScheme.primary.withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              // Flag emoji
              Text(
                flag,
                style: const TextStyle(fontSize: 48),
              ),
              const SizedBox(width: 16),
              // Country info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      country.namePt,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isSelected ? colorScheme.primary : colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${country.currencySymbol} (${country.currencyCode})',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              // Selection indicator
              if (isSelected)
                Icon(
                  Icons.check_circle_rounded,
                  color: colorScheme.primary,
                  size: 28,
                ),
            ],
          ),
        ),
      ),
    );
  }
}