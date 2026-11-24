import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_repository.dart';
import '../../../core/l10n/language_provider.dart';
import '../../../core/l10n/strings.dart';
import '../../../core/settings/app_settings_notifier.dart';
import '../../../core/settings/country_data.dart';
import '../../controllers/session_controller.dart';
import '../auth/auth_widgets.dart';

/// Edits the name of the signed-in account (saved on the server) and the
/// country of this device. Each part is written only when it changed.
class ProfileEditDialog extends ConsumerStatefulWidget {
  const ProfileEditDialog({super.key});

  @override
  ConsumerState<ProfileEditDialog> createState() => _ProfileEditDialogState();
}

class _ProfileEditDialogState extends ConsumerState<ProfileEditDialog> {
  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late String _countryCode;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final user = ref.read(sessionProvider).user;
    _firstName = TextEditingController(text: user?.firstName ?? '');
    _lastName = TextEditingController(text: user?.lastName ?? '');
    _countryCode = ref.read(appSettingsProvider).countryCode;
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    super.dispose();
  }

  bool get _canSave =>
      !_busy && isValidName(_firstName.text) && isValidName(_lastName.text);

  Future<void> _save() async {
    if (!_canSave) return;
    final lang = ref.read(appLanguageProvider);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final user = ref.read(sessionProvider).user;
    if (user == null) {
      navigator.pop();
      return;
    }
    final firstName = _firstName.text.trim();
    final lastName = _lastName.text.trim();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (firstName != user.firstName || lastName != user.lastName) {
        await ref.read(sessionProvider.notifier).updateProfile(
              firstName: firstName,
              lastName: lastName,
            );
      }
      if (_countryCode != ref.read(appSettingsProvider).countryCode) {
        await ref.read(appSettingsProvider.notifier).setCountry(_countryCode);
      }
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(content: Text(lang.tr('settings.profileSaved'))),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = authErrorMessage(lang, e);
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
        title: Text(lang.tr('settings.profileTitle')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                key: const Key('settings-profile-first-name'),
                controller: _firstName,
                enabled: !_busy,
                textCapitalization: TextCapitalization.words,
                decoration:
                    InputDecoration(labelText: lang.tr('auth.firstName')),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('settings-profile-last-name'),
                controller: _lastName,
                enabled: !_busy,
                textCapitalization: TextCapitalization.words,
                decoration:
                    InputDecoration(labelText: lang.tr('auth.lastName')),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: const Key('settings-profile-country'),
                initialValue: _countryCode,
                isExpanded: true,
                decoration:
                    InputDecoration(labelText: lang.tr('onboarding.country')),
                items: [
                  for (final country in COUNTRIES)
                    DropdownMenuItem(
                      value: country.code,
                      child: Text(country.namePt),
                    ),
                ],
                onChanged: _busy
                    ? null
                    : (value) {
                        if (value != null) {
                          setState(() => _countryCode = value);
                        }
                      },
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _error!,
                    key: const Key('settings-profile-error'),
                    style: TextStyle(color: scheme.error),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _busy ? null : () => Navigator.of(context).pop(),
            child: Text(lang.tr('dash.cancel')),
          ),
          FilledButton(
            key: const Key('settings-profile-save'),
            onPressed: _canSave ? _save : null,
            child: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(lang.tr('dash.save')),
          ),
        ],
      ),
    );
  }
}
