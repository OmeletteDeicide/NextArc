import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nextarc/core/router/app_router.dart';
import 'package:nextarc/features/activity/domain/activity_providers.dart';
import 'package:nextarc/features/activity/domain/month_activity.dart';
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

    return Scaffold(
      appBar: AppBar(
        title: Text('stats_title'.tr()),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share_rounded),
            tooltip: 'share_stats_button'.tr(),
            onPressed: () => context.push(AppRoutes.shareStats),
          ),
        ],
      ),
      body: statsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 12),
              Text(e.toString()),
              const SizedBox(height: 16),
              FilledButton.icon(
                icon: const Icon(Icons.refresh),
                label: Text('action_retry'.tr()),
                onPressed: () => ref.invalidate(statsProvider),
              ),
            ],
          ),
        ),
        data: (stats) => _StatsBody(stats: stats),
      ),
    );
  }
}

class _StatsBody extends StatelessWidget {
  const _StatsBody({required this.stats});
  final StatsModel stats;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      children: [
        // ── Titre ──────────────────────────────────────────────────────────
        _SectionHeader(label: 'title_section'.tr()),
        const SizedBox(height: 12),
        _TitleCard(title: stats.title),

        const SizedBox(height: 28),

        // ── Ce mois-ci (journal d'activité) ────────────────────────────────
        _SectionHeader(label: 'stats_month_section'.tr()),
        const SizedBox(height: 12),
        const _CurrentMonthCard(),

        const SizedBox(height: 28),

        // ── Section Anime ──────────────────────────────────────────────────
        _SectionHeader(label: 'stats_section_anime'.tr()),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _BigStatCard(
                value: stats.animeWatched.toString(),
                label: 'stats_anime_watched'.tr(),
                icon: Icons.play_circle_outline,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _BigStatCard(
                value: stats.animeCompleted.toString(),
                label: 'stats_anime_completed'.tr(),
                icon: Icons.check_circle_outline,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _BigStatCard(
                value: stats.episodesWatched.toString(),
                label: 'stats_episodes_watched'.tr(),
                icon: Icons.live_tv_outlined,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _BigStatCard(
                value: stats.watchTimeFormatted,
                label: 'stats_watch_time'.tr(),
                icon: Icons.schedule_outlined,
                accent: true,
              ),
            ),
          ],
        ),

        const SizedBox(height: 28),

        // ── Section Manga ──────────────────────────────────────────────────
        _SectionHeader(label: 'stats_section_manga'.tr()),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _BigStatCard(
                value: stats.mangaRead.toString(),
                label: 'stats_manga_read'.tr(),
                icon: Icons.menu_book_outlined,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _BigStatCard(
                value: stats.mangaCompleted.toString(),
                label: 'stats_manga_completed'.tr(),
                icon: Icons.check_circle_outline,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _BigStatCard(
                value: stats.chaptersRead.toString(),
                label: 'stats_chapters_read'.tr(),
                icon: Icons.bookmark_outline,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _BigStatCard(
                value: stats.readTimeFormatted,
                label: 'stats_read_time'.tr(),
                icon: Icons.auto_stories_outlined,
                accent: true,
              ),
            ),
          ],
        ),

        const SizedBox(height: 28),

        // ── Score moyen ────────────────────────────────────────────────────
        if (stats.meanScore != null) ...[
          _SectionHeader(label: 'stats_section_scores'.tr()),
          const SizedBox(height: 12),
          _ScoreCard(
            score: stats.meanScore!,
            bestAnime: stats.bestAnime,
            bestManga: stats.bestManga,
          ),
          const SizedBox(height: 28),
        ],

        // ── Genres favoris ─────────────────────────────────────────────────
        if (stats.topGenres.isNotEmpty) ...[
          _SectionHeader(label: 'stats_section_genres'.tr()),
          const SizedBox(height: 12),
          _GenreChart(genres: stats.topGenres),
          const SizedBox(height: 28),
        ],

        // ── Meilleures notes ───────────────────────────────────────────────
        if (stats.bestAnime != null || stats.bestManga != null) ...[
          _SectionHeader(label: 'stats_section_best'.tr()),
          const SizedBox(height: 12),
          if (stats.bestAnime != null) ...[
            _BestMediaCard(
              entry: stats.bestAnime!,
              label: 'stats_best_anime'.tr(),
            ),
            const SizedBox(height: 8),
          ],
          if (stats.bestManga != null)
            _BestMediaCard(
              entry: stats.bestManga!,
              label: 'stats_best_manga'.tr(),
            ),
          const SizedBox(height: 20),
        ],
      ],
    );
  }
}

// ── Récap du mois en cours ────────────────────────────────────────────────────

class _CurrentMonthCard extends ConsumerWidget {
  const _CurrentMonthCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final recap = ref
        .watch(monthlyRecapProvider(monthKey(DateTime.now())))
        .whenOrNull(data: (r) => r);

    if (recap == null) {
      return const SizedBox(
        height: 48,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (recap.isEmpty) {
      return Text(
        'stats_month_empty'.tr(),
        style: TextStyle(
            fontSize: 13, color: cs.onSurface.withValues(alpha: 0.54)),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _BigStatCard(
                value: '${recap.episodesWatched}',
                label: 'stats_episodes_watched'.tr(),
                icon: Icons.live_tv_outlined,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _BigStatCard(
                value: recap.watchTimeFormatted,
                label: 'stats_watch_time'.tr(),
                icon: Icons.schedule_outlined,
                accent: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _BigStatCard(
                value: '${recap.completed}',
                label: 'stats_month_completed'.tr(),
                icon: Icons.check_circle_outline,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _BigStatCard(
                value: '${recap.chaptersRead}',
                label: 'stats_chapters_read'.tr(),
                icon: Icons.bookmark_outline,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Carte titre ───────────────────────────────────────────────────────────────

class _TitleCard extends StatelessWidget {
  const _TitleCard({required this.title});
  final UserTitle title;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hintStyle =
        TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.6));
    final nextRank = title.nextRank;
    final hoursToNext = title.hoursToNextQualifier;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UserTitleBadge(title: title, fontSize: 18),
          const SizedBox(height: 12),
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
            if (hoursToNext != null)
              Text(
                'title_next_qualifier'.tr(namedArgs: {'hours': '$hoursToNext'}),
                style: hintStyle,
              ),
            const SizedBox(height: 4),
            Text(
              'title_arcer_progress'.tr(namedArgs: {
                'completed': '${title.totalCompleted}',
                'maxCompleted': '${UserTitle.arcerMinCompleted}',
                'hours': '${title.totalHours}',
                'maxHours': '${UserTitle.arcerMinHours}',
              }),
              style: hintStyle.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.4)),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.4,
        color: cs.onSurface.withValues(alpha: 0.45),
      ),
    );
  }
}

// ── Grande carte stat ─────────────────────────────────────────────────────────

class _BigStatCard extends StatelessWidget {
  const _BigStatCard({
    required this.value,
    required this.label,
    required this.icon,
    this.accent = false,
  });

  final String value;
  final String label;
  final IconData icon;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final cardBg = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF161C26)
        : cs.surfaceContainerLowest;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accent ? cs.primary.withValues(alpha: 0.12) : cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accent
              ? cs.primary.withValues(alpha: 0.4)
              : cs.outline.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: [
          Icon(icon,
              size: 20,
              color: accent ? cs.primary : cs.onSurface.withValues(alpha: 0.5)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Réduit la taille plutôt que de passer à la ligne
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: accent ? cs.primary : cs.onSurface,
                    ),
                    maxLines: 1,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: cs.onSurface.withValues(alpha: 0.54),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Carte score moyen ─────────────────────────────────────────────────────────

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({
    required this.score,
    this.bestAnime,
    this.bestManga,
  });

  final double score;
  final MediaListEntry? bestAnime;
  final MediaListEntry? bestManga;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final cardBg = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF161C26)
        : cs.surfaceContainerLowest;

    final scoreStr = score % 1 == 0
        ? score.toInt().toString()
        : score.toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          // Score circulaire
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                  color: const Color(0xFFFFC107).withValues(alpha: 0.6),
                  width: 2.5),
              color: const Color(0xFFFFC107).withValues(alpha: 0.08),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.star_rounded,
                    color: Color(0xFFFFC107), size: 16),
                Text(
                  scoreStr,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFFC107),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'stats_mean_score_label'.tr(),
              style: TextStyle(
                fontSize: 13,
                color: cs.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Graphique genres ──────────────────────────────────────────────────────────

class _GenreChart extends StatelessWidget {
  const _GenreChart({required this.genres});
  final List<GenreStat> genres;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final cardBg = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF161C26)
        : cs.surfaceContainerLowest;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: genres
            .map((g) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _GenreBar(stat: g),
                ))
            .toList(),
      ),
    );
  }
}

class _GenreBar extends StatelessWidget {
  const _GenreBar({required this.stat});
  final GenreStat stat;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(stat.name,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500)),
            ),
            Text(
              '${(stat.ratio * 100).round()}%',
              style: TextStyle(
                  fontSize: 11,
                  color: cs.onSurface.withValues(alpha: 0.45)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: stat.ratio,
            minHeight: 6,
            backgroundColor: cs.onSurface.withValues(alpha: 0.08),
            valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
          ),
        ),
      ],
    );
  }
}

// ── Carte meilleure note ──────────────────────────────────────────────────────

class _BestMediaCard extends StatelessWidget {
  const _BestMediaCard({required this.entry, required this.label});
  final MediaListEntry entry;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final cardBg = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF161C26)
        : cs.surfaceContainerLowest;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          // Jaquette
          ClipRRect(
            borderRadius:
                const BorderRadius.horizontal(left: Radius.circular(16)),
            child: SizedBox(
              width: 60,
              height: 80,
              child: entry.media.coverImage != null
                  ? CachedNetworkImage(
                      imageUrl: entry.media.coverImage!,
                      fit: BoxFit.cover,
                    )
                  : Container(color: cs.surfaceContainerHighest),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: cs.primary,
                      letterSpacing: 0.8),
                ),
                const SizedBox(height: 2),
                Text(
                  entry.media.displayTitle,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Column(
              children: [
                const Icon(Icons.star_rounded,
                    color: Color(0xFFFFC107), size: 18),
                Text(
                  entry.formattedScore ?? '',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFFC107),
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
