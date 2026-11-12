// Create account: e-mail + password, then the code sent by e-mail.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/language_provider.dart';
import '../../../core/l10n/strings.dart';
import '../../controllers/session_controller.dart';
import 'auth_widgets.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key, this.pendingEmail});

  /// When set, the account already exists and only the e-mail confirmation
  /// code is missing, so the page opens on that step.
  final String? pendingEmail;

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage>
    with AuthFormMixin {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _code = TextEditingController();

  /// The address waiting for its confirmation code, once one was sent.
  String? _awaitingCodeFor;

  @override
  void initState() {
    super.initState();
    _awaitingCodeFor = widget.pendingEmail;
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _createAccount() async {
    if (!_formKey.currentState!.validate()) return;
    final email = _email.text.trim();
    var created = false;
    final ok = await submit(() async {
      created = await ref.read(sessionProvider.notifier).signUp(
            email,
            _password.text,
            firstName: _firstName.text,
            lastName: _lastName.text,
          );
    });
    if (ok && !created && mounted) setState(() => _awaitingCodeFor = email);
  }

  Future<void> _confirmCode() async {
    if (!_formKey.currentState!.validate()) return;
    await submit(() => ref
        .read(sessionProvider.notifier)
        .confirmSignUp(_awaitingCodeFor!, _code.text));
  }

  Future<void> _resend() async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await submit(() =>
        ref.read(sessionProvider.notifier).resendSignUpCode(_awaitingCodeFor!));
    if (ok) {
      messenger
          .showSnackBar(SnackBar(content: Text(lang.tr('auth.codeResent'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(appLanguageProvider);
    final awaiting = _awaitingCodeFor;

    if (awaiting != null) {
      return AuthScaffold(
        showBack: true,
        title: lang.tr('auth.codeTitle'),
        subtitle: lang.tr('auth.codeSent', args: {'email': awaiting}),
        children: [
          Form(
            key: _formKey,
            child: CodeField(
              controller: _code,
              label: lang.tr('auth.code'),
              validator: validateCode,
            ),
          ),
          AuthErrorText(error),
          AuthSubmitButton(
            label: lang.tr('auth.confirm'),
            busy: busy,
            onPressed: _confirmCode,
          ),
          const SizedBox(height: 12),
          TextButton(
            key: const Key('auth-resend'),
            onPressed: busy ? null : _resend,
            child: Text(lang.tr('auth.resendCode')),
          ),
        ],
      );
    }

    return AuthScaffold(
      showBack: true,
      title: lang.tr('auth.createAccount'),
      subtitle: lang.tr('auth.registerSubtitle'),
      children: [
        Form(
          key: _formKey,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                NameField(
                  fieldKey: const Key('auth-first-name'),
                  controller: _firstName,
                  label: lang.tr('auth.firstName'),
                  validator: validateName,
                  autofillHint: AutofillHints.givenName,
                ),
                const SizedBox(height: 16),
                NameField(
                  fieldKey: const Key('auth-last-name'),
                  controller: _lastName,
                  label: lang.tr('auth.lastName'),
                  validator: validateName,
                  autofillHint: AutofillHints.familyName,
                ),
                const SizedBox(height: 16),
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
                  validator: validatePassword,
                  isNew: true,
                ),
                const SizedBox(height: 16),
                PasswordField(
                  key: const Key('auth-confirm'),
                  controller: _confirm,
                  label: lang.tr('auth.confirmPassword'),
                  toggleTooltip: lang.tr('auth.togglePassword'),
                  validator: (v) => v == _password.text
                      ? null
                      : lang.tr('auth.err.passwordMismatch'),
                  isNew: true,
                  onSubmitted: _createAccount,
                ),
              ],
            ),
          ),
        ),
        AuthErrorText(error),
        AuthSubmitButton(
          label: lang.tr('auth.createAccount'),
          busy: busy,
          onPressed: _createAccount,
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: busy ? null : () => Navigator.of(context).maybePop(),
          child: Text(lang.tr('auth.haveAccount')),
        ),
      ],
    );
  }
}
