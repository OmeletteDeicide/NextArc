import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nextarc/core/router/app_router.dart';
import 'package:nextarc/core/theme/app_tokens.dart';
import 'package:nextarc/core/widgets/ds/ds.dart';
import 'package:nextarc/features/auth/domain/auth_providers.dart';
import 'package:nextarc/features/auth/domain/user_model.dart';
import 'package:nextarc/features/discover/domain/discover_providers.dart';
import 'package:nextarc/features/recommendations/domain/reco_providers.dart';
import 'package:nextarc/features/recommendations/domain/recommendation_model.dart';
import 'package:nextarc/features/watchlist/domain/in_watchlist_provider.dart';
import 'package:nextarc/features/watchlist/presentation/watchlist_sheet_helper.dart';

/// Écran « Pour toi » : recommandations anime / manga.
class RecommendationsScreen extends ConsumerStatefulWidget {
  const RecommendationsScreen({super.key});

  @override
  ConsumerState<RecommendationsScreen> createState() =>
      _RecommendationsScreenState();
}

class _RecommendationsScreenState extends ConsumerState<RecommendationsScreen> {
  late bool _isManga = ref.read(contentPreferenceProvider) == 'MANGA';

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── En-tête (même gabarit que Ma liste) ─────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screen, AppSpacing.xs, AppSpacing.screen - 4, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text('nav_for_you'.tr(),
                        style: text.headlineMedium?.copyWith(color: c.text1)),
                  ),
                  RoundIconButton(
                    icon: Icons.search_rounded,
                    tooltip: 'search_hint'.tr(),
                    onTap: () => context.push(AppRoutes.search),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
              child: SegmentedControl<bool>(
                segments: const [
                  (value: false, label: 'Anime'),
                  (value: true, label: 'Manga'),
                ],
                selected: _isManga,
                onChanged: (v) => setState(() => _isManga = v),
              ),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: AppMotion.transition,
                child: _isManga
                    ? const _RecoTab(key: ValueKey('manga'), isManga: true)
                    : const _RecoTab(key: ValueKey('anime'), isManga: false),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Onglet ────────────────────────────────────────────────────────────────────

class _RecoTab extends ConsumerWidget {
  const _RecoTab({super.key, required this.isManga});

  final bool isManga;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider =
        isManga ? mangaRecommendationsProvider : recommendationsProvider;
    final recoAsync = ref.watch(provider);
    final user = ref.watch(authProvider).whenOrNull<UserModel?>(
          data: (a) => a.user,
        );

    return recoAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _RecoError(
        message: e.toString(),
        onRetry: () => ref.invalidate(provider),
      ),
      data: (feed) => _RecoList(
        feed: feed,
        user: user,
        onRetry: () => ref.invalidate(provider),
        hintText: isManga
            ? 'reco_banner_no_data_manga'.tr()
            : 'reco_banner_no_data_anime'.tr(),
      ),
    );
  }
}

// ── Liste de recommandations ──────────────────────────────────────────────────

class _RecoList extends ConsumerWidget {
  const _RecoList({
    required this.feed,
    required this.user,
    required this.onRetry,
    required this.hintText,
  });

  final RecoFeed feed;
  final UserModel? user;
  final VoidCallback onRetry;

  /// Invite à ajouter des ❤️ ou des notes, affiché tant que les recos
  /// ne sont pas personnalisées.
  final String hintText;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recos = feed.items;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return RefreshIndicator(
      onRefresh: () async => onRetry(),
      child: ListView.separated(
        padding: EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.sm,
            AppSpacing.screen, AppSpacing.xl + bottomInset),
        itemCount: recos.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, index) {
          if (index == 0) {
            return feed.isPersonalised
                ? const SizedBox.shrink()
                : _InfoBanner(text: hintText);
          }
          final item = recos[index - 1];
          return _RecoCard(
            item: item,
            index: index - 1,
            isFallback: !feed.isPersonalised,
            onWatchlistTap: () => openWatchlistSheet(context, ref,
                anime: item.recommended, user: user),
          );
        },
      ),
    );
  }
}

// ── Carte recommandation ──────────────────────────────────────────────────────

/// La recommandation d'abord (titre, note, genres) ; la raison « parce que
/// tu as aimé » en petit dessous, pour ne pas voler la vedette.
class _RecoCard extends ConsumerWidget {
  const _RecoCard({
    required this.item,
    required this.index,
    required this.isFallback,
    required this.onWatchlistTap,
  });

  final RecommendationItem item;
  final int index;
  final bool isFallback;
  final VoidCallback onWatchlistTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    final media = item.recommended;
    final inList = ref.watch(inWatchlistProvider(media.id));
    final heroTag = 'reco_${media.isManga ? 'm' : 'a'}_$index';

    final score = media.formattedScore == null
        ? null
        : context.locale.languageCode == 'en'
            ? media.formattedScore!
            : media.formattedScore!.replaceAll('.', ',');
    final count = media.isManga
        ? (media.chapters == null
            ? null
            : 'meta_chapters'.tr(namedArgs: {'count': '${media.chapters}'}))
        : (media.episodes == null
            ? null
            : 'meta_episodes'.tr(namedArgs: {'count': '${media.episodes}'}));

    return Material(
      color: c.surface1,
      borderRadius: BorderRadius.circular(AppRadius.card),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/detail/${media.id}',
            extra: {'heroTag': heroTag, 'coverUrl': media.coverImage}),
        child: Padding(
          padding: const EdgeInsets.all(11),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 76,
                child: MediaCover(
                  imageUrl: media.coverImage,
                  radius: 10,
                  heroTag: heroTag,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      media.displayTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleMedium?.copyWith(color: c.text1),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (score != null) ...[
                          Icon(Icons.star_rounded, size: 14, color: c.star),
                          const SizedBox(width: 2),
                          Text(score,
                              style: text.bodySmall?.copyWith(
                                  color: c.star,
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(width: AppSpacing.xs),
                        ],
                        if (count != null)
                          Text(count,
                              style:
                                  text.bodySmall?.copyWith(color: c.text2)),
                      ],
                    ),
                    if (media.genres != null && media.genres!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        media.genres!.take(3).join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodySmall?.copyWith(color: c.text3),
                      ),
                    ],
                    if (!isFallback && item.sourceTitle.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        children: [
                          Icon(Icons.favorite_rounded,
                              size: 11, color: c.favourite),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text.rich(
                              TextSpan(children: [
                                TextSpan(
                                    text:
                                        '${'reco_because_you_liked'.tr()} '),
                                TextSpan(
                                  text: item.sourceTitle,
                                  style: TextStyle(color: c.text2),
                                ),
                              ]),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.bodySmall
                                  ?.copyWith(color: c.text3, fontSize: 10.5),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              // Ajouter / modifier dans la liste (zone tactile 44 px)
              Tooltip(
                message: inList
                    ? 'detail_edit'.tr()
                    : 'detail_add_to_watchlist'.tr(),
                child: InkResponse(
                  radius: 24,
                  onTap: onWatchlistTap,
                  child: SizedBox(
                    width: AppSpacing.minTouch,
                    height: AppSpacing.minTouch,
                    child: Center(
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: inList ? null : c.accentGradient,
                          color: inList ? c.surface2 : null,
                        ),
                        child: Icon(
                          inList ? Icons.check_rounded : Icons.add_rounded,
                          size: 18,
                          color: inList ? c.statusCurrent : Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Bannière et erreur ────────────────────────────────────────────────────────

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: c.surface1,
        borderRadius: BorderRadius.circular(AppRadius.cover),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          Icon(Icons.favorite_border_rounded, size: 16, color: c.favourite),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: c.text2),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecoError extends StatelessWidget {
  const _RecoError({required this.message, required this.onRetry});

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
