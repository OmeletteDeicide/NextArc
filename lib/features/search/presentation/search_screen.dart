import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nextarc/core/constants/app_constants.dart';
import 'package:nextarc/core/widgets/anime_card.dart';
import 'package:nextarc/features/auth/domain/auth_providers.dart';
import 'package:nextarc/features/search/domain/search_providers.dart';
import 'package:nextarc/features/watchlist/presentation/watchlist_sheet_helper.dart';

/// Écran "Recherche" — barre avec debounce 400ms + grille de résultats.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: AppConstants.searchDebounceMs),
      () => ref.read(searchQueryProvider.notifier).state = value,
    );
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(searchResultsProvider);
    final query = ref.watch(searchQueryProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          onChanged: _onSearchChanged,
          // ← couleur du texte saisi adaptée au thème
          style: TextStyle(color: cs.onSurface),
          decoration: InputDecoration(
            hintText: 'Rechercher un anime, manga...',
            hintStyle: TextStyle(color: cs.onSurface.withValues(alpha: 0.4)),
            border: InputBorder.none,
            suffixIcon: query.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear, size: 18, color: cs.onSurface.withValues(alpha: 0.5)),
                    onPressed: () {
                      _controller.clear();
                      ref.read(searchQueryProvider.notifier).state = '';
                    },
                  )
                : null,
          ),
        ),
      ),
      body: results.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _buildError(error),
        data: (result) {
          if (result == null) return _buildIdle();
          if (result.items.isEmpty) return _buildEmpty(query);
          return _buildGrid(result.items);
        },
      ),
    );
  }

  Widget _buildIdle() {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search, size: 64, color: cs.onSurface.withValues(alpha: 0.12)),
          const SizedBox(height: 16),
          Text(
            'Tape un titre pour commencer',
            style: TextStyle(color: cs.onSurface.withValues(alpha: 0.38)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(String query) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 48, color: cs.onSurface.withValues(alpha: 0.24)),
          const SizedBox(height: 12),
          Text(
            'Aucun résultat pour "$query"',
            style: TextStyle(color: cs.onSurface.withValues(alpha: 0.54)),
          ),
        ],
      ),
    );
  }

  Widget _buildError(Object error) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off_rounded, color: cs.onSurface.withValues(alpha: 0.38), size: 40),
          const SizedBox(height: 12),
          Text(
            error.toString(),
            textAlign: TextAlign.center,
            style: TextStyle(color: cs.onSurface.withValues(alpha: 0.54)),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text('Réessayer'),
            onPressed: () => ref.invalidate(searchResultsProvider),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(List items) {
    final isLoggedIn = ref.watch(authProvider).whenOrNull(
              data: (a) => a.isAuthenticated,
            ) ??
        false;

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisExtent: 240,
        crossAxisSpacing: 12,
        mainAxisSpacing: 16,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final anime = items[index];
        final tag = 'search_$index';
        return AnimeCard(
          anime: anime,
          heroTag: tag,
          onTap: () => context.push('/detail/${anime.id}',
              extra: {'heroTag': tag, 'coverUrl': anime.coverImage}),
          width: double.infinity,
          onWatchlistTap: () => openWatchlistSheet(
            context, ref,
            anime: anime,
            isLoggedIn: isLoggedIn,
          ),
        );
      },
    );
  }
}
