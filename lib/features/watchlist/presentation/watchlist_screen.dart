import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:nextarc/features/auth/domain/auth_providers.dart';
import 'package:nextarc/features/watchlist/domain/media_list_entry.dart';
import 'package:nextarc/features/watchlist/domain/watchlist_providers.dart';

class WatchlistScreen extends ConsumerWidget {
  const WatchlistScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);

    return auth.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text(e.toString()))),
      data: (authState) {
        if (!authState.isAuthenticated) {
          return _buildNotLoggedIn(context);
        }
        return _buildList(context, ref);
      },
    );
  }

  // ── Non connecté ──────────────────────────────────────────────────────────

  Widget _buildNotLoggedIn(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Image.asset('assets/images/logo.png', height: 40)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, size: 64, color: cs.onSurface.withValues(alpha: 0.24)),
            const SizedBox(height: 16),
            const Text('Connecte-toi pour voir ta liste',
                style: TextStyle(fontSize: 16)),
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: const Icon(Icons.person),
              label: const Text('Aller au profil'),
              onPressed: () => context.go('/profile'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Liste avec onglets ────────────────────────────────────────────────────

  Widget _buildList(BuildContext context, WidgetRef ref) {
    final listAsync = ref.watch(userListProvider);
    final cs = Theme.of(context).colorScheme;

    return listAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: Image.asset('assets/images/logo.png', height: 40)),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.wifi_off_rounded,
                  size: 48, color: cs.onSurface.withValues(alpha: 0.38)),
              const SizedBox(height: 12),
              Text(e.toString(),
                  style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.54))),
              const SizedBox(height: 16),
              FilledButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Réessayer'),
                onPressed: () => ref.invalidate(userListProvider),
              ),
            ],
          ),
        ),
      ),
      data: (groups) {
        // Ordre imposé des onglets statut
        const orderedStatuses = [
          ListStatus.current,
          ListStatus.planning,
          ListStatus.paused,
          ListStatus.completed,
          ListStatus.dropped,
        ];

        final orderedGroups = orderedStatuses
            .map((s) => groups.where((g) => g.status == s).firstOrNull)
            .whereType<MediaListGroup>()
            .toList();

        // Favoris = animes notés >= 8 toutes listes confondues, triés par note
        final favourites = groups
            .expand((g) => g.entries)
            .where((e) => (e.score ?? 0) >= 8)
            .toList()
          ..sort((a, b) => (b.score ?? 0).compareTo(a.score ?? 0));

        final tabs = <Tab>[];
        final views = <Widget>[];

        // En cours + Prévu d'abord
        for (final s in [ListStatus.current, ListStatus.planning]) {
          final g = orderedGroups.where((g) => g.status == s).firstOrNull;
          if (g != null) {
            tabs.add(Tab(text: '${g.status.label} (${g.entries.length})'));
            views.add(_StatusTab(
              entries: g.entries,
              onRetry: () => ref.invalidate(userListProvider),
            ));
          }
        }

        // ❤️ Favoris en 3e position
        tabs.add(Tab(text: '❤️ Favoris (${favourites.length})'));
        views.add(_TopRatedTab(entries: favourites));

        // En pause / Terminé / Abandonné ensuite
        for (final s in [
          ListStatus.paused,
          ListStatus.completed,
          ListStatus.dropped
        ]) {
          final g = orderedGroups.where((g) => g.status == s).firstOrNull;
          if (g != null) {
            tabs.add(Tab(text: '${g.status.label} (${g.entries.length})'));
            views.add(_StatusTab(
              entries: g.entries,
              onRetry: () => ref.invalidate(userListProvider),
            ));
          }
        }

        return DefaultTabController(
          length: tabs.length,
          child: Scaffold(
            appBar: AppBar(
              title: Image.asset('assets/images/logo.png', height: 40),
              bottom: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: tabs,
              ),
            ),
            body: TabBarView(children: views),
          ),
        );
      },
    );
  }
}

// ── Onglet statut ──────────────────────────────────────────────────────────────

class _StatusTab extends StatelessWidget {
  const _StatusTab({required this.entries, required this.onRetry});

  final List<MediaListEntry> entries;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (entries.isEmpty) {
      return Center(
        child: Text(
          'Aucun anime dans cette liste',
          style: TextStyle(color: cs.onSurface.withValues(alpha: 0.38)),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => onRetry(),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: entries.length,
        separatorBuilder: (_, idx) => const Divider(height: 1, indent: 80),
        itemBuilder: (context, index) => _EntryTile(entry: entries[index]),
      ),
    );
  }
}

// ── Tuile d'entrée ────────────────────────────────────────────────────────────

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry});

  final MediaListEntry entry;

  @override
  Widget build(BuildContext context) {
    final anime = entry.media;
    final cs = Theme.of(context).colorScheme;

    return ListTile(
      onTap: () => context.push('/detail/${anime.id}'),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          width: 48,
          height: 68,
          child: anime.coverImage != null
              ? CachedNetworkImage(
                  imageUrl: anime.coverImage!,
                  fit: BoxFit.cover,
                )
              : Container(color: cs.surfaceContainerHighest),
        ),
      ),
      title: Text(
        anime.displayTitle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.play_circle_outline,
                  size: 13, color: cs.onSurface.withValues(alpha: 0.38)),
              const SizedBox(width: 4),
              Text(
                entry.progressLabel,
                style: TextStyle(
                    fontSize: 12, color: cs.onSurface.withValues(alpha: 0.54)),
              ),
            ],
          ),
        ],
      ),
      trailing: entry.formattedScore != null
          ? _ScoreBadge(score: entry.formattedScore!)
          : SizedBox(width: 40),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }
}

// ── Badge score ───────────────────────────────────────────────────────────────

class _ScoreBadge extends StatelessWidget {
  const _ScoreBadge({required this.score});

  final String score;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.star_rounded, size: 12, color: Color(0xFFFFC107)),
          Text(
            score,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: cs.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Onglet Favoris (note ≥ 8) ─────────────────────────────────────────────────

class _TopRatedTab extends StatelessWidget {
  const _TopRatedTab({required this.entries});

  final List<MediaListEntry> entries;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.star_outline,
                size: 48, color: cs.onSurface.withValues(alpha: 0.24)),
            const SizedBox(height: 12),
            Text(
              'Aucun anime noté ≥ 8 pour l\'instant',
              style: TextStyle(color: cs.onSurface.withValues(alpha: 0.38)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Note tes animes sur AniList pour les voir ici',
              style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.24), fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: entries.length,
      separatorBuilder: (_, idx) => const Divider(height: 1, indent: 80),
      itemBuilder: (context, index) {
        final entry = entries[index];
        final anime = entry.media;
        return ListTile(
          onTap: () => context.push('/detail/${anime.id}'),
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              width: 48,
              height: 68,
              child: anime.coverImage != null
                  ? CachedNetworkImage(
                      imageUrl: anime.coverImage!,
                      fit: BoxFit.cover,
                    )
                  : Container(color: cs.surfaceContainerHighest),
            ),
          ),
          title: Text(
            anime.displayTitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            entry.status?.label ?? '',
            style: TextStyle(
                fontSize: 12, color: cs.onSurface.withValues(alpha: 0.38)),
          ),
          trailing: entry.formattedScore != null
              ? _ScoreBadge(score: entry.formattedScore!)
              : const SizedBox(width: 40),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        );
      },
    );
  }
}
