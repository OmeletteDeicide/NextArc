import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nextarc/core/constants/app_version.dart';
import 'package:nextarc/core/theme/app_tokens.dart';
import 'package:nextarc/core/theme/app_typography.dart';
import 'package:nextarc/core/widgets/ds/ds.dart';
import 'package:url_launcher/url_launcher.dart';

/// Politique de confidentialité (GitHub Pages, dossier `docs/`).
const String privacyPolicyUrl =
    'https://omelettedeicide.github.io/NextArc/privacy-policy.html';

/// Conditions d'utilisation : lien masqué tant qu'aucune page n'existe.
const String? termsUrl = null;

void _open(String url) =>
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

/// Écran « À propos » : crédits AniList (obligatoires), technologies, liens.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const _technologies = [
    'Flutter',
    'Dart',
    'Material 3',
    'GraphQL',
    'Firebase',
  ];

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
                  AppSpacing.screen - 4, AppSpacing.xs, AppSpacing.screen, 8),
              child: Row(
                children: [
                  RoundIconButton(
                    icon: Icons.arrow_back_rounded,
                    tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                    color: c.accentText,
                    onTap: () => context.pop(),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('about_title'.tr(),
                        style: text.titleLarge?.copyWith(color: c.text1)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.xs,
                    AppSpacing.screen, AppSpacing.lg + bottomInset),
                children: [
                  // ── Logo ────────────────────────────────────────────────
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.asset('assets/images/logo.png',
                            width: 58, height: 58, fit: BoxFit.cover),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'NextArc',
                              style: text.headlineSmall?.copyWith(color: c.text1),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'about_version'
                                  .tr(namedArgs: {'version': appVersion}),
                              style: text.labelMedium?.copyWith(
                                color: c.accentText,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'about_description'.tr(),
                    style: text.bodyMedium?.copyWith(color: c.text2, height: 1.65),
                  ),

                  // ── Crédits AniList ─────────────────────────────────────
                  _Overline('about_data_provided_by'.tr()),
                  const _AnilistCard(),

                  // ── Technologies ────────────────────────────────────────
                  _Overline('about_section_technologies'.tr()),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final tech in _technologies)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: c.surface2,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            tech,
                            style: text.labelMedium?.copyWith(
                                color: c.text2, fontWeight: FontWeight.w600),
                          ),
                        ),
                    ],
                  ),

                  // ── Développement ───────────────────────────────────────
                  _Overline('about_section_developer'.tr()),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 13),
                    decoration: BoxDecoration(
                      color: c.surface1,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: c.accentGradient,
                          ),
                          child: Text(
                            'E',
                            style: text.titleSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Espiègle',
                                  style: text.titleSmall
                                      ?.copyWith(color: c.text1)),
                              const SizedBox(height: 2),
                              Text(
                                'about_developer_note'.tr(),
                                style: text.bodySmall?.copyWith(
                                    color: c.text2, fontSize: 10.5),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Liens légaux ────────────────────────────────────────
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 4,
                    children: [
                      _LinkButton(
                        label: 'about_privacy'.tr(),
                        onTap: () => _open(privacyPolicyUrl),
                      ),
                      if (termsUrl case final url?)
                        _LinkButton(
                          label: 'about_terms'.tr(),
                          onTap: () => _open(url),
                        ),
                      _LinkButton(
                        label: 'about_licenses'.tr(),
                        onTap: () => showLicensePage(
                          context: context,
                          applicationName: 'NextArc',
                          applicationVersion: appVersion,
                        ),
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

class _Overline extends StatelessWidget {
  const _Overline(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 10),
      child: Text(label.toUpperCase(),
          style: AppTypography.overline(AppColors.of(context).text3)),
    );
  }
}

/// Carte AniList encadrée d'accent : mention contractuelle, repérable sans
/// ressembler à une publicité.
class _AnilistCard extends StatelessWidget {
  const _AnilistCard();

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final text = Theme.of(context).textTheme;

    return Material(
      color: c.surface1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: c.accent.withValues(alpha: 0.24)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _open('https://anilist.co'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: c.accent.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(Icons.data_object_rounded,
                        size: 16, color: c.accentText),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('AniList',
                        style: text.titleSmall?.copyWith(
                            color: c.text1, fontWeight: FontWeight.w800)),
                  ),
                  Icon(Icons.open_in_new_rounded,
                      size: 16, color: c.accentText),
                ],
              ),
              const SizedBox(height: 8),
              Text.rich(
                TextSpan(children: [
                  TextSpan(text: '${'about_credit_anilist_subtitle'.tr()} '),
                  TextSpan(
                    text: 'about_credit_not_affiliated'.tr(),
                    style: TextStyle(
                        color: c.text1, fontWeight: FontWeight.w700),
                  ),
                ]),
                style: text.bodySmall?.copyWith(color: c.text2, height: 1.6),
              ),
              const SizedBox(height: 8),
              Text('anilist.co',
                  style: text.labelMedium?.copyWith(
                      color: c.accentText, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

class _LinkButton extends StatelessWidget {
  const _LinkButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSpacing.minTouch),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Center(
            widthFactor: 1,
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: c.accentText, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ),
    );
  }
}
