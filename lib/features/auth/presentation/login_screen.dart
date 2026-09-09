import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

    final authState = ref.read(authProvider).value;
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isSignUp ? 'auth_create_account'.tr() : 'auth_sign_in'.tr()),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),

              // ── Nom (inscription uniquement) ───────────────────────────
              if (_isSignUp) ...[
                TextFormField(
                  controller: _nameCtrl,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'auth_field_name'.tr(),
                    prefixIcon: const Icon(Icons.person_outline),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'auth_field_name_required'.tr()
                      : null,
                ),
                const SizedBox(height: 16),
              ],

              // ── Email ──────────────────────────────────────────────────
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: 'auth_field_email'.tr(),
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: const OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'auth_field_email_required'.tr();
                  }
                  if (!v.contains('@')) return 'auth_error_invalid_email'.tr();
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // ── Mot de passe ───────────────────────────────────────────
              TextFormField(
                controller: _passwordCtrl,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: 'auth_field_password'.tr(),
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
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
              const SizedBox(height: 24),

              // ── Erreur ─────────────────────────────────────────────────
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cs.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: cs.onErrorContainer, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // ── Bouton principal ───────────────────────────────────────
              FilledButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        _isSignUp
                            ? 'auth_create_account'.tr()
                            : 'auth_sign_in'.tr(),
                      ),
              ),

              const SizedBox(height: 16),

              // ── Toggle inscription / connexion ─────────────────────────
              TextButton(
                onPressed: () => setState(() {
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
    );
  }
}
