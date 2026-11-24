// Lets a premium action through, or shows the paywall first.
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../controllers/entitlement_controller.dart';

/// True when the driver is premium, possibly after buying on the paywall.
///
/// Waits (bounded) for the store first, so a premium driver whose
/// entitlement is still loading never sees the paywall.
Future<bool> ensurePremium(BuildContext context, WidgetRef ref) async {
  if (await ref.read(entitlementProvider.notifier).resolveIsPremium()) {
    return true;
  }
  if (!context.mounted) return false;
  return await context.push<bool>('/paywall') == true;
}
