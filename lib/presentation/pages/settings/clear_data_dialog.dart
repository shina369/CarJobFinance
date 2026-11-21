import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_repository.dart';
import '../../../core/l10n/language_provider.dart';
import '../../../core/l10n/strings.dart';
import '../../controllers/data_controller.dart';
import '../../controllers/session_controller.dart';
import '../auth/auth_widgets.dart';

/// Asks for the account password before erasing every record on this device.
/// The password is checked on the server first: nothing is erased when it is
/// wrong or the server cannot be reached.
class ClearDataDialog extends ConsumerStatefulWidget {
  const ClearDataDialog({super.key});

  @override
  ConsumerState<ClearDataDialog> createState() => _ClearDataDialogState();
}

class _ClearDataDialogState extends ConsumerState<ClearDataDialog> {
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
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(sessionProvider.notifier).confirmPassword(_password.text);
    } catch (e) {
      if (!mounted) return;
      final wrongPassword =
          e is AuthFailure && e.reason == AuthFailureReason.invalidCredentials;
      setState(() {
        _busy = false;
        _error = wrongPassword
            ? lang.tr('settings.clearDataWrongPassword')
            : authErrorMessage(lang, e);
      });
      return;
    }
    try {
      await ref.read(dataControllerProvider).clearAll();
      messenger.showSnackBar(
          SnackBar(content: Text(lang.tr('settings.dataCleared'))));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text(lang.tr('export.failed').replaceAll('{error}', '$e')),
      ));
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(appLanguageProvider);
    final scheme = Theme.of(context).colorScheme;
    return PopScope(
      canPop: !_busy,
      child: AlertDialog(
        title: Text(lang.tr('settings.clearDataConfirm')),
        content: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(lang.tr('settings.clearDataMsg')),
                const SizedBox(height: 12),
                Text(lang.tr('settings.clearDataPasswordHint')),
                const SizedBox(height: 16),
                PasswordField(
                  key: const Key('settings-clear-data-password'),
                  controller: _password,
                  label: lang.tr('auth.password'),
                  toggleTooltip: lang.tr('auth.togglePassword'),
                  validator: (v) => (v ?? '').isEmpty
                      ? lang.tr('settings.clearDataWrongPassword')
                      : null,
                  onSubmitted: _confirm,
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      _error!,
                      key: const Key('settings-clear-data-error'),
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
            key: const Key('settings-clear-data-confirm'),
            style: FilledButton.styleFrom(backgroundColor: scheme.error),
            onPressed: _busy ? null : _confirm,
            child: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(lang.tr('settings.deleteAll')),
          ),
        ],
      ),
    );
  }
}
