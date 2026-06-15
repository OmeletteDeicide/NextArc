import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nextarc/core/widgets/horizontal_anime_list.dart';
import 'package:nextarc/features/auth/domain/auth_providers.dart';
import 'package:nextarc/features/discover/domain/discover_providers.dart';
import 'package:nextarc/features/discover/domain/media_model.dart';
import 'package:nextarc/features/watchlist/presentation/watchlist_sheet_helper.dart';

/// Extrait l'URL de couverture depuis un AsyncValue par tag (ex: 'trending_2').
String? _coverUrl(AsyncValue asyncValue, String tag) {
  final index = int.tryParse(tag.split('_').last);
  if (index == null) return null;
  return asyncValue.whenOrNull(
    data: (result) => result.items.length > index
        ? result.items[index].coverImage
        : null,
  );
}

/// Écran principal "Découvrir" — sections horizontales Tendances + Saison.
class DiscoverScreen extends ConsumerWidget {
  const DiscoverScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trending = ref.watch(trendingAnimeProvider);
    final seasonal = ref.watch(seasonalAnimeProvider);

    final isLoggedIn = ref.watch(authProvider).whenOrNull(
              data: (a) => a.isAuthenticated,
            ) ??
        false;

    void openWatchlist(MediaModel anime) =>
        openWatchlistSheet(context, ref, anime: anime, isLoggedIn: isLoggedIn);

    return Scaffold(
      appBar: AppBar(
        title: Image.asset('assets/images/logo.png', height: 40),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => context.push('/search'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // Invalide les providers pour forcer un rechargement
          ref.invalidate(trendingAnimeProvider);
          ref.invalidate(seasonalAnimeProvider);
          // Attend que les deux soient rechargés
          await Future.wait([
            ref.read(trendingAnimeProvider.future),
            ref.read(seasonalAnimeProvider.future),
          ]);
        },
        child: ListView(
          children: [
            // ── Section Tendances ────────────────────────────────────────
            HorizontalAnimeList(
              title: 'Tendances',
              asyncValue: trending,
              sectionKey: 'trending',
              onAnimeTap: (id, tag) => context.push('/detail/$id',
                  extra: {'heroTag': tag, 'coverUrl': _coverUrl(trending, tag)}),
              onRetry: () => ref.invalidate(trendingAnimeProvider),
              onWatchlistTap: openWatchlist,
            ),

            // ── Section Saison en cours ──────────────────────────────────
            HorizontalAnimeList(
              title: 'En ce moment',
              asyncValue: seasonal,
              sectionKey: 'seasonal',
              onAnimeTap: (id, tag) => context.push('/detail/$id',
                  extra: {'heroTag': tag, 'coverUrl': _coverUrl(seasonal, tag)}),
              onRetry: () => ref.invalidate(seasonalAnimeProvider),
              onWatchlistTap: openWatchlist,
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
