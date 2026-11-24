// Assinatura Premium: the annual offer, its benefits and the legal links.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/language_provider.dart';
import '../../../core/l10n/languages.dart';
import '../../../core/l10n/strings.dart';
import '../../../core/purchases/purchase_failure.dart';
import '../../../core/purchases/purchases_gateway.dart';
import '../../controllers/entitlement_controller.dart';
import '../settings/legal_page.dart';

/// Null when the store has nothing to sell, fails, or does not answer.
final paywallOfferProvider = FutureProvider.autoDispose<PremiumOffer?>(
  (ref) => ref
      .watch(purchasesGatewayProvider)
      .annualOffer()
      .timeout(const Duration(seconds: 15), onTimeout: () => null),
);

const _benefits = [
  (Icons.bar_chart_outlined, 'premium.benefit.reports'),
  (Icons.flag_outlined, 'premium.benefit.goals'),
  (Icons.file_download_outlined, 'premium.benefit.export'),
  (Icons.cloud_upload_outlined, 'premium.benefit.backup'),
  (Icons.notifications_active_outlined, 'premium.benefit.reminders'),
];

/// Pops `true` once the account is premium, `false` when the driver leaves.
class PaywallPage extends ConsumerStatefulWidget {
  const PaywallPage({
    super.key,
    this.purchaseTimeout = const Duration(minutes: 2),
    this.restoreTimeout = const Duration(seconds: 30),
  });

  /// The store's sheet is driven by the driver, so this is generous.
  final Duration purchaseTimeout;
  final Duration restoreTimeout;

  @override
  ConsumerState<PaywallPage> createState() => _PaywallPageState();
}

class _PaywallPageState extends ConsumerState<PaywallPage> {
  bool _busy = false;
  bool _closed = false;
  String? _errorKey;
  bool _pending = false;

  @override
  void initState() {
    super.initState();
    ref.listenManual<bool>(isPremiumProvider, (_, premium) {
      if (premium) _close(true);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ref.read(isPremiumProvider)) _close(true);
    });
  }

  void _close(bool result) {
    if (_closed || !mounted) return;
    _closed = true;
    final own = ModalRoute.of(context);
    if (own != null && !own.isCurrent) {
      Navigator.of(context).popUntil((route) => route == own);
    }
    if (context.canPop()) {
      context.pop(result);
    } else {
      context.go('/');
    }
  }

  /// [operation] returns the key of the message to leave, if any.
  Future<void> _run(Future<String?> Function() operation) async {
    setState(() {
      _busy = true;
      _errorKey = null;
      _pending = false;
    });
    final errorKey = await operation();
    if (!mounted) return;
    if (ref.read(isPremiumProvider)) return _close(true);
    setState(() {
      _busy = false;
      if (errorKey == 'premium.error.pending') {
        _pending = true;
      } else {
        _errorKey = errorKey;
      }
    });
  }

  Future<String?> _restore({required String failureKey}) async {
    try {
      await ref
          .read(entitlementProvider.notifier)
          .restore()
          .timeout(widget.restoreTimeout);
    } catch (_) {
      return failureKey;
    }
    return null;
  }

  Future<void> _buy(PremiumOffer offer) => _run(() async {
        try {
          await ref
              .read(entitlementProvider.notifier)
              .purchase(offer)
              .timeout(widget.purchaseTimeout);
          return null;
        } catch (e) {
          return switch (purchaseFailureOf(e)) {
            PurchaseFailure.cancelled => null,
            PurchaseFailure.pending => 'premium.error.pending',
            PurchaseFailure.alreadyOwned =>
              await _restore(failureKey: 'premium.error.purchase'),
            PurchaseFailure.failed => 'premium.error.purchase',
          };
        }
      });

  Future<void> _restorePurchases() => _run(() async {
        final failure = await _restore(failureKey: 'premium.error.unavailable');
        if (failure != null || ref.read(premiumOverrideProvider) != null) {
          return failure;
        }
        return 'premium.restore.none';
      });

  void _openLegal(Widget page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(appLanguageProvider);
    final offer = ref.watch(paywallOfferProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final loaded = offer.valueOrNull;
    final unavailable = !offer.isLoading && loaded == null;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          key: const Key('paywall-close'),
          icon: const Icon(Icons.close),
          tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
          onPressed: () => _close(false),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  _Header(
                    title: lang.tr('premium.title'),
                    tagline: lang.tr('premium.tagline'),
                  ),
                  const SizedBox(height: 24),
                  Card(
                    child: Column(
                      children: [
                        for (final (index, (icon, key))
                            in _benefits.indexed) ...[
                          if (index > 0) const Divider(height: 1, indent: 72),
                          ListTile(
                            leading: Icon(icon, color: cs.primary),
                            title: Text(lang.tr(key)),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (loaded != null)
                    _Price(offer: loaded, lang: lang)
                  else if (unavailable)
                    Text(
                      lang.tr('premium.error.unavailable'),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: cs.onSurfaceVariant),
                    )
                  else
                    const Center(child: CircularProgressIndicator()),
                  if (_errorKey case final key?) ...[
                    const SizedBox(height: 16),
                    Text(
                      lang.tr(key),
                      key: const Key('paywall-error'),
                      textAlign: TextAlign.center,
                      style:
                          theme.textTheme.bodyMedium?.copyWith(color: cs.error),
                    ),
                  ],
                  if (_pending) ...[
                    const SizedBox(height: 16),
                    Text(
                      lang.tr('premium.error.pending'),
                      key: const Key('paywall-pending'),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: cs.tertiary),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton(
                    key: const Key('paywall-cta'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    onPressed:
                        _busy || loaded == null ? null : () => _buy(loaded),
                    child: _busy
                        ? const SizedBox.square(
                            dimension: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          )
                        : Text(lang.tr('premium.cta')),
                  ),
                  const SizedBox(height: 4),
                  TextButton(
                    key: const Key('paywall-restore'),
                    onPressed: _busy ? null : _restorePurchases,
                    child: Text(lang.tr('premium.restore')),
                  ),
                  Wrap(
                    alignment: WrapAlignment.center,
                    children: [
                      TextButton(
                        key: const Key('paywall-terms'),
                        onPressed: () => _openLegal(const LegalPage.terms()),
                        child: Text(lang.tr('premium.terms')),
                      ),
                      TextButton(
                        key: const Key('paywall-privacy'),
                        onPressed: () => _openLegal(const LegalPage.privacy()),
                        child: Text(lang.tr('premium.privacy')),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.tagline});

  final String title;
  final String tagline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: cs.primaryContainer,
          child: Icon(
            Icons.workspace_premium,
            size: 30,
            color: cs.onPrimaryContainer,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          title,
          style: theme.textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          tagline,
          style:
              theme.textTheme.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _Price extends StatelessWidget {
  const _Price({required this.offer, required this.lang});

  final PremiumOffer offer;
  final AppLanguage lang;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final trialDays = offer.trialDays;
    return Column(
      children: [
        Text(
          lang.tr('premium.price.year', args: {'price': offer.priceText}),
          key: const Key('paywall-price'),
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: cs.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          lang.tr('premium.price.perMonth', args: {'price': offer.monthlyText}),
          textAlign: TextAlign.center,
          style:
              theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
        ),
        if (trialDays != null) ...[
          const SizedBox(height: 12),
          Chip(
            key: const Key('paywall-trial'),
            avatar: Icon(Icons.card_giftcard_outlined, color: cs.primary),
            label: Text(lang.tr('premium.trial', args: {'days': '$trialDays'})),
          ),
        ],
        const SizedBox(height: 12),
        Text(
          lang.tr('premium.disclosure'),
          key: const Key('paywall-disclosure'),
          textAlign: TextAlign.center,
          style:
              theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}
