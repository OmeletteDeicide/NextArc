import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nextarc/core/router/app_router.dart';
import 'package:nextarc/core/theme/app_tokens.dart';
import 'package:nextarc/core/theme/app_typography.dart';
import 'package:nextarc/core/theme/zigzag_background.dart';
import 'package:nextarc/core/widgets/ds/ds.dart';
import 'package:nextarc/features/activity/domain/activity_providers.dart';
import 'package:nextarc/features/activity/domain/month_activity.dart';
import 'package:nextarc/features/auth/domain/auth_providers.dart';
import 'package:nextarc/features/stats/domain/month_story.dart';
import 'package:nextarc/features/stats/domain/stats_model.dart';
import 'package:nextarc/features/stats/domain/stats_provider.dart';
import 'package:nextarc/features/stats/domain/user_title.dart';
import 'package:nextarc/features/stats/presentation/user_title_badge.dart';
import 'package:nextarc/features/watchlist/domain/media_list_entry.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(statsProvider);
    final usesAnilistList = ref
            .watch(authProvider)
            .whenOrNull(data: (a) => a.user?.usesAnilistList) ??
        false;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _StatsHeader(),
            Expanded(
              child: statsAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => _StatsError(
                  message: e.toString(),
                  onRetry: () => ref.invalidate(statsProvider),
                ),
                // Le journal mensuel n'existe pas pour un compte AniList seul
                data: (stats) =>
                    _StatsBody(stats: stats, showMonth: !usesAnilistList),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── En-tête ───────────────────────────────────────────────────────────────────

class _StatsHeader extends StatelessWidget {
  const _StatsHeader();

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.screen - 4, AppSpacing.xs, AppSpacing.screen, 0),
      child: Row(
        children: [
          Tooltip(
            message: MaterialLocalizations.of(context).backButtonTooltip,
            child: InkResponse(
              radius: 24,
              onTap: () =>
                  context.canPop() ? context.pop() : context.go('/profile'),
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
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'stats_title'.tr(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.headlineSmall?.copyWith(fontSize: 19, color: c.text1),
            ),
          ),
          Material(
            type: MaterialType.transparency,
            child: Ink(
              decoration: BoxDecoration(
                gradient: c.accentGradient,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.full),
                onTap: () => context.push(AppRoutes.shareStats),
                child: ConstrainedBox(
                  constraints:
                      const BoxConstraints(minHeight: AppSpacing.minTouch - 8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 9),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.ios_share_rounded,
                            size: 14, color: Colors.white),
                        const SizedBox(width: 6),
                        Text(
                          'share_stats_button'.tr(),
                          style: text.labelMedium
                              ?.copyWith(color: Colors.white, fontSize: 11.5),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Corps ─────────────────────────────────────────────────────────────────────

class _StatsBody extends StatefulWidget {
  const _StatsBody({required this.stats, required this.showMonth});

  final StatsModel stats;
  final bool showMonth;

  @override
  State<_StatsBody> createState() => _StatsBodyState();
}

class _StatsBodyState extends State<_StatsBody> {
  bool _showDetails = false;

  @override
  Widget build(BuildContext context) {
    final stats = widget.stats;
    final c = AppColors.of(context);
    final locale = context.locale.toString();
    final numbers = NumberFormat.decimalPattern(locale);
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    String score(double value) {
      final raw = value.toStringAsFixed(1);
      return context.locale.languageCode == 'en'
          ? raw
          : raw.replaceAll('.', ',');
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.md,
          AppSpacing.screen, AppSpacing.xl + bottomInset),
      children: [
        if (widget.showMonth) ...[
          const _MonthStoryCard(),
          const SizedBox(height: 18),
        ],

        // ── Tuiles (cumul total) ──────────────────────────────────────────
        _TileGrid(
          children: [
            StatTile(
              value: numbers.format(stats.episodesWatched),
              label: 'stats_episodes_watched'.tr(),
            ),
            StatTile(
              value: stats.meanScore == null ? '—' : score(stats.meanScore!),
              label: 'stats_tile_mean_score'.tr(),
              valueColor: c.star,
            ),
            StatTile(
              value: numbers.format(stats.animeCompleted),
              label: 'stats_anime_completed'.tr(),
            ),
            _DetailsToggleTile(
              expanded: _showDetails,
              onTap: () => setState(() => _showDetails = !_showDetails),
            ),
          ],
        ),

        // ── Détail dépliable ──────────────────────────────────────────────
        AnimatedSize(
          duration: AppMotion.transition,
          alignment: Alignment.topCenter,
          child: _showDetails
              ? Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: _StatsDetails(stats: stats),
                )
              : const SizedBox(width: double.infinity),
        ),

        // ── Genres favoris ────────────────────────────────────────────────
        if (stats.topGenres.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          SectionHeader(title: 'stats_section_genres'.tr()),
          const SizedBox(height: AppSpacing.sm),
          for (var i = 0; i < stats.topGenres.length; i++) ...[
            if (i > 0) const SizedBox(height: 11),
            _GenreBar(stat: stats.topGenres[i], rank: i),
          ],
        ],

        // ── Titre ─────────────────────────────────────────────────────────
        const SizedBox(height: AppSpacing.lg),
        SectionHeader(title: 'title_section'.tr()),
        const SizedBox(height: AppSpacing.sm),
        _TitleCard(title: stats.title),
      ],
    );
  }
}

class _TileGrid extends StatelessWidget {
  const _TileGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var row = 0; row < children.length; row += 2) ...[
          if (row > 0) const SizedBox(height: AppSpacing.sm),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: children[row]),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: row + 1 < children.length
                      ? children[row + 1]
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _DetailsToggleTile extends StatelessWidget {
  const _DetailsToggleTile({required this.expanded, required this.onTap});

  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    return Material(
      color: c.surface1,
      borderRadius: BorderRadius.circular(AppRadius.card),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      expanded
                          ? 'stats_hide_details'.tr()
                          : 'stats_see_details'.tr(),
                      style: text.labelLarge
                          ?.copyWith(color: c.accentText, fontSize: 12),
                    ),
                  ),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: AppMotion.transition,
                    child: Icon(Icons.expand_more_rounded,
                        size: 18, color: c.accentText),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                'stats_details_hint'.tr(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: text.bodySmall?.copyWith(color: c.text2, fontSize: 10.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatsDetails extends StatelessWidget {
  const _StatsDetails({required this.stats});

  final StatsModel stats;

  @override
  Widget build(BuildContext context) {
    final numbers = NumberFormat.decimalPattern(context.locale.toString());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TileGrid(
          children: [
            StatTile(
              value: numbers.format(stats.animeWatched),
              label: 'stats_anime_watched'.tr(),
            ),
            StatTile(
              value: stats.watchTimeFormatted,
              label: 'stats_watch_time'.tr(),
            ),
            StatTile(
              value: numbers.format(stats.mangaRead),
              label: 'stats_manga_read'.tr(),
            ),
            StatTile(
              value: numbers.format(stats.mangaCompleted),
              label: 'stats_manga_completed'.tr(),
            ),
            StatTile(
              value: numbers.format(stats.chaptersRead),
              label: 'stats_chapters_read'.tr(),
            ),
            StatTile(
              value: stats.readTimeFormatted,
              label: 'stats_read_time'.tr(),
            ),
          ],
        ),
        if (stats.bestAnime != null || stats.bestManga != null) ...[
          const SizedBox(height: AppSpacing.md),
          SectionHeader(title: 'stats_section_best'.tr()),
          const SizedBox(height: AppSpacing.xs),
          if (stats.bestAnime != null)
            _BestMediaRow(
                entry: stats.bestAnime!, label: 'stats_best_anime'.tr()),
          if (stats.bestAnime != null && stats.bestManga != null)
            const SizedBox(height: AppSpacing.xs),
          if (stats.bestManga != null)
            _BestMediaRow(
                entry: stats.bestManga!, label: 'stats_best_manga'.tr()),
        ],
      ],
    );
  }
}

// ── Récap narratif « Ton mois » ───────────────────────────────────────────────

class _MonthStoryCard extends ConsumerWidget {
  const _MonthStoryCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final locale = context.locale.toString();

    final months = lastMonths(DateTime.now());
    // Erreur (hors ligne, règles non publiées…) : mois vide plutôt qu'un
    // chargement infini
    final recaps = [
      for (final m in months)
        ref.watch(monthlyRecapProvider(monthKey(m))).value ??
            MonthlyRecap.fromItems(monthKey(m), const []),
    ];
    final isLoading =
        ref.watch(monthlyRecapProvider(monthKey(months.last))).isLoading &&
            !ref.watch(monthlyRecapProvider(monthKey(months.last))).hasValue;

    int minutesOf(MonthlyRecap r) => r.watchTimeMinutes + r.readTimeMinutes;
    final current = recaps.last;
    final previous = recaps[recaps.length - 2];
    final monthName = DateFormat.MMMM(locale).format(months.last);

    final bodyStyle =
        text.bodyMedium?.copyWith(color: c.text2, fontSize: 12.5, height: 1.5);
    final strong = bodyStyle?.copyWith(
        color: c.text1, fontWeight: FontWeight.w700);

    return Container(
      decoration: BoxDecoration(
        color: c.surface1,
        borderRadius: BorderRadius.circular(AppRadius.sheet),
        border: isDark ? Border.all(color: c.border) : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: ZigzagBackground(
        color: c.accent,
        opacity: 0.3,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'stats_story_overline'
                    .tr(namedArgs: {'month': monthName})
                    .toUpperCase(),
                style: AppTypography.overline(c.text3),
              ),
              const SizedBox(height: 6),
              if (isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else if (current.isEmpty)
                Text('stats_month_empty'.tr(), style: bodyStyle)
              else ...[
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    heroDuration(minutesOf(current)),
                    maxLines: 1,
                    style: text.displayLarge?.copyWith(
                      fontSize: 44,
                      height: 0.95,
                      color: c.text1,
                      letterSpacing: -1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text.rich(
                  TextSpan(
                    style: bodyStyle,
                    children: _storySpans(
                      current: current,
                      previous: previous,
                      previousMonthName:
                          DateFormat.MMMM(locale).format(months[months.length - 2]),
                      strong: strong,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              _MonthBars(
                months: months,
                minutes: [for (final r in recaps) minutesOf(r)],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// « 24 épisodes, surtout des **Drama**. Soit **+38 %** par rapport à août. »
  List<InlineSpan> _storySpans({
    required MonthlyRecap current,
    required MonthlyRecap previous,
    required String previousMonthName,
    required TextStyle? strong,
  }) {
    String count(String key, int n) => n == 1
        ? '${key}_one'.tr()
        : key.tr(namedArgs: {'count': '$n'});

    final spans = <InlineSpan>[];
    final parts = [
      if (current.episodesWatched > 0)
        count('stats_story_episodes', current.episodesWatched),
      if (current.chaptersRead > 0)
        count('stats_story_chapters', current.chaptersRead),
    ];
    if (parts.isNotEmpty) {
      spans.add(TextSpan(text: parts.join('stats_story_and'.tr())));
      if (current.topGenres.isNotEmpty) {
        spans
          ..add(TextSpan(text: 'stats_story_genre'.tr()))
          ..add(TextSpan(text: current.topGenres.first.name, style: strong));
      }
      spans.add(const TextSpan(text: '. '));
    }

    final comparison = compareMonths(
      currentMinutes: current.watchTimeMinutes + current.readTimeMinutes,
      previousMinutes: previous.watchTimeMinutes + previous.readTimeMinutes,
    );
    final month = {'month': previousMonthName};
    switch (comparison.trend) {
      case MonthTrend.hidden:
        break;
      case MonthTrend.percent:
        spans
          ..add(TextSpan(text: 'stats_story_compare_prefix'.tr()))
          ..add(TextSpan(
            text: 'stats_story_percent'.tr(
                namedArgs: {'value': signedPercent(comparison.percent)}),
            style: strong,
          ))
          ..add(TextSpan(
              text: 'stats_story_compare_suffix'.tr(namedArgs: month)));
      case MonthTrend.same:
        spans.add(TextSpan(text: 'stats_story_same'.tr(namedArgs: month)));
      case MonthTrend.calmer:
        spans.add(TextSpan(text: 'stats_story_calmer'.tr(namedArgs: month)));
    }
    return spans;
  }
}

class _MonthBars extends StatelessWidget {
  const _MonthBars({required this.months, required this.minutes});

  final List<DateTime> months;
  final List<int> minutes;

  static const double _height = 56;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final locale = context.locale.toString();
    final ratios = barRatios(minutes);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final idle = isDark ? const Color(0xFF1E2A50) : c.surface2;

    return Semantics(
      label: [
        for (var i = 0; i < months.length; i++)
          '${DateFormat.MMMM(locale).format(months[i])} ${heroDuration(minutes[i]).toLowerCase()}',
      ].join(', '),
      child: ExcludeSemantics(
        child: Column(
          children: [
            SizedBox(
              height: _height,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < months.length; i++) ...[
                    if (i > 0) const SizedBox(width: 5),
                    Expanded(
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(end: ratios[i]),
                        duration: AppMotion.progress,
                        curve: Curves.easeOutCubic,
                        builder: (context, ratio, _) => Container(
                          // Un mois vide garde un trait visible
                          height: (_height * ratio).clamp(3, _height),
                          decoration: BoxDecoration(
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4)),
                            color: i == months.length - 1 ? null : idle,
                            gradient: i == months.length - 1
                                ? LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [c.violet, c.accent],
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 5),
            Row(
              children: [
                for (var i = 0; i < months.length; i++) ...[
                  if (i > 0) const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      DateFormat.MMM(locale)
                          .format(months[i])
                          .replaceAll('.', '')
                          .toUpperCase(),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      style: AppTypography.overline(c.text3)
                          .copyWith(fontSize: 9, letterSpacing: 0),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Genres ────────────────────────────────────────────────────────────────────

class _GenreBar extends StatelessWidget {
  const _GenreBar({required this.stat, required this.rank});

  final GenreStat stat;
  final int rank;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final style = Theme.of(context)
        .textTheme
        .labelMedium
        ?.copyWith(fontSize: 11.5, color: c.text1);
    // Les genres suivants s'estompent légèrement
    final fade = (1 - rank * 0.15).clamp(0.4, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(stat.name, style: style)),
            Text(
              'stats_story_percent'
                  .tr(namedArgs: {'value': '${(stat.ratio * 100).round()}'}),
              style: style?.copyWith(color: c.text2),
            ),
          ],
        ),
        const SizedBox(height: 5),
        GradientProgressBar(
          value: stat.ratio,
          colors: [
            c.accent.withValues(alpha: fade),
            c.violet.withValues(alpha: fade),
          ],
        ),
      ],
    );
  }
}

// ── Titre ─────────────────────────────────────────────────────────────────────

class _TitleCard extends StatelessWidget {
  const _TitleCard({required this.title});

  final UserTitle title;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final hintStyle = Theme.of(context)
        .textTheme
        .bodySmall
        ?.copyWith(color: c.text2, fontSize: 12);
    final nextRank = title.nextRank;
    final hoursToNext = title.hoursToNextQualifier;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: c.surface1,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: title.isArcer ? c.star.withValues(alpha: 0.35) : c.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UserTitleBadge(title: title, fontSize: 16),
          const SizedBox(height: AppSpacing.sm),
          if (title.isArcer)
            Text('title_arcer_reached'.tr(), style: hintStyle)
          else ...[
            if (nextRank != null)
              Text(
                'title_next_rank'.tr(namedArgs: {
                  'count': '${nextRank.$1}',
                  'title': nextRank.$2.tr(),
                }),
                style: hintStyle,
              ),
            if (hoursToNext != null) ...[
              const SizedBox(height: 2),
              Text(
                'title_next_qualifier'
                    .tr(namedArgs: {'hours': '$hoursToNext'}),
                style: hintStyle,
              ),
            ],
          ],
        ],
      ),
    );
  }
}

// ── Meilleures notes ──────────────────────────────────────────────────────────

class _BestMediaRow extends StatelessWidget {
  const _BestMediaRow({required this.entry, required this.label});

  final MediaListEntry entry;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    return Material(
      color: c.surface1,
      borderRadius: BorderRadius.circular(AppRadius.card),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/detail/${entry.media.id}'),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              SizedBox(
                width: 44,
                child: MediaCover(imageUrl: entry.media.coverImage, radius: 8),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label.toUpperCase(),
                        style: AppTypography.overline(c.accentText)),
                    const SizedBox(height: 3),
                    Text(
                      entry.media.displayTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleSmall?.copyWith(color: c.text1),
                    ),
                  ],
                ),
              ),
              if (entry.formattedScore != null) ...[
                const SizedBox(width: AppSpacing.xs),
                Icon(Icons.star_rounded, size: 16, color: c.star),
                const SizedBox(width: 2),
                Text(
                  context.locale.languageCode == 'en'
                      ? entry.formattedScore!
                      : entry.formattedScore!.replaceAll('.', ','),
                  style: text.labelLarge?.copyWith(color: c.star),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Erreur ────────────────────────────────────────────────────────────────────

class _StatsError extends StatelessWidget {
  const _StatsError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 44, color: c.text3),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: c.text2),
            ),
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: 'action_retry'.tr(),
              icon: Icons.refresh_rounded,
              variant: AppButtonVariant.secondary,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}
