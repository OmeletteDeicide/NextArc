import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nextarc/features/auth/domain/auth_providers.dart';
import 'package:nextarc/features/detail/domain/detail_providers.dart';
import 'package:nextarc/features/discover/domain/media_model.dart';
import 'package:nextarc/features/recommendations/domain/reco_providers.dart';
import 'package:nextarc/features/recommendations/domain/recommendation_model.dart';
import 'package:nextarc/features/watchlist/presentation/watchlist_sheet_helper.dart';

class RecommendationsScreen extends ConsumerWidget {
  const RecommendationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recoAsync = ref.watch(recommendationsProvider);
    final isPersonalised = ref.watch(recoIsPersonalisedProvider);
    final auth = ref.watch(authProvider);
    final isLoggedIn = auth.whenOrNull(data: (a) => a.isAuthenticated) ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Image.asset('assets/images/logo.png', height: 40),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => context.push('/search'),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            onPressed: () => ref.invalidate(recommendationsProvider),
          ),
        ],
      ),
      body: recoAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _buildError(context, ref, e),
        data: (recos) =>
            _buildContent(context, ref, recos, isPersonalised, isLoggedIn),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    List<RecommendationItem> recos,
    bool isPersonalised,
    bool isLoggedIn,
  ) {
    void openWatchlist(MediaModel anime) =>
        openWatchlistSheet(context, ref, anime: anime, isLoggedIn: isLoggedIn);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(recommendationsProvider),
      child: CustomScrollView(
        slivers: [
          // ── Bannière contextuelle ──────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: isPersonalised
                  ? _InfoBanner(
                      icon: Icons.person,
                      text: 'Basé sur tes favoris et tes notes AniList',
                      color: Theme.of(context).colorScheme.primary,
                    )
                  : _InfoBanner(
                      icon: isLoggedIn
                          ? Icons.info_outline
                          : Icons.lock_outline,
                      text: isLoggedIn
                          ? 'Note des animes sur AniList pour des recos personnalisées'
                          : 'Connecte-toi pour des recommandations personnalisées',
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.35),
                      onTap: isLoggedIn ? null : () => context.go('/profile'),
                    ),
            ),
          ),

          // ── Liste des recommandations ──────────────────────────────────
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _RecoCard(
                item: recos[index],
                index: index,
                isFallback: !isPersonalised,
                onWatchlistTap: () => openWatchlist(recos[index].recommended),
              ),
              childCount: recos.length,
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  Widget _buildError(BuildContext context, WidgetRef ref, Object error) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off_rounded,
              size: 48, color: cs.onSurface.withValues(alpha: 0.38)),
          const SizedBox(height: 12),
          Text(
            error.toString(),
            style: TextStyle(color: cs.onSurface.withValues(alpha: 0.54)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text('Réessayer'),
            onPressed: () => ref.invalidate(recommendationsProvider),
          ),
        ],
      ),
    );
  }
}

// ── Carte recommandation ──────────────────────────────────────────────────────

class _RecoCard extends ConsumerWidget {
  const _RecoCard({
    required this.item,
    required this.index,
    required this.isFallback,
    this.onWatchlistTap,
  });

  final RecommendationItem item;
  final int index;
  final bool isFallback;
  final VoidCallback? onWatchlistTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final anime = item.recommended;
    final cs = Theme.of(context).colorScheme;
    final isLoggedIn =
        ref.watch(authProvider).whenOrNull(data: (a) => a.isAuthenticated) ??
            false;
    final isInWatchlist = isLoggedIn
        ? ref.watch(userListEntryProvider(anime.id)) != null
        : ref.watch(guestListEntryProvider(anime.id)) != null;
    final heroTag = 'reco_$index';

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => context.push('/detail/${anime.id}',
          extra: {'heroTag': heroTag, 'coverUrl': anime.coverImage}),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Jaquette + bouton watchlist
            SizedBox(
              width: 80,
              height: 115,
              child: Stack(
                children: [
                  Hero(
                    tag: heroTag,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox.expand(
                        child: anime.coverImage != null
                            ? CachedNetworkImage(
                                imageUrl: anime.coverImage!,
                                fit: BoxFit.cover,
                              )
                            : Container(color: cs.surfaceContainerHighest),
                      ),
                    ),
                  ),
                  if (onWatchlistTap != null)
                    Positioned(
                      bottom: 6,
                      right: 6,
                      child: GestureDetector(
                        onTap: onWatchlistTap,
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: cs.primary,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.4),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            isInWatchlist
                                ? Icons.edit_outlined
                                : Icons.bookmark_add_outlined,
                            size: 15,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // Infos
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // "Parce que tu as aimé X"
                  if (!isFallback && item.sourceTitle.isNotEmpty) ...[
                    Text(
                      'Parce que tu as aimé',
                      style: TextStyle(
                          fontSize: 11,
                          color: cs.onSurface.withValues(alpha: 0.38)),
                    ),
                    Text(
                      item.sourceTitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.primary,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                  ],

                  // Titre
                  Text(
                    anime.displayTitle,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 6),

                  // Score + épisodes
                  Row(
                    children: [
                      if (anime.formattedScore != null) ...[
                        const Icon(Icons.star_rounded,
                            size: 14, color: Color(0xFFFFC107)),
                        const SizedBox(width: 3),
                        Text(
                          anime.formattedScore!,
                          style: TextStyle(
                              fontSize: 13,
                              color: cs.onSurface.withValues(alpha: 0.7)),
                        ),
                        const SizedBox(width: 12),
                      ],
                      if (anime.episodes != null)
                        Text(
                          '${anime.episodes} ép.',
                          style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurface.withValues(alpha: 0.5)),
                        ),
                    ],
                  ),

                  const SizedBox(height: 6),

                  // Genres
                  if (anime.genres != null && anime.genres!.isNotEmpty)
                    Wrap(
                      spacing: 6,
                      children: anime.genres!
                          .take(3)
                          .map((g) => Text(
                                g,
                                style: TextStyle(
                                    fontSize: 11,
                                    color:
                                        cs.onSurface.withValues(alpha: 0.45)),
                              ))
                          .toList(),
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

// ── Bannière info ─────────────────────────────────────────────────────────────

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({
    required this.icon,
    required this.text,
    required this.color,
    this.onTap,
  });

  final IconData icon;
  final String text;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(text, style: TextStyle(fontSize: 12, color: color)),
            ),
            if (onTap != null)
              Icon(Icons.chevron_right, size: 16, color: color),
          ],
        ),
      ),
    );
  }
}
