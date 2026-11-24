// Settings entry for the premium subscription: upsell or status.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/l10n/language_provider.dart';
import '../../../core/l10n/strings.dart';
import '../../controllers/entitlement_controller.dart';

final Uri playSubscriptionsUri =
    Uri.parse('https://play.google.com/store/account/subscriptions');

/// Opens a URL outside the app; tests replace it so nothing is launched.
final manageSubscriptionLauncherProvider = Provider<Future<bool> Function(Uri)>(
  (_) => (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
);

class PremiumTile extends ConsumerWidget {
  const PremiumTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(appLanguageProvider);
    final entitlement = ref.watch(entitlementProvider);
    final primary = Theme.of(context).colorScheme.primary;
    final icon = Icon(Icons.workspace_premium_outlined, color: primary);

    if (entitlement.isPremium) {
      final expiresAt = entitlement.info.expiresAt;
      final key =
          entitlement.info.willRenew ? 'premium.renews' : 'premium.expires';
      return Card(
        key: const Key('premium-tile'),
        child: Column(
          children: [
            ListTile(
              leading: icon,
              title: Text(lang.tr('premium.active')),
              subtitle: expiresAt == null
                  ? null
                  : Text(lang.tr(key, args: {
                      'date': DateFormat.yMd(lang.tag).format(expiresAt),
                    })),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                key: const Key('premium-manage'),
                onPressed: () => ref.read(manageSubscriptionLauncherProvider)(
                    playSubscriptionsUri),
                child: Text(lang.tr('premium.manage')),
              ),
            ),
          ],
        ),
      );
    }

    if (!entitlement.resolved) return const SizedBox.shrink();

    return Card(
      key: const Key('premium-tile'),
      child: ListTile(
        leading: icon,
        title: Text(lang.tr('premium.settings.tile')),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/paywall'),
      ),
    );
  }
}
