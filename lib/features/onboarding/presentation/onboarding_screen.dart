import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nextarc/core/router/app_router.dart';
import 'package:nextarc/core/theme/app_tokens.dart';
import 'package:nextarc/core/theme/app_typography.dart';
import 'package:nextarc/core/widgets/ds/ds.dart';
import 'package:nextarc/core/widgets/google_logo.dart';
import 'package:nextarc/features/auth/domain/auth_providers.dart';
import 'package:nextarc/features/onboarding/domain/onboarding_prefs.dart';

/// Onboarding léger : 3 écrans (promesse · contenu · compte), « Passer »
/// toujours visible, une seule question, aucune demande de notifications.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const _pageCount = 3;

  final _controller = PageController();
  int _page = 0;
  ContentChoice _choice = ContentChoice.anime;
  bool _signingIn = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    HapticFeedback.selectionClick();
    _controller.nextPage(
      duration: AppMotion.transition,
      curve: Curves.easeOutCubic,
    );
  }

  /// Termine l'onboarding (avec ou sans réponse) et ouvre l'app.
  Future<void> _finish({bool saveChoice = true}) async {
    ref.read(onboardingDoneProvider.notifier).state = true;
    if (saveChoice) ref.read(contentChoiceProvider.notifier).state = _choice;
    try {
      await OnboardingPrefs.saveDone();
      if (saveChoice) await OnboardingPrefs.saveChoice(_choice);
    } catch (_) {
      // Au pire l'onboarding repassera : jamais bloquant
    }
    if (mounted) context.go(AppRoutes.discover);
  }

  Future<void> _google() async {
    setState(() => _signingIn = true);
    await ref.read(authProvider.notifier).loginWithGoogle();
    if (!mounted) return;
    setState(() => _signingIn = false);
    final auth = ref.read(authProvider).valueOrNull;
    if (auth?.isAuthenticated == true) {
      await _finish();
    } else if (auth?.error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(auth!.error!.tr())));
    }
  }

  Future<void> _email() async {
    await context.push(AppRoutes.login);
    if (!mounted) return;
    if (ref.read(authProvider).valueOrNull?.isAuthenticated == true) {
      await _finish();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_page > 0) {
          _controller.previousPage(
              duration: AppMotion.transition, curve: Curves.easeOutCubic);
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            // Halo violet du premier écran
            if (isDark)
              Positioned(
                right: -50,
                top: -50,
                child: IgnorePointer(
                  child: AnimatedOpacity(
                    duration: AppMotion.transition,
                    opacity: _page == 0 ? 1 : 0,
                    child: Container(
                      width: 260,
                      height: 260,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            c.violet.withValues(alpha: 0.45),
                            c.violet.withValues(alpha: 0),
                          ],
                          stops: const [0, 0.7],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            SafeArea(
              bottom: false,
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(0, 4, 8, 0),
                      child: TextButton(
                        style: TextButton.styleFrom(foregroundColor: c.text2),
                        onPressed: () => _finish(saveChoice: _page > 1),
                        child: Text('onboarding_skip'.tr()),
                      ),
                    ),
                  ),
                  Expanded(
                    child: PageView(
                      controller: _controller,
                      onPageChanged: (i) => setState(() => _page = i),
                      children: [
                        const _PromisePage(),
                        _ContentPage(
                          choice: _choice,
                          onChanged: (v) => setState(() => _choice = v),
                        ),
                        _AccountPage(
                          signingIn: _signingIn,
                          onGoogle: _google,
                          onEmail: _email,
                          onGuest: _finish,
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                        22, AppSpacing.sm, 22, 22 + bottomInset),
                    child: SizedBox(
                      height: AppSpacing.minTouch,
                      child: Row(
                        children: [
                          for (var i = 0; i < _pageCount; i++) ...[
                            if (i > 0) const SizedBox(width: 8),
                            AnimatedContainer(
                              duration: AppMotion.transition,
                              width: i == _page ? 22 : 5,
                              height: 5,
                              decoration: BoxDecoration(
                                color: i == _page ? c.accentText : c.surface2,
                                borderRadius:
                                    BorderRadius.circular(AppRadius.full),
                              ),
                            ),
                          ],
                          const Spacer(),
                          // Le dernier écran a ses propres actions
                          if (_page < _pageCount - 1)
                            AppButton(
                              label: 'onboarding_next'.tr(),
                              onPressed: _next,
                            ),
                        ],
                      ),
                    ),
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

// ── Écrans ────────────────────────────────────────────────────────────────────

class _PageFrame extends StatelessWidget {
  const _PageFrame({
    required this.step,
    required this.title,
    required this.body,
    this.top,
    this.children = const [],
    this.titleAtBottom = false,
  });

  final String step;
  final String title;
  final String body;
  final Widget? top;
  final List<Widget> children;

  /// Premier écran : texte posé en bas, logo en haut.
  final bool titleAtBottom;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final text = Theme.of(context).textTheme;

    final heading = [
      Text(step.toUpperCase(), style: AppTypography.overline(c.text3)),
      const SizedBox(height: 10),
      Text(
        title,
        style: text.headlineMedium?.copyWith(
          fontSize: titleAtBottom ? 27 : 23,
          height: 1.12,
          letterSpacing: -1,
          color: c.text1,
        ),
      ),
      const SizedBox(height: 10),
      Text(body, style: text.bodyMedium?.copyWith(color: c.text2, height: 1.6)),
    ];

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 22),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: titleAtBottom
                ? MainAxisAlignment.spaceBetween
                : MainAxisAlignment.start,
            children: [
              ?top,
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ...heading,
                  if (children.isNotEmpty) const SizedBox(height: 20),
                  ...children,
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PromisePage extends StatelessWidget {
  const _PromisePage();

  @override
  Widget build(BuildContext context) {
    return _PageFrame(
      titleAtBottom: true,
      top: Align(
        alignment: Alignment.centerLeft,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.asset('assets/images/logo.png',
              width: 44, height: 44, fit: BoxFit.cover),
        ),
      ),
      step: 'onboarding_step_promise'.tr(),
      title: 'onboarding_promise_title'.tr(),
      body: 'onboarding_promise_body'.tr(),
    );
  }
}

class _ContentPage extends StatelessWidget {
  const _ContentPage({required this.choice, required this.onChanged});

  final ContentChoice choice;
  final ValueChanged<ContentChoice> onChanged;

  @override
  Widget build(BuildContext context) {
    return _PageFrame(
      step: 'onboarding_step_content'.tr(),
      title: 'onboarding_content_title'.tr(),
      body: 'onboarding_content_body'.tr(),
      children: [
        for (final (value, icon, key) in const [
          (ContentChoice.anime, Icons.play_arrow_rounded,
              'onboarding_content_anime'),
          (ContentChoice.manga, Icons.menu_book_rounded,
              'onboarding_content_manga'),
          (ContentChoice.both, Icons.auto_awesome_rounded,
              'onboarding_content_both'),
        ]) ...[
          _ChoiceCard(
            icon: icon,
            label: key.tr(),
            selected: choice == value,
            onTap: () {
              HapticFeedback.selectionClick();
              onChanged(value);
            },
          ),
          const SizedBox(height: 11),
        ],
      ],
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? c.accent.withValues(alpha: 0.14) : c.surface1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: BorderSide(
            color: selected
                ? c.accentText.withValues(alpha: 0.5)
                : Colors.transparent,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: selected
                        ? c.accent.withValues(alpha: 0.2)
                        : c.surface2,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icon,
                      size: 20, color: selected ? c.accentText : c.text2),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: selected ? c.text1 : c.text2),
                  ),
                ),
                AnimatedContainer(
                  duration: AppMotion.press,
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: selected ? c.accentGradient : null,
                    border: selected
                        ? null
                        : Border.all(color: c.text3, width: 1.5),
                  ),
                  child: selected
                      ? const Icon(Icons.check_rounded,
                          size: 13, color: Colors.white)
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AccountPage extends StatelessWidget {
  const _AccountPage({
    required this.signingIn,
    required this.onGoogle,
    required this.onEmail,
    required this.onGuest,
  });

  final bool signingIn;
  final VoidCallback onGoogle;
  final VoidCallback onEmail;
  final VoidCallback onGuest;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final hint = Theme.of(context)
        .textTheme
        .bodySmall
        ?.copyWith(color: c.text3, fontSize: 10.5, height: 1.5);

    return _PageFrame(
      step: 'onboarding_step_account'.tr(),
      title: 'onboarding_account_title'.tr(),
      body: 'onboarding_account_body'.tr(),
      children: [
        AppButton(
          label: 'auth_continue_google'.tr(),
          leading: const GoogleLogo(),
          expand: true,
          loading: signingIn,
          onPressed: onGoogle,
        ),
        const SizedBox(height: 10),
        AppButton(
          label: 'auth_continue_email'.tr(),
          icon: Icons.mail_outline_rounded,
          variant: AppButtonVariant.secondary,
          expand: true,
          onPressed: signingIn ? null : onEmail,
        ),
        const SizedBox(height: 14),
        Center(
          child: TextButton(
            style: TextButton.styleFrom(foregroundColor: c.accentText),
            onPressed: signingIn ? null : onGuest,
            child: Text('auth_continue_guest'.tr(),
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
        Text('onboarding_guest_hint'.tr(),
            textAlign: TextAlign.center, style: hint),
      ],
    );
  }
}
