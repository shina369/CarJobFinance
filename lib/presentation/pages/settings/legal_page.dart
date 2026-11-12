// Termos de Uso / Política de Privacidade: a titled, scrollable text page.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/language_provider.dart';
import '../../../core/l10n/strings.dart';

class LegalPage extends ConsumerWidget {
  const LegalPage({super.key, required this.titleKey, required this.bodyKey});

  const LegalPage.terms({super.key})
      : titleKey = 'settings.terms',
        bodyKey = 'legal.termsBody';

  const LegalPage.privacy({super.key})
      : titleKey = 'settings.privacy',
        bodyKey = 'legal.privacyBody';

  final String titleKey;
  final String bodyKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(appLanguageProvider);
    return Scaffold(
      appBar: AppBar(title: Text(lang.tr(titleKey))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: SelectableText(
          lang.tr(bodyKey),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5),
        ),
      ),
    );
  }
}
