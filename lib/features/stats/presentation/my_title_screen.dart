import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nextarc/core/theme/app_tokens.dart';
import 'package:nextarc/core/theme/app_typography.dart';
import 'package:nextarc/core/widgets/ds/ds.dart';
import 'package:nextarc/features/stats/domain/stats_provider.dart';
import 'package:nextarc/features/stats/domain/user_title.dart';

/// Écran « Mon titre » : deux jauges (nom, qualificatif), Arcer à part,
/// échelle des noms. Toujours sur le cumul total.
class MyTitleScreen extends ConsumerWidget {
  const MyTitleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(statsProvider);
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
                  _BackButton(
                    onTap: () => context.canPop()
                        ? context.pop()
                        : context.go('/profile'),
                  ),
                  const SizedBox(width: 6),
                  Text('title_section'.tr(),
                      style: text.headlineSmall
                          ?.copyWith(fontSize: 19, color: c.text1)),
                ],
              ),
            ),
            Expanded(
              child: statsAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: AppButton(
                      label: 'action_retry'.tr(),
                      icon: Icons.refresh_rounded,
                      variant: AppButtonVariant.secondary,
                      onPressed: () => ref.invalidate(statsProvider),
                    ),
                  ),
                ),
                data: (stats) => ListView(
                  padding: EdgeInsets.fromLTRB(AppSpacing.screen, 14,
                      AppSpacing.screen, AppSpacing.xl + bottomInset),
                  children: [
                    _CurrentTitleHero(title: stats.title),
                    const SizedBox(height: 14),
                    _RankGauge(title: stats.title),
                    const SizedBox(height: 10),
                    _QualifierGauge(title: stats.title),
                    const SizedBox(height: 14),
                    _ArcerCard(title: stats.title),
                    const SizedBox(height: 18),
                    _RankLadder(title: stats.title),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Tooltip(
      message: MaterialLocalizations.of(context).backButtonTooltip,
      child: InkResponse(
        radius: 24,
        onTap: onTap,
        child: SizedBox(
          width: AppSpacing.minTouch,
          height: AppSpacing.minTouch,
          child: Center(
            child: Container(
              width: 36,
              height: 36,
              decoration:
                  BoxDecoration(color: c.surface2, shape: BoxShape.circle),
              child: Icon(Icons.arrow_back_rounded, size: 18, color: c.text2),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Titre actuel ──────────────────────────────────────────────────────────────

class _CurrentTitleHero extends StatelessWidget {
  const _CurrentTitleHero({required this.title});

  final UserTitle title;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final numbers = NumberFormat.decimalPattern(context.locale.toString());

    final chipColor = isDark ? const Color(0xFFD6D0F5) : Colors.white;
    final qualifierWord = title.qualifierKey == null
        ? 'title_qual_none'.tr()
        : '${title.qualifierKey}_word'.tr();

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.sheet),
        gradient: isDark
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF2A2160), Color(0xFF151C3E)],
                stops: [0, 0.75],
              )
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [c.accent, c.violet],
              ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -30,
            top: -40,
            child: IgnorePointer(
              child: Container(
                width: 170,
                height: 170,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      c.violet.withValues(alpha: isDark ? 0.45 : 0.35),
                      c.violet.withValues(alpha: 0),
                    ],
                    stops: const [0, 0.7],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'my_title_overline'.tr().toUpperCase(),
                  style: AppTypography.overline(
                      isDark ? const Color(0xFFA99BE0) : Colors.white70),
                ),
                const SizedBox(height: 9),
                Row(
                  children: [
                    if (title.isArcer) ...[
                      const Text('👑', style: TextStyle(fontSize: 24)),
                      const SizedBox(width: 8),
                    ],
                    Flexible(
                      child: Text(
                        title.label,
                        style: text.displaySmall?.copyWith(
                          fontSize: 28,
                          height: 1.05,
                          letterSpacing: -1,
                          color: title.isArcer ? c.star : Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                if (!title.isArcer) ...[
                  const SizedBox(height: 11),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      _HeroChip(
                        label: 'my_title_chip'.tr(namedArgs: {
                          'word': qualifierWord,
                          'value': '${numbers.format(title.watchHours)} h',
                        }),
                        color: chipColor,
                      ),
                      _HeroChip(
                        label: 'my_title_chip'.tr(namedArgs: {
                          'word': title.rankKey.tr(),
                          'value': numbers.format(title.animeCompleted),
                        }),
                        color: chipColor,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .labelMedium
            ?.copyWith(color: color, fontSize: 10.5, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ── Jauges ────────────────────────────────────────────────────────────────────

class _GaugeCard extends StatelessWidget {
  const _GaugeCard({
    required this.title,
    required this.value,
    required this.progress,
    required this.hint,
  });

  final String title;
  final String value;
  final double progress;
  final InlineSpan hint;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface1,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: text.titleSmall
                      ?.copyWith(fontSize: 12.5, color: c.text1),
                ),
              ),
              Text(
                value,
                style: text.labelSmall?.copyWith(
                  color: c.accentText,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          GradientProgressBar(
              value: progress == 0 ? 0 : progress.clamp(0.01, 1.0)),
          const SizedBox(height: 9),
          Text.rich(
            hint,
            style: text.bodySmall
                ?.copyWith(color: c.text2, fontSize: 11, height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _RankGauge extends StatelessWidget {
  const _RankGauge({required this.title});

  final UserTitle title;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final numbers = NumberFormat.decimalPattern(context.locale.toString());
    final strong = TextStyle(color: c.text1, fontWeight: FontWeight.w700);
    final next = title.nextRankThreshold;

    if (next == null) {
      return _GaugeCard(
        title: 'my_title_rank_max'.tr(),
        value: numbers.format(title.animeCompleted),
        progress: 1,
        hint: TextSpan(text: 'title_rank_legend'.tr(), style: strong),
      );
    }

    final left = next - title.animeCompleted;
    final nextName = UserTitle.ranks[title.rankIndex + 1].$2.tr();
    return _GaugeCard(
      title: 'my_title_next_rank'.tr(namedArgs: {'name': nextName}),
      value: '${numbers.format(title.animeCompleted)}/${numbers.format(next)}',
      progress: title.rankProgress,
      hint: TextSpan(children: [
        TextSpan(text: 'my_title_still'.tr()),
        TextSpan(
          text: left == 1
              ? 'my_title_anime_left_one'.tr()
              : 'my_title_anime_left'
                  .tr(namedArgs: {'count': numbers.format(left)}),
          style: strong,
        ),
      ]),
    );
  }
}

class _QualifierGauge extends StatelessWidget {
  const _QualifierGauge({required this.title});

  final UserTitle title;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final numbers = NumberFormat.decimalPattern(context.locale.toString());
    final strong = TextStyle(color: c.text1, fontWeight: FontWeight.w700);
    final next = title.nextQualifierThreshold;
    final name = title.rankKey.tr();

    if (next == null) {
      return _GaugeCard(
        title: 'my_title_qualifier'.tr(),
        value: '${numbers.format(title.watchHours)} h',
        progress: 1,
        hint: TextSpan(text: 'my_title_qualifier_max'.tr()),
      );
    }

    final left = next - title.watchHours;
    final hours = TextSpan(
      text: 'my_title_hours_left'.tr(namedArgs: {'hours': numbers.format(left)}),
      style: strong,
    );

    final List<InlineSpan> rest;
    if (title.nextQualifierDropsWord) {
      rest = [
        TextSpan(
          text: 'my_title_drop_word'
              .tr(namedArgs: {'word': '${title.qualifierKey}_word'.tr()}),
        ),
        TextSpan(text: name, style: strong),
      ];
    } else {
      final nextTitle = title.nextQualifierKey == null
          ? name
          : title.nextQualifierKey!.tr(namedArgs: {'name': name});
      rest = [
        TextSpan(text: 'my_title_become'.tr()),
        TextSpan(text: nextTitle, style: strong),
      ];
    }

    return _GaugeCard(
      title: 'my_title_qualifier'.tr(),
      value: '${numbers.format(title.watchHours)}/${numbers.format(next)} h',
      progress: title.qualifierProgress,
      hint: TextSpan(children: [
        TextSpan(text: 'my_title_still'.tr()),
        hours,
        ...rest,
      ]),
    );
  }
}

// ── Arcer (hors échelle) ──────────────────────────────────────────────────────

class _ArcerCard extends StatelessWidget {
  const _ArcerCard({required this.title});

  final UserTitle title;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final numbers = NumberFormat.decimalPattern(context.locale.toString());

    final strongGold =
        isDark ? const Color(0xFFFFD98A) : const Color(0xFF7A4A00);
    final softGold = isDark ? const Color(0xFFC6A864) : const Color(0xFF8A5200);

    Widget gauge(String label, String value, double progress) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(label,
                      style: text.bodySmall?.copyWith(
                          color: softGold,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600)),
                ),
                Text(value,
                    style: text.bodySmall?.copyWith(
                        color: strongGold,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 6),
            GradientProgressBar(
              value: progress == 0 ? 0 : progress.clamp(0.01, 1.0),
              height: 6,
              colors: [c.star, c.star],
            ),
          ],
        );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? c.star.withValues(alpha: 0.09) : const Color(0xFFFFF7E6),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: c.star.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text('👑', style: TextStyle(fontSize: 15)),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.isArcer
                          ? 'title_arcer_reached'.tr()
                          : 'my_title_arcer_title'.tr(),
                      style: text.labelLarge?.copyWith(color: strongGold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'my_title_arcer_sub'.tr(),
                      style: text.bodySmall
                          ?.copyWith(color: softGold, fontSize: 10.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          gauge(
            'my_title_arcer_completed'.tr(),
            '${numbers.format(title.totalCompleted)} / ${numbers.format(UserTitle.arcerMinCompleted)}',
            title.arcerCompletedProgress,
          ),
          const SizedBox(height: 10),
          gauge(
            'my_title_arcer_hours'.tr(),
            '${numbers.format(title.totalHours)} / ${numbers.format(UserTitle.arcerMinHours)} h',
            title.arcerHoursProgress,
          ),
        ],
      ),
    );
  }
}

// ── Échelle des noms ──────────────────────────────────────────────────────────

class _RankLadder extends StatefulWidget {
  const _RankLadder({required this.title});

  final UserTitle title;

  @override
  State<_RankLadder> createState() => _RankLadderState();
}

class _RankLadderState extends State<_RankLadder> {
  bool _expanded = false;

  /// Paliers visibles repliés : tous les atteints jusqu'à l'actuel est trop
  /// long, on garde l'actuel, le prochain et celui d'après.
  static const _collapsedAhead = 2;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    final numbers = NumberFormat.decimalPattern(context.locale.toString());
    final current = widget.title.rankIndex;
    final ranks = UserTitle.ranks;

    final start = _expanded ? 0 : current;
    final end = _expanded
        ? ranks.length - 1
        : (current + _collapsedAhead).clamp(0, ranks.length - 1);
    final hidden = ranks.length - 1 - end;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('my_title_ladder'.tr().toUpperCase(),
            style: AppTypography.overline(c.text3)),
        const SizedBox(height: 9),
        for (var i = start; i <= end; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Row(
              children: [
                _LadderDot(state: i <= current
                    ? _DotState.reached
                    : i == current + 1
                        ? _DotState.next
                        : _DotState.locked),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    ranks[i].$2.tr(),
                    style: text.labelMedium?.copyWith(
                      fontSize: 12,
                      fontWeight:
                          i <= current + 1 ? FontWeight.w700 : FontWeight.w600,
                      color: i <= current
                          ? c.text1
                          : i == current + 1
                              ? c.text2
                              : c.text3,
                    ),
                  ),
                ),
                Text(
                  numbers.format(ranks[i].$1),
                  style: text.labelSmall?.copyWith(
                    letterSpacing: 0,
                    fontSize: 10.5,
                    color: i == current + 1
                        ? c.accentText
                        : i <= current
                            ? c.text2
                            : c.text3,
                  ),
                ),
              ],
            ),
          ),
        if (hidden > 0 || _expanded)
          InkWell(
            borderRadius: BorderRadius.circular(AppRadius.chip),
            onTap: () => setState(() => _expanded = !_expanded),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: AppSpacing.minTouch),
              child: Row(
                children: [
                  SizedBox(
                    width: 22,
                    child: Icon(
                      _expanded
                          ? Icons.expand_less_rounded
                          : Icons.more_vert_rounded,
                      size: 16,
                      color: c.text3,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _expanded
                        ? 'my_title_ladder_less'.tr()
                        : 'my_title_ladder_more'.tr(namedArgs: {
                            'count': '$hidden',
                            'name': ranks.last.$2.tr(),
                          }),
                    style: text.labelMedium
                        ?.copyWith(color: c.accentText, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

enum _DotState { reached, next, locked }

class _LadderDot extends StatelessWidget {
  const _LadderDot({required this.state});

  final _DotState state;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return switch (state) {
      _DotState.reached => Container(
          width: 22,
          height: 22,
          decoration:
              BoxDecoration(gradient: c.accentGradient, shape: BoxShape.circle),
          child: const Icon(Icons.check_rounded, size: 13, color: Colors.white),
        ),
      _DotState.next => Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
                color: c.accentText.withValues(alpha: 0.6), width: 1.5),
          ),
        ),
      _DotState.locked => Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(color: c.surface2, shape: BoxShape.circle),
        ),
    };
  }
}
