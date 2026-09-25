import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nextarc/core/theme/app_tokens.dart';
import 'package:nextarc/core/widgets/ds/ds.dart';
import 'package:nextarc/features/auth/domain/auth_providers.dart';

/// Écran de connexion / inscription par email + mot de passe.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();

  bool _isSignUp = false;
  bool _obscurePassword = true;
  bool _loading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    final notifier = ref.read(authProvider.notifier);

    if (_isSignUp) {
      await notifier.createAccount(
        _emailCtrl.text,
        _passwordCtrl.text,
        _nameCtrl.text,
      );
    } else {
      await notifier.loginWithEmail(_emailCtrl.text, _passwordCtrl.text);
    }

    if (!mounted) return;

    final authState = ref.read(authProvider).valueOrNull;
    if (authState?.isAuthenticated == true) {
      Navigator.of(context).pop();
    } else {
      final err = authState?.error ?? 'auth_error_generic';
      setState(() {
        _loading = false;
        _errorMessage = err.tr();
      });
    }
  }

  /// « Mot de passe oublié ? » : envoie un lien de réinitialisation à
  /// l'adresse saisie.
  Future<void> _resetPassword() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _errorMessage = 'auth_reset_email_first'.tr());
      return;
    }
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      await ref.read(firebaseAuthServiceProvider).sendPasswordReset(
            email,
            languageCode: context.locale.languageCode,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('auth_reset_sent'.tr(namedArgs: {'email': email})),
      ));
    } catch (_) {
      if (mounted) {
        setState(() => _errorMessage = 'auth_reset_error'.tr());
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screen - 4, AppSpacing.xs, AppSpacing.screen, 0),
              child: Row(
                children: [
                  Tooltip(
                    message:
                        MaterialLocalizations.of(context).backButtonTooltip,
                    child: InkResponse(
                      radius: 24,
                      onTap: () => Navigator.of(context).maybePop(),
                      child: SizedBox(
                        width: AppSpacing.minTouch,
                        height: AppSpacing.minTouch,
                        child: Center(
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                                color: c.surface2, shape: BoxShape.circle),
                            child: Icon(Icons.arrow_back_rounded,
                                size: 18, color: c.text2),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                    22, AppSpacing.md, 22, AppSpacing.lg + bottomInset),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _isSignUp
                            ? 'auth_create_account'.tr()
                            : 'auth_sign_in'.tr(),
                        style: text.headlineMedium?.copyWith(color: c.text1),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _isSignUp
                            ? 'auth_email_signup_hint'.tr()
                            : 'auth_email_signin_hint'.tr(),
                        style: text.bodyMedium?.copyWith(color: c.text2),
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      // ── Nom (inscription uniquement) ─────────────────
                      if (_isSignUp) ...[
                        TextFormField(
                          controller: _nameCtrl,
                          textInputAction: TextInputAction.next,
                          textCapitalization: TextCapitalization.words,
                          autofillHints: const [AutofillHints.nickname],
                          decoration: InputDecoration(
                            labelText: 'auth_field_name'.tr(),
                            prefixIcon: const Icon(Icons.person_outline),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'auth_field_name_required'.tr()
                              : null,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                      ],

                      // ── Email ────────────────────────────────────────
                      TextFormField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autocorrect: false,
                        autofillHints: const [AutofillHints.email],
                        decoration: InputDecoration(
                          labelText: 'auth_field_email'.tr(),
                          prefixIcon: const Icon(Icons.mail_outline_rounded),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'auth_field_email_required'.tr();
                          }
                          if (!v.contains('@')) {
                            return 'auth_error_invalid_email'.tr();
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.sm),

                      // ── Mot de passe ─────────────────────────────────
                      TextFormField(
                        controller: _passwordCtrl,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.done,
                        autofillHints: [
                          _isSignUp
                              ? AutofillHints.newPassword
                              : AutofillHints.password,
                        ],
                        onFieldSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          labelText: 'auth_field_password'.tr(),
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          suffixIcon: IconButton(
                            tooltip: _obscurePassword
                                ? 'auth_show_password'.tr()
                                : 'auth_hide_password'.tr(),
                            icon: Icon(_obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined),
                            onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'auth_field_password_required'.tr();
                          }
                          if (_isSignUp && v.length < 6) {
                            return 'auth_error_weak_password'.tr();
                          }
                          return null;
                        },
                      ),
                      if (!_isSignUp)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            style: TextButton.styleFrom(
                                foregroundColor: c.accentText),
                            onPressed: _loading ? null : _resetPassword,
                            child: Text('auth_forgot_password'.tr()),
                          ),
                        ),
                      SizedBox(
                          height: _isSignUp ? AppSpacing.lg : AppSpacing.xs),

                      // ── Erreur ───────────────────────────────────────
                      if (_errorMessage != null) ...[
                        _ErrorBox(message: _errorMessage!),
                        const SizedBox(height: AppSpacing.md),
                      ],

                      AppButton(
                        label: _isSignUp
                            ? 'auth_create_account'.tr()
                            : 'auth_sign_in'.tr(),
                        expand: true,
                        loading: _loading,
                        onPressed: _submit,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextButton(
                        style:
                            TextButton.styleFrom(foregroundColor: c.accentText),
                        onPressed: _loading
                            ? null
                            : () => setState(() {
                                  _isSignUp = !_isSignUp;
                                  _errorMessage = null;
                                }),
                        child: Text(
                          _isSignUp
                              ? 'auth_already_have_account'.tr()
                              : 'auth_no_account'.tr(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Message d'erreur de connexion (rouge discret).
class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: c.favourite.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.cover),
        border: Border.all(color: c.favourite.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, size: 18, color: c.statusDroppedText),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: c.statusDroppedText),
            ),
          ),
        ],
      ),
    );
  }
}
