import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:nextarc/core/router/app_router.dart';
import 'package:nextarc/core/theme/app_tokens.dart';
import 'package:nextarc/core/widgets/ds/ds.dart';
import 'package:nextarc/features/auth/domain/auth_providers.dart';
import 'package:nextarc/features/auth/domain/user_model.dart';
import 'package:nextarc/features/calendar/domain/calendar_provider.dart';
import 'package:nextarc/features/discover/domain/discover_providers.dart';
import 'package:nextarc/features/watchlist/data/mutation_repository.dart';
import 'package:nextarc/features/watchlist/domain/firestore_watchlist_providers.dart';
import 'package:nextarc/features/watchlist/domain/guest_backup.dart';
import 'package:nextarc/features/watchlist/domain/guest_watchlist_providers.dart';
import 'package:nextarc/features/watchlist/domain/list_items.dart';
import 'package:nextarc/features/watchlist/domain/media_list_entry.dart';
import 'package:nextarc/features/watchlist/domain/watchlist_providers.dart';
import 'package:nextarc/features/watchlist/presentation/edit_sheet_parts.dart';
import 'package:nextarc/features/watchlist/presentation/watchlist_sheet_helper.dart';

/// D'où vient la liste affichée.
enum _ListSource { anilist, firestore, guest }

class WatchlistScreen extends ConsumerStatefulWidget {
  const WatchlistScreen({super.key});

  @override
  ConsumerState<WatchlistScreen> createState() => _WatchlistScreenState();
}

class _WatchlistScreenState extends ConsumerState<WatchlistScreen> {
  late bool _isManga =
      ref.read(contentPreferenceProvider) == 'MANGA';

  /// Onglet choisi par segment (Anime / Manga).
  final Map<bool, String> _tabKeys = {};

  /// Médias dont le +1 / Démarrer est en cours d'enregistrement.
  final Set<int> _busy = {};

  @override
  Widget build(BuildContext context) {
    final authAsync = ref.watch(authProvider);
    if (authAsync.isLoading && !authAsync.hasValue) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final user = authAsync.whenOrNull<UserModel?>(data: (a) => a.user);
    final source = user?.usesAnilistList == true
        ? _ListSource.anilist
        : user?.hasFirebase == true
            ? _ListSource.firestore
            : _ListSource.guest;

    // ── Éléments des deux segments ──────────────────────────────────────────
    final AsyncValue<List<ListItem>> animeAsync;
    final AsyncValue<List<ListItem>> mangaAsync;
    if (source == _ListSource.anilist) {
      List<ListItem> flatten(List<MediaListGroup> groups) => [
            for (final g in groups)
              for (final e in g.entries) ListItem.fromAnilist(e),
          ];
      animeAsync = ref.watch(userListProvider).whenData(flatten);
      mangaAsync = ref.watch(userMangaListProvider).whenData(flatten);
    } else {
      final entries = source == _ListSource.firestore
          ? ref.watch(firestoreWatchlistProvider)
          : ref.watch(guestWatchlistProvider);
      final all = entries.whenData((list) => list.map(ListItem.fromLocal));
      animeAsync = all.whenData((l) => l.where((i) => !i.isManga).toList());
      mangaAsync = all.whenData((l) => l.where((i) => i.isManga).toList());
    }

    final currentAsync = _isManga ? mangaAsync : animeAsync;
    final c = AppColors.of(context);
    final text = Theme.of(context).textTheme;

    String segmentLabel(String name, AsyncValue<List<ListItem>> async) {
      final count = async.valueOrNull?.length;
      return count == null ? name : '$name · $count';
    }

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── En-tête ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screen, AppSpacing.xs, AppSpacing.screen, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text('nav_my_list'.tr(),
                        style: text.headlineMedium?.copyWith(color: c.text1)),
                  ),
                  RoundIconButton(
                    icon: Icons.calendar_month_outlined,
                    tooltip: 'calendar_title'.tr(),
                    onTap: () => context.push(AppRoutes.calendar),
                  ),
                ],
              ),
            ),
            if (source == _ListSource.guest &&
                !ref.watch(guestBannerDismissedProvider))
              const _GuestBanner(),
            const SizedBox(height: 14),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
              child: SegmentedControl<bool>(
                segments: [
                  (value: false, label: segmentLabel('Anime', animeAsync)),
                  (value: true, label: segmentLabel('Manga', mangaAsync)),
                ],
                selected: _isManga,
                onChanged: (v) => setState(() => _isManga = v),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Expanded(
              child: currentAsync.when(
                skipLoadingOnReload: true,
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => _ErrorState(
                  message: e.toString(),
                  onRetry: () => _refresh(source),
                ),
                data: (items) => _buildList(context, items, source, user),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    List<ListItem> items,
    _ListSource source,
    UserModel? user,
  ) {
    if (items.isEmpty) {
      // Un état vide promet quelque chose et propose une action
      return _EmptyState(
        icon: _isManga ? Icons.menu_book_rounded : Icons.live_tv_rounded,
        title: _isManga
            ? 'watchlist_manga_empty_title'.tr()
            : 'watchlist_empty_title'.tr(),
        subtitle: _isManga
            ? 'watchlist_manga_empty_subtitle'.tr()
            : 'watchlist_empty_subtitle'.tr(),
        actionLabel: 'watchlist_empty_explore'.tr(),
        onAction: () => context.go(AppRoutes.discover),
        // Invité : la liste peut venir d'une sauvegarde .json
        secondaryLabel: source == _ListSource.guest
            ? 'watchlist_empty_import'.tr()
            : null,
        onSecondary: () => context.push(AppRoutes.settings),
      );
    }

    final tabs = buildListTabs(items);
    final selected = tabs.firstWhere(
      (t) => t.key == _tabKeys[_isManga],
      orElse: () => tabs.first,
    );

    final releases = _isManga ? 0 : _releasesThisWeek();
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    final list = ListView(
      padding: EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.sm,
          AppSpacing.screen, AppSpacing.xl + bottomInset),
      children: [
        if (selected.items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
            child: Text(
              selected.isFavourites
                  ? 'watchlist_favorites_empty'.tr()
                  : 'watchlist_status_tab_empty'.tr(),
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.of(context).text3),
            ),
          ),
        for (final item in selected.items) ...[
          _dismissible(
            item: item,
            source: source,
            user: user,
            child: _ListRow(
              item: item,
              inFavouritesTab: selected.isFavourites,
              busy: _busy.contains(item.mediaId),
              onOpen: () => context.push('/detail/${item.mediaId}'),
              onEdit: () => openWatchlistSheet(context, ref,
                  anime: item.toMedia(), user: user),
              onPlusOne: () => _plusOne(item, source),
              onStart: () => _start(item, source),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        if (releases > 0) ...[
          const SizedBox(height: AppSpacing.xs),
          _ReleasesCard(count: releases),
        ],
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StatusTabs(
          tabs: tabs,
          selectedKey: selected.key,
          onSelected: (key) => setState(() => _tabKeys[_isManga] = key),
        ),
        Expanded(
          child: source == _ListSource.anilist
              ? RefreshIndicator(
                  onRefresh: () async => _refresh(source), child: list)
              : list,
        ),
      ],
    );
  }

  /// Glisser vers la gauche : retirer (NextArc / invité) ou modifier (AniList,
  /// où la suppression demande une confirmation dans la fiche).
  Widget _dismissible({
    required ListItem item,
    required _ListSource source,
    required UserModel? user,
    required Widget child,
  }) {
    final c = AppColors.of(context);
    final isAnilist = source == _ListSource.anilist;

    return Dismissible(
      key: ValueKey('list_${item.mediaId}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        HapticFeedback.mediumImpact();
        if (isAnilist) {
          openWatchlistSheet(context, ref, anime: item.toMedia(), user: user);
          return false;
        }
        return confirmRemoveFromList(
          context,
          'sheet_delete_dialog_content_guest'
              .tr(namedArgs: {'title': item.title}),
        );
      },
      onDismissed: (_) {
        if (source == _ListSource.firestore) {
          ref.read(firestoreWatchlistProvider.notifier).remove(item.mediaId);
        } else {
          ref.read(guestWatchlistProvider.notifier).remove(item.mediaId);
        }
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: (isAnilist ? c.accent : c.favourite).withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: Icon(
          isAnilist ? Icons.edit_outlined : Icons.delete_outline_rounded,
          color: isAnilist ? c.accentText : c.favourite,
        ),
      ),
      child: child,
    );
  }

  int _releasesThisWeek() {
    final calendar = ref.watch(airingCalendarProvider).valueOrNull;
    if (calendar == null) return 0;
    return countReleasesWithin(
      calendar.values.expand((day) => day).map((e) => e.airingAt),
      now: DateTime.now(),
    );
  }

  void _refresh(_ListSource source) {
    switch (source) {
      case _ListSource.anilist:
        ref.invalidate(userListProvider);
        ref.invalidate(userMangaListProvider);
      case _ListSource.firestore:
        ref.invalidate(firestoreWatchlistProvider);
      case _ListSource.guest:
        ref.invalidate(guestWatchlistProvider);
    }
  }

  // ── Actions rapides ─────────────────────────────────────────────────────────

  Future<void> _plusOne(ListItem item, _ListSource source) async {
    final next = plusOne(
      progress: item.progress,
      total: item.total,
      status: item.status,
    );
    final completed = next.status == ListStatus.completed &&
        item.status != ListStatus.completed;
    await _update(item, source, progress: next.progress, status: next.status,
        message: completed
            ? 'watchlist_marked_completed'.tr(namedArgs: {'title': item.title})
            : null);
  }

  Future<void> _start(ListItem item, _ListSource source) => _update(
        item,
        source,
        progress: item.progress,
        status: ListStatus.current,
        message: 'watchlist_started'.tr(namedArgs: {'title': item.title}),
      );

  Future<void> _update(
    ListItem item,
    _ListSource source, {
    required int progress,
    required ListStatus status,
    String? message,
  }) async {
    if (_busy.contains(item.mediaId)) return;
    HapticFeedback.lightImpact();
    setState(() => _busy.add(item.mediaId));
    try {
      switch (source) {
        case _ListSource.anilist:
          await MutationRepository().saveEntry(
            mediaId: item.mediaId,
            status: status,
            score: (item.score ?? 0) > 0 ? item.score : null,
            progress: progress > 0 ? progress : null,
          );
          ref.invalidate(item.isManga ? userMangaListProvider : userListProvider);
        case _ListSource.firestore:
          await ref.read(firestoreWatchlistProvider.notifier).upsert(item
              .local!
              .copyWith(progress: progress, status: status));
        case _ListSource.guest:
          await ref.read(guestWatchlistProvider.notifier).upsert(item.local!
              .copyWith(
                  progress: progress,
                  status: status,
                  updatedAt: DateTime.now()));
      }
      if (message != null && mounted) showEditSheetSnackBar(context, message);
    } catch (e) {
      if (mounted) {
        showEditSheetSnackBar(
          context,
          'sheet_snackbar_error'.tr(namedArgs: {'error': e.toString()}),
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _busy.remove(item.mediaId));
    }
  }
}

// ── En-tête ───────────────────────────────────────────────────────────────────

/// Bandeau « Mode invité » discret, masquable pour la session.
class _GuestBanner extends ConsumerWidget {
  const _GuestBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.screen, AppSpacing.sm, AppSpacing.screen, 0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 0, 0, 0),
        decoration: BoxDecoration(
          color: c.surface1,
          borderRadius: BorderRadius.circular(AppRadius.cover),
          border: Border.all(color: c.border),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline_rounded, size: 16, color: c.text3),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                'watchlist_guest_banner_local'.tr(),
                style: text.bodySmall?.copyWith(color: c.text2),
              ),
            ),
            TextButton(
              onPressed: () => context.go(AppRoutes.profile),
              style: TextButton.styleFrom(foregroundColor: c.accentText),
              child: Text('watchlist_guest_banner_login'.tr()),
            ),
            IconButton(
              tooltip: 'watchlist_guest_banner_hide'.tr(),
              icon: Icon(Icons.close_rounded, size: 16, color: c.text3),
              onPressed: () =>
                  ref.read(guestBannerDismissedProvider.notifier).state = true,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Onglets de statut (un seul niveau) ────────────────────────────────────────

class _StatusTabs extends StatelessWidget {
  const _StatusTabs({
    required this.tabs,
    required this.selectedKey,
    required this.onSelected,
  });

  final List<ListTab> tabs;
  final String selectedKey;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final text = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen - 6),
        child: Row(
          children: [
            for (final tab in tabs)
              Semantics(
                button: true,
                selected: tab.key == selectedKey,
                child: InkWell(
                  onTap: () {
                    if (tab.key == selectedKey) return;
                    HapticFeedback.selectionClick();
                    onSelected(tab.key);
                  },
                  child: Container(
                    constraints:
                        const BoxConstraints(minHeight: AppSpacing.minTouch),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          width: 2,
                          color: tab.key == selectedKey
                              ? c.accentText
                              : Colors.transparent,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (tab.isFavourites) ...[
                          Icon(Icons.favorite_rounded,
                              size: 13,
                              color: tab.key == selectedKey
                                  ? c.favourite
                                  : c.text3),
                          const SizedBox(width: 5),
                        ],
                        Text(
                          tab.isFavourites
                              ? 'watchlist_tab_favourites'.tr()
                              : tab.status!.label,
                          style: text.labelLarge?.copyWith(
                            color: tab.key == selectedKey ? c.text1 : c.text3,
                            fontWeight: tab.key == selectedKey
                                ? FontWeight.w800
                                : FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '${tab.items.length}',
                          style: text.labelSmall?.copyWith(
                            color: tab.key == selectedKey ? c.text2 : c.text3,
                            letterSpacing: 0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Ligne de liste ────────────────────────────────────────────────────────────

class _ListRow extends StatelessWidget {
  const _ListRow({
    required this.item,
    required this.inFavouritesTab,
    required this.busy,
    required this.onOpen,
    required this.onEdit,
    required this.onPlusOne,
    required this.onStart,
  });

  final ListItem item;
  final bool inFavouritesTab;
  final bool busy;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onPlusOne;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    final score = (item.score ?? 0) > 0
        ? formatSheetScore(context, item.score!)
        : null;
    final countLabel = '${item.progress}/${item.hasKnownTotal ? item.total : '?'}';

    // ── Ligne d'info sous le titre ──────────────────────────────────────────
    final Widget? meta;
    if (inFavouritesTab) {
      meta = _MetaText([
        if (score != null) '★ $score',
        item.status.label,
      ].join(' · '));
    } else if (item.status == ListStatus.completed) {
      meta = _MetaText(
        [if (score != null) '★ $score', countLabel].join(' · '),
        color: score != null ? c.star : null,
      );
    } else if (item.status == ListStatus.planning) {
      meta = _MetaText(countLabel);
    } else if (item.nextAiring != null && !item.isManga) {
      final day = DateFormat.EEEE(context.locale.toString())
          .format(item.nextAiring!.airingAt.toLocal());
      meta = _MetaText('watchlist_next_episode'.tr(namedArgs: {
        'number': '${item.nextAiring!.episode}',
        'day': day,
      }));
    } else if (item.countryOfOrigin != null &&
        item.countryOfOrigin != 'JP' &&
        item.isManga) {
      meta = _MetaText(
        item.countryOfOrigin == 'KR' ? 'label_manhwa'.tr() : 'label_manhua'.tr(),
        color: c.accentText,
      );
    } else {
      meta = null;
    }

    final showProgress = !inFavouritesTab &&
        (item.status == ListStatus.current ||
            item.status == ListStatus.paused ||
            item.status == ListStatus.dropped);

    // ── Action à droite ─────────────────────────────────────────────────────
    final Widget? action;
    if (inFavouritesTab) {
      action = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Icon(Icons.favorite_rounded, size: 18, color: c.favourite),
      );
    } else if (item.canPlusOne) {
      action = _PlusOneButton(busy: busy, onTap: onPlusOne);
    } else if (item.status == ListStatus.planning) {
      action = _PillButton(
        label: 'watchlist_start'.tr(),
        busy: busy,
        onTap: onStart,
      );
    } else {
      action = null;
    }

    return Material(
      color: c.surface1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: inFavouritesTab
            ? BorderSide(color: c.favourite.withValues(alpha: 0.28))
            : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        onLongPress: onEdit,
        child: Padding(
          padding: const EdgeInsets.all(11),
          child: Row(
            children: [
              SizedBox(
                width: 52,
                child: MediaCover(imageUrl: item.coverImage, radius: 9),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleSmall?.copyWith(color: c.text1),
                    ),
                    if (meta != null) ...[
                      const SizedBox(height: 5),
                      meta,
                    ],
                    if (showProgress) ...[
                      const SizedBox(height: 7),
                      Row(
                        children: [
                          Expanded(
                            child: item.hasKnownTotal
                                ? GradientProgressBar(
                                    value: item.progress / item.total!,
                                    height: 5,
                                  )
                                : const SizedBox.shrink(),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            countLabel,
                            style: text.labelSmall?.copyWith(
                              color: c.text2,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (action != null) ...[
                const SizedBox(width: AppSpacing.sm),
                action,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaText extends StatelessWidget {
  const _MetaText(this.text, {this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context)
          .textTheme
          .bodySmall
          ?.copyWith(color: color ?? c.text2, fontSize: 10.5),
    );
  }
}

class _PlusOneButton extends StatelessWidget {
  const _PlusOneButton({required this.busy, required this.onTap});

  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Semantics(
      button: true,
      label: 'watchlist_plus_one_label'.tr(),
      child: InkResponse(
        onTap: busy ? null : onTap,
        radius: 24,
        child: SizedBox(
          width: AppSpacing.minTouch,
          height: AppSpacing.minTouch,
          child: Center(
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: c.accentGradient,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      '+1',
                      style: Theme.of(context)
                          .textTheme
                          .labelLarge
                          ?.copyWith(color: Colors.white),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.label,
    required this.busy,
    required this.onTap,
  });

  final String label;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.full),
      onTap: busy ? null : onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSpacing.minTouch),
        child: Center(
          widthFactor: 1,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: c.surface2,
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: busy
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    label,
                    style: Theme.of(context)
                        .textTheme
                        .labelMedium
                        ?.copyWith(color: c.text1, fontSize: 11),
                  ),
          ),
        ),
      ),
    );
  }
}

// ── Carte « sorties cette semaine » ───────────────────────────────────────────

class _ReleasesCard extends StatelessWidget {
  const _ReleasesCard({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: c.surface1,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: c.text3.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            count == 1
                ? 'watchlist_releases_week_one'.tr()
                : 'watchlist_releases_week'
                    .tr(namedArgs: {'count': '$count'}),
            style: text.titleSmall?.copyWith(color: c.text1, fontSize: 12.5),
          ),
          const SizedBox(height: 6),
          Text(
            'watchlist_releases_week_sub'.tr(),
            style: text.bodySmall?.copyWith(color: c.text2),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () => context.push(AppRoutes.calendar),
            style: OutlinedButton.styleFrom(
              foregroundColor: c.accentText,
              side: BorderSide(color: c.accentText.withValues(alpha: 0.45)),
              shape: const StadiumBorder(),
            ),
            child: Text('watchlist_see_calendar'.tr()),
          ),
        ],
      ),
    );
  }
}

// ── États vide / erreur ───────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
    this.secondaryLabel,
    this.onSecondary,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: c.surface1,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, size: 32, color: c.accentText),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(title,
                textAlign: TextAlign.center,
                style: text.titleLarge?.copyWith(color: c.text1)),
            const SizedBox(height: AppSpacing.xs),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: text.bodyMedium?.copyWith(color: c.text2)),
            if (actionLabel != null) ...[
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: actionLabel!,
                icon: Icons.explore_outlined,
                onPressed: onAction,
              ),
            ],
            if (secondaryLabel != null) ...[
              const SizedBox(height: AppSpacing.xs),
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: c.accentText),
                onPressed: onSecondary,
                icon: const Icon(Icons.file_download_outlined, size: 18),
                label: Text(secondaryLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

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
            Icon(Icons.wifi_off_rounded, size: 44, color: c.text3),
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
