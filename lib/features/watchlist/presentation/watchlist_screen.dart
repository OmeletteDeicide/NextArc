import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:nextarc/core/router/app_router.dart';
import 'package:nextarc/features/auth/domain/auth_providers.dart';
import 'package:nextarc/features/auth/domain/user_model.dart';
import 'package:nextarc/features/watchlist/domain/firestore_watchlist_providers.dart';
import 'package:nextarc/features/watchlist/presentation/watchlist_sheet_helper.dart';
import 'package:nextarc/features/discover/domain/discover_providers.dart';
import 'package:nextarc/features/watchlist/domain/guest_watchlist_entry.dart';
import 'package:nextarc/features/watchlist/domain/guest_watchlist_providers.dart';
import 'package:nextarc/features/watchlist/domain/media_list_entry.dart';
import 'package:nextarc/features/watchlist/domain/watchlist_providers.dart';

class WatchlistScreen extends ConsumerWidget {
  const WatchlistScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);

    return auth.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text(e.toString()))),
      data: (authState) {
        if (!authState.isAuthenticated) {
          return _buildGuestList(context, ref);
        }
        return _buildAuthenticatedList(context, ref);
      },
    );
  }

  // ── Vue invité (liste locale) ─────────────────────────────────────────────

  Widget _buildGuestList(BuildContext context, WidgetRef ref) {
    final guestAsync = ref.watch(guestWatchlistProvider);
    final cs = Theme.of(context).colorScheme;

    final loginBanner = ColoredBox(
      color: cs.primaryContainer.withValues(alpha: 0.55),
      child: ListTile(
        dense: true,
        leading: Icon(Icons.info_outline_rounded, color: cs.primary, size: 18),
        title: Text(
          'watchlist_guest_banner'.tr(),
          style: TextStyle(fontSize: 11, color: cs.onPrimaryContainer),
        ),
        trailing: TextButton(
          onPressed: () => context.go('/profile'),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text('watchlist_guest_banner_login'.tr(),
              style: TextStyle(fontSize: 11, color: cs.primary)),
        ),
      ),
    );

    return guestAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) =>
          Scaffold(body: Center(child: Text(e.toString()))),
      data: (entries) {
        if (entries.isEmpty) {
          return Scaffold(
            appBar: AppBar(
                title: Image.asset('assets/images/logo.png', height: 40)),
            body: Column(
              children: [
                loginBanner,
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.list_alt_rounded,
                            size: 64,
                            color: cs.onSurface.withValues(alpha: 0.24)),
                        const SizedBox(height: 16),
                        Text('watchlist_guest_empty_title'.tr(),
                            style: const TextStyle(fontSize: 16)),
                        const SizedBox(height: 8),
                        Text(
                          'watchlist_anime_empty_subtitle'.tr(),
                          style: TextStyle(
                              color: cs.onSurface.withValues(alpha: 0.54),
                              fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        final grouped = <ListStatus, List<GuestWatchlistEntry>>{};
        for (final e in entries) {
          grouped.putIfAbsent(e.status, () => []).add(e);
        }

        const orderedStatuses = [
          ListStatus.current,
          ListStatus.planning,
          ListStatus.paused,
          ListStatus.completed,
          ListStatus.dropped,
        ];

        final tabs = <Tab>[];
        final views = <Widget>[];

        for (final status in orderedStatuses) {
          final group = grouped[status];
          if (group != null && group.isNotEmpty) {
            tabs.add(Tab(text: '${status.label} (${group.length})'));
            views.add(_GuestStatusTab(
              entries: group,
              onDelete: (id) =>
                  ref.read(guestWatchlistProvider.notifier).remove(id),
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
            body: Column(
              children: [
                loginBanner,
                Expanded(child: TabBarView(children: views)),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Vue authentifiée : AniList ou Firestore selon le compte ─────────────

  Widget _buildAuthenticatedList(BuildContext context, WidgetRef ref) {
    final user =
        ref.watch(authProvider).whenOrNull<UserModel?>(data: (a) => a.user);
    if (user?.hasAnilist == true) {
      return const _AuthenticatedWatchlistView();
    }
    return _buildFirestoreList(context, ref, user);
  }

  // ── Vue Firebase-only (Firestore) ─────────────────────────────────────────

  Widget _buildFirestoreList(
      BuildContext context, WidgetRef ref, UserModel? user) {
    final firestoreAsync = ref.watch(firestoreWatchlistProvider);
    final cs = Theme.of(context).colorScheme;

    return firestoreAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text(e.toString()))),
      data: (entries) {
        if (entries.isEmpty) {
          return Scaffold(
            appBar:
                AppBar(title: Image.asset('assets/images/logo.png', height: 40)),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.list_alt_rounded,
                      size: 64, color: cs.onSurface.withValues(alpha: 0.24)),
                  const SizedBox(height: 16),
                  Text('watchlist_guest_empty_title'.tr(),
                      style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 8),
                  Text(
                    'watchlist_anime_empty_subtitle'.tr(),
                    style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.54),
                        fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        final grouped = <ListStatus, List<GuestWatchlistEntry>>{};
        for (final e in entries) {
          grouped.putIfAbsent(e.status, () => []).add(e);
        }

        const orderedStatuses = [
          ListStatus.current,
          ListStatus.planning,
          ListStatus.paused,
          ListStatus.completed,
          ListStatus.dropped,
        ];

        final tabs = <Tab>[];
        final views = <Widget>[];

        for (final status in orderedStatuses) {
          final group = grouped[status];
          if (group != null && group.isNotEmpty) {
            tabs.add(Tab(text: '${status.label} (${group.length})'));
            views.add(_GuestStatusTab(
              entries: group,
              onDelete: (id) =>
                  ref.read(firestoreWatchlistProvider.notifier).remove(id),
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

// ── Vue connectée avec onglet initial dynamique ───────────────────────────────

class _AuthenticatedWatchlistView extends ConsumerStatefulWidget {
  const _AuthenticatedWatchlistView();

  @override
  ConsumerState<_AuthenticatedWatchlistView> createState() =>
      _AuthenticatedWatchlistViewState();
}

class _AuthenticatedWatchlistViewState
    extends ConsumerState<_AuthenticatedWatchlistView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    final preference = ref.read(contentPreferenceProvider);
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: preference == 'MANGA' ? 1 : 0,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final animeAsync = ref.watch(userListProvider);
    final mangaAsync = ref.watch(userMangaListProvider);

    if (animeAsync.isLoading && mangaAsync.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Image.asset('assets/images/logo.png', height: 40),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_outlined),
            tooltip: 'calendar_title'.tr(),
            onPressed: () => context.push(AppRoutes.calendar),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '🎬 Anime'),
            Tab(text: '📖 Manga'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _AnimeListTab(animeAsync: animeAsync),
          _MangaListTab(mangaAsync: mangaAsync),
        ],
      ),
    );
  }
}

// ── Onglet Anime ──────────────────────────────────────────────────────────────

class _AnimeListTab extends ConsumerWidget {
  const _AnimeListTab({required this.animeAsync});

  final AsyncValue<List<MediaListGroup>> animeAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return animeAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _buildError(context, ref, e, isAnime: true),
      data: (groups) {
        final total = groups.expand((g) => g.entries).length;
        if (total == 0) {
          return _buildEmpty(
            context,
            icon: Icons.live_tv_rounded,
            message: 'watchlist_anime_empty_title'.tr(),
            sub: 'watchlist_anime_empty_subtitle'.tr(),
          );
        }
        return _buildStatusTabs(context, ref, groups, isAnime: true);
      },
    );
  }

  Widget _buildError(BuildContext context, WidgetRef ref, Object e,
      {required bool isAnime}) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off_rounded,
              size: 48, color: cs.onSurface.withValues(alpha: 0.38)),
          const SizedBox(height: 12),
          Text(e.toString(),
              style: TextStyle(color: cs.onSurface.withValues(alpha: 0.54))),
          const SizedBox(height: 16),
          FilledButton.icon(
            icon: const Icon(Icons.refresh),
            label: Text('action_retry'.tr()),
            onPressed: () => ref.invalidate(userListProvider),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusTabs(
    BuildContext context,
    WidgetRef ref,
    List<MediaListGroup> groups, {
    required bool isAnime,
  }) {
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

    final favourites = groups
        .expand((g) => g.entries)
        .where((e) => (e.score ?? 0) >= 8)
        .toList()
      ..sort((a, b) => (b.score ?? 0).compareTo(a.score ?? 0));

    final tabs = <Tab>[];
    final views = <Widget>[];

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

    tabs.add(Tab(text: '❤️ Favoris (${favourites.length})'));
    views.add(_TopRatedTab(entries: favourites));

    for (final s in [ListStatus.paused, ListStatus.completed, ListStatus.dropped]) {
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
      child: Column(
        children: [
          TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: tabs,
          ),
          Expanded(child: TabBarView(children: views)),
        ],
      ),
    );
  }
}

// ── Onglet Manga ──────────────────────────────────────────────────────────────

class _MangaListTab extends ConsumerWidget {
  const _MangaListTab({required this.mangaAsync});

  final AsyncValue<List<MediaListGroup>> mangaAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return mangaAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _buildError(context, ref, e),
      data: (groups) {
        final total = groups.expand((g) => g.entries).length;
        if (total == 0) {
          return _buildEmpty(
            context,
            icon: Icons.menu_book_rounded,
            message: 'watchlist_manga_empty_title'.tr(),
            sub: 'watchlist_manga_empty_subtitle'.tr(),
          );
        }
        return _buildStatusTabs(context, ref, groups);
      },
    );
  }

  Widget _buildError(BuildContext context, WidgetRef ref, Object e) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off_rounded,
              size: 48, color: cs.onSurface.withValues(alpha: 0.38)),
          const SizedBox(height: 12),
          Text(e.toString(),
              style: TextStyle(color: cs.onSurface.withValues(alpha: 0.54))),
          const SizedBox(height: 16),
          FilledButton.icon(
            icon: const Icon(Icons.refresh),
            label: Text('action_retry'.tr()),
            onPressed: () => ref.invalidate(userMangaListProvider),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusTabs(
    BuildContext context,
    WidgetRef ref,
    List<MediaListGroup> groups,
  ) {
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

    final favourites = groups
        .expand((g) => g.entries)
        .where((e) => (e.score ?? 0) >= 8)
        .toList()
      ..sort((a, b) => (b.score ?? 0).compareTo(a.score ?? 0));

    final tabs = <Tab>[];
    final views = <Widget>[];

    for (final s in [ListStatus.current, ListStatus.planning]) {
      final g = orderedGroups.where((g) => g.status == s).firstOrNull;
      if (g != null) {
        tabs.add(Tab(text: '${g.status.label} (${g.entries.length})'));
        views.add(_StatusTab(
          entries: g.entries,
          onRetry: () => ref.invalidate(userMangaListProvider),
        ));
      }
    }

    tabs.add(Tab(text: '❤️ Favoris (${favourites.length})'));
    views.add(_TopRatedTab(entries: favourites));

    for (final s in [ListStatus.paused, ListStatus.completed, ListStatus.dropped]) {
      final g = orderedGroups.where((g) => g.status == s).firstOrNull;
      if (g != null) {
        tabs.add(Tab(text: '${g.status.label} (${g.entries.length})'));
        views.add(_StatusTab(
          entries: g.entries,
          onRetry: () => ref.invalidate(userMangaListProvider),
        ));
      }
    }

    return DefaultTabController(
      length: tabs.length,
      child: Column(
        children: [
          TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: tabs,
          ),
          Expanded(child: TabBarView(children: views)),
        ],
      ),
    );
  }
}

// ── Helpers d'état vide ───────────────────────────────────────────────────────

Widget _buildEmpty(
  BuildContext context, {
  required IconData icon,
  required String message,
  required String sub,
}) {
  final cs = Theme.of(context).colorScheme;
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 64, color: cs.onSurface.withValues(alpha: 0.24)),
        const SizedBox(height: 16),
        Text(message, style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 8),
        Text(
          sub,
          style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.54), fontSize: 13),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}

// ── Onglet invité ─────────────────────────────────────────────────────────────

class _GuestStatusTab extends StatelessWidget {
  const _GuestStatusTab({required this.entries, required this.onDelete});

  final List<GuestWatchlistEntry> entries;
  final void Function(int animeId) onDelete;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: entries.length,
      separatorBuilder: (_, _) => const Divider(height: 1, indent: 80),
      itemBuilder: (context, index) {
        final entry = entries[index];
        return Dismissible(
          key: ValueKey(entry.animeId),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            color: Colors.red.shade800,
            child: const Icon(Icons.delete_outline, color: Colors.white),
          ),
          onDismissed: (_) {
            HapticFeedback.mediumImpact();
            onDelete(entry.animeId);
          },
          child: _GuestEntryTile(entry: entry),
        );
      },
    );
  }
}

class _GuestEntryTile extends StatelessWidget {
  const _GuestEntryTile({required this.entry});

  final GuestWatchlistEntry entry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      onTap: () => context.push('/detail/${entry.animeId}'),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          width: 48,
          height: 68,
          child: entry.coverImage != null
              ? CachedNetworkImage(
                  imageUrl: entry.coverImage!,
                  fit: BoxFit.cover,
                )
              : Container(color: cs.surfaceContainerHighest),
        ),
      ),
      title: Text(
        entry.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          children: [
            Icon(
                entry.isManga
                    ? Icons.menu_book_outlined
                    : Icons.play_circle_outline,
                size: 13,
                color: cs.onSurface.withValues(alpha: 0.38)),
            const SizedBox(width: 4),
            Text(
              entry.progressLabel,
              style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurface.withValues(alpha: 0.54)),
            ),
          ],
        ),
      ),
      trailing: entry.formattedScore != null
          ? _ScoreBadge(score: entry.formattedScore!)
          : const SizedBox(width: 40),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }
}

// ── Onglet statut AniList ─────────────────────────────────────────────────────

class _StatusTab extends ConsumerWidget {
  const _StatusTab({required this.entries, required this.onRetry});

  final List<MediaListEntry> entries;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    if (entries.isEmpty) {
      return Center(
        child: Text(
          'watchlist_status_tab_empty'.tr(),
          style: TextStyle(color: cs.onSurface.withValues(alpha: 0.38)),
        ),
      );
    }

    final user = ref.watch(authProvider).whenOrNull<UserModel?>(
          data: (a) => a.user,
        );

    return RefreshIndicator(
      onRefresh: () async => onRetry(),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: entries.length,
        separatorBuilder: (_, _) => const Divider(height: 1, indent: 80),
        itemBuilder: (context, index) {
          final entry = entries[index];
          return Dismissible(
            key: ValueKey('swipe_${entry.media.id}'),
            direction: DismissDirection.endToStart,
            confirmDismiss: (_) async {
              HapticFeedback.mediumImpact();
              openWatchlistSheet(
                context, ref,
                anime: entry.media,
                user: user,
              );
              return false; // ne retire pas l'item
            },
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              color: cs.primary.withValues(alpha: 0.15),
              child: Icon(Icons.edit_outlined, color: cs.primary),
            ),
            child: _EntryTile(entry: entry),
          );
        },
      ),
    );
  }
}

// ── Tuile d'entrée AniList ────────────────────────────────────────────────────

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry});

  final MediaListEntry entry;

  @override
  Widget build(BuildContext context) {
    final media = entry.media;
    final cs = Theme.of(context).colorScheme;

    return ListTile(
      onTap: () => context.push('/detail/${media.id}'),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          width: 48,
          height: 68,
          child: media.coverImage != null
              ? CachedNetworkImage(
                  imageUrl: media.coverImage!,
                  fit: BoxFit.cover,
                )
              : Container(color: cs.surfaceContainerHighest),
        ),
      ),
      title: Text(
        media.displayTitle,
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
              Icon(
                entry.isManga
                    ? Icons.menu_book_outlined
                    : Icons.play_circle_outline,
                size: 13,
                color: cs.onSurface.withValues(alpha: 0.38),
              ),
              const SizedBox(width: 4),
              Text(
                entry.progressLabel,
                style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurface.withValues(alpha: 0.54)),
              ),
              if (media.countryOfOrigin != null &&
                  media.countryOfOrigin != 'JP') ...[
                const SizedBox(width: 8),
                Text(
                  media.countryOfOrigin == 'KR'
                      ? 'label_manhwa'.tr()
                      : 'label_manhua'.tr(),
                  style: TextStyle(
                    fontSize: 11,
                    color: cs.primary.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
      trailing: entry.formattedScore != null
          ? _ScoreBadge(score: entry.formattedScore!)
          : const SizedBox(width: 40),
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
              'watchlist_favorites_empty'.tr(),
              style: TextStyle(color: cs.onSurface.withValues(alpha: 0.38)),
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
        final media = entry.media;
        return ListTile(
          onTap: () => context.push('/detail/${media.id}'),
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              width: 48,
              height: 68,
              child: media.coverImage != null
                  ? CachedNetworkImage(
                      imageUrl: media.coverImage!,
                      fit: BoxFit.cover,
                    )
                  : Container(color: cs.surfaceContainerHighest),
            ),
          ),
          title: Text(
            media.displayTitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            entry.status?.label ?? '',
            style: TextStyle(
                fontSize: 12,
                color: cs.onSurface.withValues(alpha: 0.38)),
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
