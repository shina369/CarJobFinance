// Whether the signed-in account holds the premium subscription.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/purchases/purchases_gateway.dart';
import 'session_controller.dart';

@immutable
class EntitlementState {
  const EntitlementState({this.info = PremiumInfo.none, this.resolved = false});

  final PremiumInfo info;

  /// False until the store answered (or failed to) for this account.
  final bool resolved;

  bool get isPremium =>
      info.isPremium &&
      (info.expiresAt == null || info.expiresAt!.isAfter(DateTime.now()));

  @override
  bool operator ==(Object other) =>
      other is EntitlementState &&
      other.info == info &&
      other.resolved == resolved;

  @override
  int get hashCode => Object.hash(info, resolved);
}

/// Follows one account: a new controller is built whenever the user changes.
class EntitlementController extends StateNotifier<EntitlementState> {
  /// With [forced] the gateway is never called and the state never changes.
  EntitlementController(
    this._gateway,
    this._userId, {
    this.resolveTimeout = const Duration(seconds: 5),
    bool? forced,
  })  : _forced = forced,
        super(
          forced != null
              ? EntitlementState(
                  info: PremiumInfo(isPremium: forced),
                  resolved: true,
                )
              : EntitlementState(resolved: _userId == null),
        ) {
    final userId = _userId;
    _ready = forced == null && userId != null ? _init(userId) : Future.value();
  }

  /// The store's account switches must not overlap: a log out of the previous
  /// account landing after the next log in would leave the store anonymous.
  static final Expando<Future<void>> _pendingSwitch = Expando();

  final PurchasesGateway _gateway;
  final String? _userId;
  final bool? _forced;
  final Duration resolveTimeout;
  late final Future<void> _ready;
  bool _loggedIn = false;
  StreamSubscription<PremiumInfo>? _subscription;

  Future<void> _afterPendingSwitch(Future<void> Function() call) {
    final previous = _pendingSwitch[_gateway] ?? Future<void>.value();
    final next = previous.then((_) => call());
    _pendingSwitch[_gateway] = next.then((_) {}, onError: (_) {});
    return next;
  }

  Future<void> _init(String userId) async {
    try {
      await _logIn(userId);
      if (!mounted) return;
      _apply(await _gateway.currentInfo());
    } catch (_) {
      if (mounted && !state.resolved) {
        state = const EntitlementState(resolved: true);
      }
    }
  }

  Future<void> _logIn(String userId) async {
    await _afterPendingSwitch(() => _gateway.logIn(userId));
    if (!mounted) return;
    _loggedIn = true;
    _subscription ??= _gateway.updates.listen(_apply, onError: (_) {});
  }

  /// A purchase or restore must never run under another store identity, so a
  /// failed login is retried first and its error rethrown.
  Future<void> _ensureLoggedIn() async {
    await _ready;
    final userId = _userId;
    if (_loggedIn || userId == null) return;
    await _logIn(userId);
    try {
      _apply(await _gateway.currentInfo());
    } catch (_) {
      // The purchase or restore that follows still reports the state.
    }
  }

  void _apply(PremiumInfo info) {
    if (mounted && _forced == null) {
      state = EntitlementState(info: info, resolved: true);
    }
  }

  /// Waits up to [resolveTimeout] for the store; never throws.
  Future<bool> resolveIsPremium() async {
    await _ready.timeout(resolveTimeout, onTimeout: () {});
    return mounted && state.isPremium;
  }

  /// Throws [PurchaseCancelled] when the driver gives up.
  Future<void> purchase(PremiumOffer offer) async {
    if (_forced != null) return;
    await _ensureLoggedIn();
    _apply(await _gateway.purchase(offer));
  }

  Future<void> restore() async {
    if (_forced != null) return;
    await _ensureLoggedIn();
    _apply(await _gateway.restore());
  }

  @override
  void dispose() {
    _subscription?.cancel();
    if (_forced == null && _userId != null) {
      _afterPendingSwitch(_gateway.logOut).ignore();
    }
    super.dispose();
  }
}

/// Debug-only override of the store's answer; main.dart sets it.
final premiumOverrideProvider = Provider<bool?>((_) => null);

final entitlementProvider =
    StateNotifierProvider<EntitlementController, EntitlementState>(
  (ref) => EntitlementController(
    ref.watch(purchasesGatewayProvider),
    ref.watch(sessionProvider.select((s) => s.user?.id)),
    forced: ref.watch(premiumOverrideProvider),
  ),
);

final isPremiumProvider =
    Provider<bool>((ref) => ref.watch(entitlementProvider).isPremium);
