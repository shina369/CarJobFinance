// Login: the gate in front of the whole app.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_repository.dart';
import '../../../core/auth/credential_store.dart';
import '../../../core/l10n/language_provider.dart';
import '../../../core/l10n/languages.dart';
import '../../../core/l10n/strings.dart';
import '../../controllers/session_controller.dart';
import '../../widgets/flag_icon.dart';
import 'auth_widgets.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> with AuthFormMixin {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _languages = signInLanguages();
  bool _remember = false;

  @override
  void initState() {
    super.initState();
    _prefillSavedLogin();
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _prefillSavedLogin() async {
    final SavedLogin? saved;
    try {
      saved = await ref.read(credentialStoreProvider).read();
    } catch (_) {
      return;
    }
    if (!mounted || saved == null || _email.text.isNotEmpty) return;
    _email.text = saved.email;
    _password.text = saved.password;
    setState(() => _remember = true);
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    final session = ref.read(sessionProvider.notifier);
    final email = _email.text.trim();
    var needsConfirmation = false;

    await submit(() async {
      try {
        await session.signIn(email, _password.text, remember: _remember);
      } on AuthFailure catch (e) {
        if (e.reason != AuthFailureReason.emailNotConfirmed) rethrow;
        await session.resendSignUpCode(email);
        needsConfirmation = true;
      }
    });

    if (needsConfirmation && mounted) {
      context.push('/register', extra: email);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(appLanguageProvider);
    final selected = _languages.firstWhere(
      (option) => option.covers(lang),
      orElse: () => _languages.first,
    );

    return AuthScaffold(
      title: lang.tr('auth.signIn'),
      subtitle: lang.tr('auth.loginSubtitle'),
      children: [
        DropdownButtonFormField<SignInLanguage>(
          key: ValueKey('auth-language-${selected.language.tag}'),
          isExpanded: true,
          initialValue: selected,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.language),
            border: OutlineInputBorder(),
            isDense: true,
          ),
          items: [
            for (final option in _languages)
              DropdownMenuItem(
                key: Key('auth-language-option-${option.language.tag}'),
                value: option,
                child: Row(
                  children: [
                    FlagIcon(option.flagCountry, width: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        option.label,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
          ],
          onChanged: (option) {
            if (option != null) {
              ref.read(languageProvider.notifier).setLanguage(option.language);
            }
          },
        ),
        const SizedBox(height: 24),
        Form(
          key: _formKey,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                EmailField(
                  controller: _email,
                  label: lang.tr('auth.email'),
                  validator: validateEmail,
                ),
                const SizedBox(height: 16),
                PasswordField(
                  key: const Key('auth-password'),
                  controller: _password,
                  label: lang.tr('auth.password'),
                  toggleTooltip: lang.tr('auth.togglePassword'),
                  validator: (v) => (v ?? '').isEmpty
                      ? lang.tr('auth.err.invalidCredentials')
                      : null,
                  onSubmitted: _signIn,
                ),
              ],
            ),
          ),
        ),
        CheckboxListTile(
          key: const Key('auth-remember'),
          value: _remember,
          onChanged:
              busy ? null : (v) => setState(() => _remember = v ?? false),
          title: Text(lang.tr('auth.rememberMe')),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          dense: true,
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            key: const Key('auth-forgot'),
            onPressed: busy ? null : () => context.push('/forgot-password'),
            child: Text(lang.tr('auth.forgotPassword')),
          ),
        ),
        AuthErrorText(error),
        AuthSubmitButton(
          label: lang.tr('auth.signIn'),
          busy: busy,
          onPressed: _signIn,
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          key: const Key('auth-create'),
          onPressed: busy ? null : () => context.push('/register'),
          style:
              OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          child: Text(lang.tr('auth.createAccount')),
        ),
      ],
    );
  }
}
