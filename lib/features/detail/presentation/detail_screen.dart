import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nextarc/features/auth/domain/auth_providers.dart';
import 'package:nextarc/features/detail/domain/detail_providers.dart';
import 'package:nextarc/features/discover/domain/media_model.dart';
import 'package:nextarc/features/watchlist/presentation/watchlist_edit_sheet.dart';

/// Écran fiche détaillée d'un anime.
class DetailScreen extends ConsumerWidget {
  const DetailScreen({
    super.key,
    required this.animeId,
    this.heroTag,
    this.coverUrl,
  });

  final int animeId;

  /// Tag Hero transmis par l'écran source pour l'animation de jaquette.
  final String? heroTag;

  /// URL de la jaquette passée depuis l'écran source (permet le Hero pendant le loading).
  final String? coverUrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncAnime = ref.watch(animeDetailProvider(animeId));

    return asyncAnime.when(
      loading: () => _LoadingSkeleton(heroTag: heroTag, coverUrl: coverUrl),
      error: (error, _) => Scaffold(
        appBar: AppBar(),
        body: Builder(
          builder: (context) {
            final cs = Theme.of(context).colorScheme;
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline,
                      size: 48, color: cs.onSurface.withValues(alpha: 0.38)),
                  const SizedBox(height: 12),
                  Text(error.toString(),
                      style: TextStyle(
                          color: cs.onSurface.withValues(alpha: 0.54))),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text('Réessayer'),
                    onPressed: () =>
                        ref.invalidate(animeDetailProvider(animeId)),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      data: (anime) => _DetailContent(anime: anime, heroTag: heroTag, coverUrl: coverUrl),
    );
  }
}

// ── Skeleton de chargement ────────────────────────────────────────────────────

class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton({this.heroTag, this.coverUrl});
  final String? heroTag;
  final String? coverUrl;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Bannière — même structure que l'écran final, SANS Hero
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: coverUrl != null
                  ? CachedNetworkImage(
                      imageUrl: coverUrl!,
                      fit: BoxFit.cover,
                    )
                  : Container(color: cs.surfaceContainerHighest),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Petite jaquette AVEC Hero — même position que l'écran final
                  if (heroTag != null && coverUrl != null)
                    Hero(
                      tag: heroTag!,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 100,
                          height: 150,
                          child: CachedNetworkImage(
                            imageUrl: coverUrl!,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    )
                  else
                    Container(
                      width: 100,
                      height: 150,
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Contenu détail avec FAB ───────────────────────────────────────────────────

class _DetailContent extends ConsumerStatefulWidget {
  const _DetailContent({required this.anime, this.heroTag, this.coverUrl});
  final MediaModel anime;
  final String? heroTag;
  final String? coverUrl;

  @override
  ConsumerState<_DetailContent> createState() => _DetailContentState();
}

class _DetailContentState extends ConsumerState<_DetailContent> {
  final _scrollController = ScrollController();
  bool _fabVisible = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final max = _scrollController.position.maxScrollExtent;
    // Cache le FAB quand on est à moins de 160px du bas (bouton plein visible)
    final nearBottom = _scrollController.offset >= max - 160;
    if (nearBottom == _fabVisible) {
      setState(() => _fabVisible = !nearBottom);
    }
  }

  void _openSheet({required bool isLoggedIn}) {
    if (!isLoggedIn) {
      final cs = Theme.of(context).colorScheme;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Connecte-toi pour gérer ta watchlist',
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
            backgroundColor: cs.surfaceContainerHighest,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
      return;
    }
    final entry = ref.read(userListEntryProvider(widget.anime.id));
    showWatchlistEditSheet(
      context, ref,
      animeId: widget.anime.id,
      animeTitle: widget.anime.displayTitle,
      totalEpisodes: widget.anime.episodes,
      startDate: widget.anime.startDate,
      existing: entry,
    );
  }

  @override
  Widget build(BuildContext context) {
    final anime = widget.anime;
    final userEntry = ref.watch(userListEntryProvider(anime.id));
    final isLoggedIn = ref.watch(authProvider).whenOrNull(
              data: (a) => a.isAuthenticated,
            ) ??
        false;

    final cs = Theme.of(context).colorScheme;
    final fabInactiveBg = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF1E2A3A)
        : const Color(0xFFDDE8F5);

    return Scaffold(
      // ── FAB flottant (icône seule) ────────────────────────────────────
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      floatingActionButton: AnimatedScale(
        scale: _fabVisible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        child: AnimatedOpacity(
          opacity: _fabVisible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: FloatingActionButton.small(
            heroTag: 'watchlist_fab_${anime.id}',
            backgroundColor: userEntry != null ? cs.primary : fabInactiveBg,
            onPressed: () => _openSheet(isLoggedIn: isLoggedIn),
            child: Icon(
              userEntry != null
                  ? Icons.bookmark
                  : Icons.bookmark_add_outlined,
              color: userEntry != null ? Colors.white : cs.primary,
              size: 20,
            ),
          ),
        ),
      ),

      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // ── AppBar avec bannière / jaquette ────────────────────────────
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (anime.coverImage != null)
                    CachedNetworkImage(
                      imageUrl: anime.coverImage!,
                      fit: BoxFit.cover,
                    ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Theme.of(context).scaffoldBackgroundColor,
                        ],
                        stops: const [0.5, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Jaquette + infos côte à côte ──────────────────────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildJacket(anime, cs),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              anime.displayTitle,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                height: 1.3,
                              ),
                            ),
                            if (anime.titleEnglish != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                anime.titleRomaji,
                                style: TextStyle(
                                    color: cs.onSurface.withValues(alpha: 0.54),
                                    fontSize: 13),
                              ),
                            ],
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                if (anime.formattedScore != null)
                                  _InfoChip(
                                    icon: Icons.star_rounded,
                                    label: anime.formattedScore!,
                                    color: const Color(0xFFFFC107),
                                  ),
                                if (anime.episodes != null)
                                  _InfoChip(
                                    icon: Icons.play_circle_outline,
                                    label: '${anime.episodes} ép.',
                                  ),
                                if (anime.status != null)
                                  _InfoChip(
                                    icon: Icons.circle,
                                    label: _statusLabel(anime.status!),
                                    color: _statusColor(anime.status!),
                                  ),
                                if (anime.seasonYear != null)
                                  _InfoChip(
                                    icon: Icons.calendar_today_outlined,
                                    label: '${anime.seasonYear}',
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // ── Genres ────────────────────────────────────────────
                  if (anime.genres != null && anime.genres!.isNotEmpty) ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: anime.genres!
                          .map((g) => _GenreChip(genre: g))
                          .toList(),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ── Synopsis ──────────────────────────────────────────
                  if (anime.description != null &&
                      anime.description!.isNotEmpty) ...[
                    const Text(
                      'Synopsis',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      anime.description!
                          .replaceAll(RegExp(r'<[^>]*>'), '')
                          .replaceAll('&amp;', '&')
                          .replaceAll('&lt;', '<')
                          .replaceAll('&gt;', '>')
                          .replaceAll('&#039;', "'")
                          .replaceAll('&quot;', '"')
                          .trim(),
                      style: TextStyle(
                          color: cs.onSurface.withValues(alpha: 0.7),
                          height: 1.6,
                          fontSize: 14),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // ── Bouton watchlist (en bas du scroll) ───────────────
                  if (userEntry != null) ...[
                    // Déjà dans la liste → badge cliquable
                    GestureDetector(
                      onTap: () => _openSheet(isLoggedIn: isLoggedIn),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: cs.primaryContainer,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: cs.primary.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.bookmark,
                                color: cs.onPrimaryContainer, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    userEntry.status?.label ?? 'Dans ta liste',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: cs.onPrimaryContainer),
                                  ),
                                  Text(
                                    userEntry.progressLabel +
                                        (userEntry.formattedScore != null
                                            ? '  •  ⭐ ${userEntry.formattedScore}'
                                            : ''),
                                    style: TextStyle(
                                        color: cs.onSurface
                                            .withValues(alpha: 0.54),
                                        fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.edit_outlined,
                                size: 16,
                                color: cs.onPrimaryContainer
                                    .withValues(alpha: 0.6)),
                          ],
                        ),
                      ),
                    ),
                  ] else ...[
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        icon: const Icon(Icons.bookmark_add_outlined),
                        label: const Text('Ajouter à ma watchlist'),
                        onPressed: () => _openSheet(isLoggedIn: isLoggedIn),
                      ),
                    ),
                  ],

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJacket(MediaModel anime, ColorScheme cs) {
    final jacket = ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 100,
        height: 150,
        child: anime.coverImage != null
            ? CachedNetworkImage(imageUrl: anime.coverImage!, fit: BoxFit.cover)
            : Container(color: cs.surfaceContainerHighest),
      ),
    );
    final tag = widget.heroTag;
    return tag != null ? Hero(tag: tag, child: jacket) : jacket;
  }

  String _statusLabel(String status) => switch (status) {
        'FINISHED' => 'Terminé',
        'RELEASING' => 'En cours',
        'NOT_YET_RELEASED' => 'À venir',
        'CANCELLED' => 'Annulé',
        'HIATUS' => 'En pause',
        _ => status,
      };

  Color _statusColor(String status) => switch (status) {
        'FINISHED' => Colors.blue,
        'RELEASING' => Colors.green,
        'NOT_YET_RELEASED' => Colors.orange,
        'CANCELLED' => Colors.red,
        'HIATUS' => Colors.purple,
        _ => Colors.white54,
      };
}

// ── Widgets utilitaires ────────────────────────────────────────────────────────

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label, this.color});
  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final fallback =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color ?? fallback),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, color: color ?? fallback)),
      ],
    );
  }
}

class _GenreChip extends StatelessWidget {
  const _GenreChip({required this.genre});
  final String genre;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(genre,
          style: TextStyle(
              fontSize: 12, color: cs.onSurface.withValues(alpha: 0.7))),
    );
  }
}
