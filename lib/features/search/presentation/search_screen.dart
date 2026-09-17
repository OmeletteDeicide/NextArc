import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nextarc/core/constants/app_constants.dart';
import 'package:nextarc/core/router/app_router.dart';
import 'package:nextarc/core/theme/app_tokens.dart';
import 'package:nextarc/core/theme/app_typography.dart';
import 'package:nextarc/core/widgets/ds/ds.dart';
import 'package:nextarc/features/auth/domain/auth_providers.dart';
import 'package:nextarc/features/discover/domain/discover_providers.dart';
import 'package:nextarc/features/discover/domain/media_model.dart';
import 'package:nextarc/features/search/domain/search_highlight.dart';
import 'package:nextarc/features/search/domain/search_history_service.dart';
import 'package:nextarc/features/search/domain/search_providers.dart';
import 'package:nextarc/features/watchlist/domain/in_watchlist_provider.dart';
import 'package:nextarc/features/watchlist/presentation/watchlist_sheet_helper.dart';

String? _score(BuildContext context, MediaModel media) {
  final s = media.formattedScore;
  if (s == null) return null;
  return context.locale.languageCode == 'en' ? s : s.replaceAll('.', ',');
}

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<String> _history = [];
  bool? _mangaTab;

  @override
  void initState() {
    super.initState();
    _history = SearchHistoryService.instance.history;
    // Nouvelle recherche à chaque ouverture
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => ref.read(searchQueryProvider.notifier).state = '');
  }

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: AppConstants.searchDebounceMs),
      () {
        _mangaTab = null;
        ref.read(searchQueryProvider.notifier).state = value;
        if (value.trim().isNotEmpty) {
          SearchHistoryService.instance.add(value.trim()).then((_) {
            if (mounted) {
              setState(() => _history = SearchHistoryService.instance.history);
            }
          });
        }
      },
    );
  }

  void _search(String query) {
    HapticFeedback.selectionClick();
    _controller.text = query;
    _controller.selection = TextSelection.collapsed(offset: query.length);
    _mangaTab = null;
    ref.read(searchQueryProvider.notifier).state = query;
    SearchHistoryService.instance.add(query);
    setState(() {});
  }

  void _clearQuery() {
    _controller.clear();
    _mangaTab = null;
    ref.read(searchQueryProvider.notifier).state = '';
    setState(() {});
  }

  Future<void> _refreshHistory(Future<void> action) async {
    await action;
    if (mounted) setState(() => _history = SearchHistoryService.instance.history);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    final results = ref.watch(searchResultsProvider);
    final query = ref.watch(searchQueryProvider);
    final offline = results.hasError;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Barre de recherche ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screen - 4, AppSpacing.xs, AppSpacing.screen, 12),
              child: Row(
                children: [
                  RoundIconButton(
                    icon: Icons.arrow_back_rounded,
                    tooltip:
                        MaterialLocalizations.of(context).backButtonTooltip,
                    onTap: () => context.pop(),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Container(
                      height: AppSpacing.minTouch,
                      padding: const EdgeInsets.only(left: 14, right: 4),
                      decoration: BoxDecoration(
                        color: c.surface1,
                        borderRadius: BorderRadius.circular(AppRadius.card),
                        border: Border.all(
                          color: offline
                              ? c.border
                              : c.accentText.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.search_rounded,
                              size: 18,
                              color: offline ? c.text3 : c.accentText),
                          const SizedBox(width: 9),
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              autofocus: true,
                              onChanged: _onSearchChanged,
                              textInputAction: TextInputAction.search,
                              style: text.bodyMedium?.copyWith(
                                  color: c.text1,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600),
                              decoration: InputDecoration(
                                hintText: 'search_hint'.tr(),
                                hintStyle: text.bodyMedium?.copyWith(
                                    color: c.text3, fontSize: 13),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                filled: false,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                          if (_controller.text.isNotEmpty)
                            IconButton(
                              tooltip: 'search_clear'.tr(),
                              icon: Icon(Icons.close_rounded,
                                  size: 18, color: c.text3),
                              onPressed: _clearQuery,
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: results.when(
                skipLoadingOnReload: true,
                loading: () => const Center(
                    child: CircularProgressIndicator(strokeWidth: 2)),
                error: (_, _) => _SearchState(
                  icon: Icons.warning_amber_rounded,
                  danger: true,
                  title: 'search_offline_title'.tr(),
                  body: 'search_offline_body'.tr(),
                  primaryLabel: 'action_retry'.tr(),
                  onPrimary: () => ref.invalidate(searchResultsProvider),
                  secondaryLabel: 'calendar_empty_list'.tr(),
                  onSecondary: () => context.go(AppRoutes.watchlist),
                ),
                data: (result) {
                  if (result == null || query.trim().isEmpty) {
                    return _IdleView(
                      history: _history,
                      onSearch: _search,
                      onRemove: (q) => _refreshHistory(
                          SearchHistoryService.instance.remove(q)),
                      onClear: () => _refreshHistory(
                          SearchHistoryService.instance.clear()),
                    );
                  }
                  if (result.items.isEmpty) {
                    return _SearchState(
                      icon: Icons.search_off_rounded,
                      title: 'search_empty_title'.tr(),
                      body: 'search_empty_body'.tr(),
                      primaryLabel: 'search_browse_genres'.tr(),
                      onPrimary: () => context.push(AppRoutes.browse),
                      secondaryLabel: 'search_clear'.tr(),
                      onSecondary: _clearQuery,
                    );
                  }
                  return _Results(
                    items: result.items,
                    query: query,
                    mangaTab: _mangaTab,
                    onTab: (v) => setState(() => _mangaTab = v),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Ouverture : récentes + tendances ──────────────────────────────────────────

class _IdleView extends ConsumerWidget {
  const _IdleView({
    required this.history,
    required this.onSearch,
    required this.onRemove,
    required this.onClear,
  });

  final List<String> history;
  final ValueChanged<String> onSearch;
  final ValueChanged<String> onRemove;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    // Tendances déjà chargées par Découvrir : aucune requête en plus
    final anime =
        ref.watch(trendingAnimeProvider).valueOrNull?.items ?? const [];
    final manga =
        ref.watch(trendingMangaProvider).valueOrNull?.items ?? const [];
    final trending = [
      ...anime.take(2),
      ...manga.take(1),
      ...anime.skip(2).take(1),
    ];

    return ListView(
      padding: EdgeInsets.fromLTRB(
          AppSpacing.screen, 0, AppSpacing.screen, AppSpacing.xl + bottomInset),
      children: [
        if (history.isNotEmpty) ...[
          Row(
            children: [
              Expanded(
                child: Text('search_history'.tr().toUpperCase(),
                    style: AppTypography.overline(c.text3)),
              ),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: c.accentText),
                onPressed: onClear,
                child: Text('search_history_clear'.tr()),
              ),
            ],
          ),
          for (final q in history)
            InkWell(
              onTap: () => onSearch(q),
              child: SizedBox(
                height: AppSpacing.minTouch,
                child: Row(
                  children: [
                    Icon(Icons.history_rounded, size: 18, color: c.text3),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(q,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.titleSmall?.copyWith(color: c.text1)),
                    ),
                    Tooltip(
                      message: 'search_history_remove'.tr(),
                      child: InkResponse(
                        radius: 18,
                        onTap: () => onRemove(q),
                        child: SizedBox(
                          width: 32,
                          height: AppSpacing.minTouch,
                          child: Icon(Icons.close_rounded,
                              size: 16, color: c.text3),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.lg),
        ],
        if (trending.isNotEmpty) ...[
          Text('search_trending'.tr().toUpperCase(),
              style: AppTypography.overline(c.text3)),
          const SizedBox(height: 11),
          for (var i = 0; i < trending.length; i++)
            InkWell(
              borderRadius: BorderRadius.circular(AppRadius.chip),
              onTap: () => context.push('/detail/${trending[i].id}'),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.5),
                child: Row(
                  children: [
                    SizedBox(
                      width: 26,
                      child: Text(
                        (i + 1).toString().padLeft(2, '0'),
                        style: text.displayLarge?.copyWith(
                            fontSize: 15, height: 1, color: c.text3),
                      ),
                    ),
                    SizedBox(
                      width: 34,
                      child: MediaCover(
                          imageUrl: trending[i].coverImage, radius: 7),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(trending[i].displayTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.titleSmall?.copyWith(
                                  color: c.text1, fontSize: 12.5)),
                          const SizedBox(height: 2),
                          Text.rich(
                            TextSpan(children: [
                              TextSpan(
                                  text: trending[i].isManga
                                      ? 'Manga'
                                      : 'Anime'),
                              if (_score(context, trending[i]) != null)
                                TextSpan(
                                  text: ' · ★ ${_score(context, trending[i])}',
                                  style: TextStyle(color: c.star),
                                ),
                            ]),
                            style: text.bodySmall
                                ?.copyWith(color: c.text2, fontSize: 10.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }
}

// ── Résultats ─────────────────────────────────────────────────────────────────

class _Results extends StatelessWidget {
  const _Results({
    required this.items,
    required this.query,
    required this.mangaTab,
    required this.onTab,
  });

  final List<MediaModel> items;
  final String query;

  /// Onglet choisi (null = automatique : le type le plus représenté).
  final bool? mangaTab;
  final ValueChanged<bool> onTab;

  @override
  Widget build(BuildContext context) {
    final anime = items.where((m) => !m.isManga).toList();
    final manga = items.where((m) => m.isManga).toList();
    final showManga = mangaTab ?? manga.length > anime.length;
    final shown = showManga ? manga : anime;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.screen, 0, AppSpacing.screen, 12),
          child: SegmentedControl<bool>(
            segments: [
              (value: false, label: 'Anime · ${anime.length}'),
              (value: true, label: 'Manga · ${manga.length}'),
            ],
            selected: showManga,
            onChanged: onTab,
          ),
        ),
        Expanded(
          child: shown.isEmpty
              ? _SearchState(
                  icon: Icons.search_off_rounded,
                  title: 'search_empty_title'.tr(),
                  body: 'search_empty_type'.tr(),
                )
              : ListView.separated(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.fromLTRB(AppSpacing.screen, 0,
                      AppSpacing.screen, AppSpacing.xl + bottomInset),
                  itemCount: shown.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, i) =>
                      _ResultRow(media: shown[i], query: query),
                ),
        ),
      ],
    );
  }
}

class _ResultRow extends ConsumerWidget {
  const _ResultRow({required this.media, required this.query});

  final MediaModel media;
  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    final placement = ref.watch(watchlistPlacementProvider(media.id));
    final score = _score(context, media);
    final highlight = TextStyle(
      backgroundColor: c.accent.withValues(alpha: 0.28),
      color: c.text1,
    );

    final count = media.isManga
        ? (media.chapters == null
            ? null
            : 'meta_chapters'.tr(namedArgs: {'count': '${media.chapters}'}))
        : (media.episodes == null
            ? null
            : 'meta_episodes'.tr(namedArgs: {'count': '${media.episodes}'}));

    final meta = [
      if (score != null) '★ $score',
      if (score == null && media.status == 'NOT_YET_RELEASED')
        media.seasonYear == null
            ? 'detail_status_not_yet_released'.tr()
            : '${'detail_status_not_yet_released'.tr()} ${media.seasonYear}',
      ?count,
      media.isManga ? 'Manga' : 'Anime',
    ];

    return Material(
      color: c.surface1,
      borderRadius: BorderRadius.circular(AppRadius.card),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/detail/${media.id}',
            extra: {'coverUrl': media.coverImage}),
        child: Padding(
          padding: const EdgeInsets.all(11),
          child: Row(
            children: [
              SizedBox(
                width: 52,
                child: MediaCover(imageUrl: media.coverImage, radius: 9),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(children: [
                        for (final part
                            in highlightParts(media.displayTitle, query))
                          TextSpan(
                            text: part.text,
                            style: part.match ? highlight : null,
                          ),
                      ]),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleSmall
                          ?.copyWith(color: c.text1, fontSize: 13),
                    ),
                    const SizedBox(height: 5),
                    Text.rich(
                      TextSpan(children: [
                        for (var i = 0; i < meta.length; i++) ...[
                          if (i > 0) const TextSpan(text: ' · '),
                          TextSpan(
                            text: meta[i],
                            style: meta[i].startsWith('★')
                                ? TextStyle(color: c.star)
                                : null,
                          ),
                        ],
                      ]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall?.copyWith(
                          color: c.text2,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 5),
                    if (placement != null)
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: c.statusCurrent,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              'search_in_list'.tr(namedArgs: {
                                'status': placement.status.label,
                              }),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.labelMedium?.copyWith(
                                  color: c.statusCurrent, fontSize: 10.5),
                            ),
                          ),
                        ],
                      )
                    else if (media.genres != null && media.genres!.isNotEmpty)
                      Text(
                        media.genres!.take(3).join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodySmall
                            ?.copyWith(color: c.text3, fontSize: 10.5),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              if (placement?.favourite ?? false)
                SizedBox(
                  width: AppSpacing.minTouch,
                  height: AppSpacing.minTouch,
                  child: Icon(Icons.favorite_rounded,
                      size: 18, color: c.favourite),
                )
              else
                RoundIconButton(
                  icon: placement == null
                      ? Icons.add_rounded
                      : Icons.edit_outlined,
                  tooltip: placement == null
                      ? 'detail_add_to_watchlist'.tr()
                      : 'detail_edit'.tr(),
                  color: c.accentText,
                  onTap: () {
                    final user = ref.read(authProvider).valueOrNull?.user;
                    openWatchlistSheet(context, ref, anime: media, user: user);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── États vide / hors ligne ───────────────────────────────────────────────────

class _SearchState extends StatelessWidget {
  const _SearchState({
    required this.icon,
    required this.title,
    required this.body,
    this.danger = false,
    this.primaryLabel,
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  final IconData icon;
  final String title;
  final String body;
  final bool danger;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: danger
                    ? c.favourite.withValues(alpha: 0.12)
                    : c.surface1,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon,
                  size: 24, color: danger ? c.statusDroppedText : c.text3),
            ),
            const SizedBox(height: 12),
            Text(title,
                textAlign: TextAlign.center,
                style: text.headlineSmall
                    ?.copyWith(fontSize: 15.5, color: c.text1)),
            const SizedBox(height: 6),
            Text(body,
                textAlign: TextAlign.center,
                style: text.bodyMedium?.copyWith(color: c.text2, height: 1.55)),
            if (primaryLabel != null) ...[
              const SizedBox(height: AppSpacing.md),
              AppButton(
                  label: primaryLabel!, expand: true, onPressed: onPrimary),
            ],
            if (secondaryLabel != null) ...[
              const SizedBox(height: AppSpacing.xs),
              AppButton(
                label: secondaryLabel!,
                variant: AppButtonVariant.secondary,
                expand: true,
                onPressed: onSecondary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
