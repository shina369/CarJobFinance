import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_repository.dart';
import '../../../core/l10n/language_provider.dart';
import '../../../core/l10n/strings.dart';
import '../../controllers/session_controller.dart';
import '../auth/auth_widgets.dart';

/// Asks for the account password and, once the server accepts it, erases the
/// account. The work runs inside the dialog: a successful deletion signs the
/// user out and the router replaces the page stack, which deactivates this
/// dialog's route, so it only pops itself while its route is still active.
class DeleteAccountDialog extends ConsumerStatefulWidget {
  const DeleteAccountDialog({super.key});

  @override
  ConsumerState<DeleteAccountDialog> createState() =>
      _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends ConsumerState<DeleteAccountDialog> {
  final _password = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (_busy || !_form.currentState!.validate()) return;
    final lang = ref.read(appLanguageProvider);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(sessionProvider.notifier).deleteAccount(_password.text);
      if (mounted && (ModalRoute.of(context)?.isActive ?? false)) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!mounted) return;
      final wrongPassword =
          e is AuthFailure && e.reason == AuthFailureReason.invalidCredentials;
      setState(() {
        _busy = false;
        _error = wrongPassword
            ? lang.tr('settings.deleteAccountWrongPassword')
            : authErrorMessage(lang, e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(appLanguageProvider);
    final scheme = Theme.of(context).colorScheme;
    return PopScope(
      canPop: !_busy,
      child: AlertDialog(
        title: Text(lang.tr('settings.deleteAccountConfirm')),
        content: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(lang.tr('settings.deleteAccountMsg')),
                const SizedBox(height: 12),
                Text(lang.tr('settings.deleteAccountPasswordHint')),
                const SizedBox(height: 16),
                PasswordField(
                  key: const Key('settings-delete-account-password'),
                  controller: _password,
                  label: lang.tr('auth.password'),
                  toggleTooltip: lang.tr('auth.togglePassword'),
                  validator: (v) => (v ?? '').isEmpty
                      ? lang.tr('settings.deleteAccountWrongPassword')
                      : null,
                  onSubmitted: _confirm,
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      _error!,
                      key: const Key('settings-delete-account-error'),
                      style: TextStyle(color: scheme.error),
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _busy ? null : () => Navigator.of(context).pop(),
            child: Text(lang.tr('dash.cancel')),
          ),
          FilledButton(
            key: const Key('settings-delete-account-confirm'),
            style: FilledButton.styleFrom(backgroundColor: scheme.error),
            onPressed: _busy ? null : _confirm,
            child: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(lang.tr('settings.deleteAccount')),
          ),
        ],
      ),
    );
  }
}
