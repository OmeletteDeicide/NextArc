import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nextarc/core/services/notification_prefs_repository.dart';
import 'package:nextarc/core/services/notification_service.dart';
import 'package:nextarc/core/theme/app_tokens.dart';
import 'package:nextarc/core/widgets/ds/ds.dart';
import 'package:nextarc/features/auth/domain/auth_providers.dart';
import 'package:nextarc/features/auth/domain/user_model.dart';
import 'package:nextarc/features/detail/domain/detail_providers.dart';
import 'package:nextarc/features/detail/domain/synopsis.dart';
import 'package:nextarc/features/discover/domain/discover_hero.dart';
import 'package:nextarc/features/discover/domain/media_model.dart';
import 'package:nextarc/features/reviews/domain/review_providers.dart';
import 'package:nextarc/features/share/presentation/share_media_sheet.dart';
import 'package:nextarc/features/watchlist/domain/firestore_watchlist_providers.dart';
import 'package:nextarc/features/watchlist/domain/list_items.dart';
import 'package:nextarc/features/watchlist/domain/media_list_entry.dart';
import 'package:nextarc/features/watchlist/presentation/watchlist_sheet_helper.dart';

/// Hauteur du bandeau du haut (≤ 38 % de l'écran).
const double _heroHeight = 280;

/// Largeur de la jaquette posée sur le bandeau.
const double _heroCoverWidth = 84;

/// Écran fiche détaillée d'un anime ou d'un manga.
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

  /// URL de la jaquette passée depuis l'écran source (Hero pendant le chargement).
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
            final c = AppColors.of(context);
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline_rounded, size: 44, color: c.text3),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      error.toString(),
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
                      onPressed: () =>
                          ref.invalidate(animeDetailProvider(animeId)),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      data: (anime) => _DetailContent(anime: anime, heroTag: heroTag),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Note AniList formatée selon la langue (« 8,4 » en FR/ES).
String? _localizedScore(BuildContext context, MediaModel media) {
  final score = media.formattedScore;
  if (score == null) return null;
  return context.locale.languageCode == 'en'
      ? score
      : score.replaceAll('.', ',');
}

String _mediaStatusLabel(String status) => switch (status) {
      'FINISHED' => 'detail_status_finished'.tr(),
      'RELEASING' => 'detail_status_releasing'.tr(),
      'NOT_YET_RELEASED' => 'detail_status_not_yet_released'.tr(),
      'CANCELLED' => 'detail_status_cancelled'.tr(),
      'HIATUS' => 'detail_status_hiatus'.tr(),
      _ => status,
    };

Color _mediaStatusColor(String status, AppColors c) => switch (status) {
      'RELEASING' => c.statusCurrent,
      'FINISHED' => c.statusCompletedText,
      'NOT_YET_RELEASED' => c.star,
      'CANCELLED' => c.favourite,
      _ => c.text2,
    };

// ── Chargement ────────────────────────────────────────────────────────────────

class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton({this.heroTag, this.coverUrl});

  final String? heroTag;
  final String? coverUrl;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(
      body: Column(
        children: [
          SizedBox(
            height: _heroHeight,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (coverUrl != null)
                  CachedNetworkImage(
                    imageUrl: coverUrl!,
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                  )
                else
                  ColoredBox(color: c.surface2),
                const _HeroScrim(),
                Positioned(
                  left: AppSpacing.screen,
                  bottom: 14,
                  child: _HeroCover(url: coverUrl, heroTag: heroTag),
                ),
              ],
            ),
          ),
          const Expanded(
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
        ],
      ),
    );
  }
}

// ── Contenu ───────────────────────────────────────────────────────────────────

class _DetailContent extends ConsumerWidget {
  const _DetailContent({required this.anime, this.heroTag});

  final MediaModel anime;
  final String? heroTag;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    final user = ref.watch(authProvider).whenOrNull<UserModel?>(
          data: (a) => a.user,
        );

    final userEntry = user?.usesAnilistList == true
        ? ref.watch(userListEntryProvider(anime.id))
        : null;
    final firestoreEntry = user?.hasFirebase == true
        ? ref.watch(firestoreListEntryProvider(anime.id))
        : null;
    final guestEntry =
        user == null ? ref.watch(guestListEntryProvider(anime.id)) : null;
    final hasEntry =
        userEntry != null || firestoreEntry != null || guestEntry != null;

    final total = (anime.isManga ? anime.chapters : anime.episodes) ??
        firestoreEntry?.episodes ??
        guestEntry?.episodes;

    final synopsis =
        anime.description == null ? '' : cleanSynopsis(anime.description!);
    final nextEpisode = anime.isManga ? null : anime.nextAiringEpisode;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    void openSheet() =>
        openWatchlistSheet(context, ref, anime: anime, user: user);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _DetailHero(anime: anime, heroTag: heroTag),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.md,
                AppSpacing.screen, AppSpacing.xl + bottomInset),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                if (hasEntry)
                  _InListCard(
                    status: userEntry?.status ??
                        firestoreEntry?.status ??
                        guestEntry?.status,
                    progress: userEntry?.progress ??
                        firestoreEntry?.progress ??
                        guestEntry?.progress ??
                        0,
                    total: total,
                    aired: anime.airedEpisodes,
                    onEdit: openSheet,
                  )
                else
                  AppButton(
                    label: 'detail_add_to_watchlist'.tr(),
                    icon: Icons.add_rounded,
                    expand: true,
                    onPressed: openSheet,
                  ),

                // ── Genres ──────────────────────────────────────────────
                if (anime.genres != null && anime.genres!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      for (final genre in anime.genres!)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm, vertical: 7),
                          decoration: BoxDecoration(
                            color: c.surface2,
                            borderRadius:
                                BorderRadius.circular(AppRadius.chip),
                          ),
                          child: Text(
                            genre,
                            style: text.labelMedium?.copyWith(
                              color: c.text2,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],

                // ── Synopsis ────────────────────────────────────────────
                if (synopsis.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.lg),
                  SectionHeader(title: 'detail_synopsis'.tr()),
                  const SizedBox(height: AppSpacing.xs),
                  _Synopsis(text: synopsis),
                ],

                // ── Note perso (compte NextArc) ─────────────────────────
                if (user?.hasFirebase == true) ...[
                  const SizedBox(height: AppSpacing.lg),
                  SectionHeader(title: 'detail_my_note'.tr()),
                  const SizedBox(height: AppSpacing.xs),
                  _PersonalNoteCard(
                    mediaId: anime.id,
                    uid: user!.firebaseUid!,
                  ),
                ],

                // ── Prochain épisode ────────────────────────────────────
                if (nextEpisode != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  SectionHeader(title: 'detail_next_episode'.tr()),
                  const SizedBox(height: AppSpacing.xs),
                  _NextEpisodeCard(media: anime, next: nextEpisode),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Bandeau du haut ───────────────────────────────────────────────────────────

class _DetailHero extends StatelessWidget {
  const _DetailHero({required this.anime, this.heroTag});

  final MediaModel anime;
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    final topInset = MediaQuery.viewPaddingOf(context).top;
    final imageUrl = anime.bannerImage ?? anime.coverImage;
    final score = _localizedScore(context, anime);

    final count = anime.isManga
        ? (anime.chapters == null
            ? null
            : 'detail_chapters_count'
                .tr(namedArgs: {'count': '${anime.chapters}'}))
        : (anime.episodes == null
            ? null
            : 'detail_episodes_count'
                .tr(namedArgs: {'count': '${anime.episodes}'}));

    final metaStyle =
        text.bodySmall?.copyWith(color: c.text2, fontWeight: FontWeight.w600);

    return SizedBox(
      height: _heroHeight,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (imageUrl != null)
            CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              alignment: anime.bannerImage == null
                  ? Alignment.topCenter
                  : Alignment.center,
              placeholder: (_, _) => ColoredBox(color: c.surface2),
              errorWidget: (_, _, _) => ColoredBox(color: c.surface2),
            )
          else
            ColoredBox(color: c.surface2),
          const _HeroScrim(),
          Positioned(
            left: AppSpacing.md - 4,
            top: topInset + 4,
            child: _HeroButton(
              icon: Icons.arrow_back_rounded,
              tooltip: 'detail_back'.tr(),
              onTap: () => Navigator.of(context).maybePop(),
            ),
          ),
          Positioned(
            right: AppSpacing.md - 4,
            top: topInset + 4,
            child: _HeroButton(
              icon: Icons.ios_share_rounded,
              tooltip: 'share_media_title'.tr(),
              onTap: () => showShareMediaSheet(context, anime),
            ),
          ),
          Positioned(
            left: AppSpacing.screen,
            right: AppSpacing.screen,
            bottom: 14,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _HeroCover(url: anime.coverImage, heroTag: heroTag),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        anime.displayTitle,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: text.headlineSmall
                            ?.copyWith(fontSize: 19, color: c.text1),
                      ),
                      if (anime.titleEnglish != null &&
                          anime.titleRomaji.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          anime.titleRomaji,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodySmall?.copyWith(color: c.text2),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 9,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (score != null)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.star_rounded,
                                    size: 14, color: c.star),
                                const SizedBox(width: 2),
                                Text(score,
                                    style: metaStyle?.copyWith(color: c.star)),
                              ],
                            ),
                          if (count != null) Text(count, style: metaStyle),
                          if (anime.status != null)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color:
                                        _mediaStatusColor(anime.status!, c),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _mediaStatusLabel(anime.status!),
                                  style: metaStyle?.copyWith(
                                      color:
                                          _mediaStatusColor(anime.status!, c)),
                                ),
                              ],
                            ),
                          if (anime.isManga &&
                              anime.countryOfOrigin != null &&
                              anime.countryOfOrigin != 'JP')
                            Text(
                              anime.countryOfOrigin == 'KR'
                                  ? 'label_manhwa'.tr()
                                  : 'label_manhua'.tr(),
                              style: metaStyle?.copyWith(color: c.accentText),
                            ),
                        ],
                      ),
                    ],
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

/// Dégradé du bandeau vers le fond de l'écran (+ assombrissement en haut pour
/// les boutons).
class _HeroScrim extends StatelessWidget {
  const _HeroScrim();

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            c.base,
            c.base.withValues(alpha: isDark ? 0.35 : 0.15),
            isDark
                ? c.base.withValues(alpha: 0.55)
                : const Color(0x59141E3C),
          ],
          stops: const [0.06, 0.55, 1],
        ),
      ),
    );
  }
}

class _HeroCover extends StatelessWidget {
  const _HeroCover({required this.url, this.heroTag});

  final String? url;
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    Widget cover = Container(
      width: _heroCoverWidth,
      height: _heroCoverWidth * 1.5,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: const Color(0x1FFFFFFF)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: url == null
            ? ColoredBox(color: c.surface2)
            : CachedNetworkImage(imageUrl: url!, fit: BoxFit.cover),
      ),
    );
    if (heroTag != null) cover = Hero(tag: heroTag!, child: cover);
    return cover;
  }
}

/// Bouton rond sur pastille sombre, lisible sur n'importe quel visuel.
class _HeroButton extends StatelessWidget {
  const _HeroButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onTap,
        radius: 24,
        child: SizedBox(
          width: AppSpacing.minTouch,
          height: AppSpacing.minTouch,
          child: Center(
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xB3060A15)
                    : const Color(0x8C0C1226),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 20, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Carte « Dans ma liste » ───────────────────────────────────────────────────

class _InListCard extends StatelessWidget {
  const _InListCard({
    required this.status,
    required this.progress,
    required this.total,
    required this.onEdit,
    this.aired,
  });

  final ListStatus? status;
  final int progress;
  final int? total;

  /// Épisodes déjà sortis (série en cours sans total connu).
  final int? aired;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ceiling = progressCeiling(total: total, aired: aired);

    return Material(
      type: MaterialType.transparency,
      child: Ink(
        decoration: BoxDecoration(
          gradient: isDark
              ? LinearGradient(colors: [
                  c.accent.withValues(alpha: 0.16),
                  c.violet.withValues(alpha: 0.16),
                ])
              : null,
          color: isDark ? null : const Color(0xFFE9EDFC),
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(
            color: (isDark ? c.accentText : c.accent)
                .withValues(alpha: isDark ? 0.3 : 0.28),
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.card),
          onTap: onEdit,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'detail_in_my_list'.tr(namedArgs: {
                          'status': status?.label ?? 'detail_in_list'.tr(),
                        }),
                        style: text.titleSmall?.copyWith(color: c.text1),
                      ),
                      const SizedBox(height: 7),
                      Row(
                        children: [
                          Expanded(
                            child: ceiling != null
                                ? GradientProgressBar(
                                    value: (progress / ceiling)
                                        .clamp(0.0, 1.0)
                                        .toDouble(),
                                    height: 5)
                                : const SizedBox.shrink(),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            formatProgress(progress,
                                total: total, aired: aired),
                            style: text.labelSmall?.copyWith(
                              color: c.text2,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 13),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                  decoration: BoxDecoration(
                    color: isDark ? c.surface1 : Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text(
                    'detail_edit'.tr(),
                    style: text.labelMedium?.copyWith(
                        color: isDark ? c.text1 : c.accentText),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Synopsis replié ───────────────────────────────────────────────────────────

class _Synopsis extends StatefulWidget {
  const _Synopsis({required this.text});

  final String text;

  @override
  State<_Synopsis> createState() => _SynopsisState();
}

class _SynopsisState extends State<_Synopsis> {
  static const _collapsedLines = 3;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final style = Theme.of(context)
        .textTheme
        .bodyMedium
        ?.copyWith(color: c.text2, height: 1.65);

    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: style),
          maxLines: _collapsedLines,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: constraints.maxWidth);
        final overflows = painter.didExceedMaxLines;
        painter.dispose();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedSize(
              duration: AppMotion.transition,
              alignment: Alignment.topCenter,
              child: Text(
                widget.text,
                style: style,
                maxLines: _expanded ? null : _collapsedLines,
                overflow:
                    _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
              ),
            ),
            if (overflows)
              TextButton(
                onPressed: () => setState(() => _expanded = !_expanded),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, AppSpacing.minTouch),
                  foregroundColor: c.accentText,
                ),
                child: Text(
                  _expanded
                      ? 'detail_read_less'.tr()
                      : 'detail_read_more'.tr(),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ── Note personnelle (Firestore) ──────────────────────────────────────────────

class _PersonalNoteCard extends ConsumerWidget {
  const _PersonalNoteCard({required this.mediaId, required this.uid});

  final int mediaId;
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final noteAsync = ref.watch(reviewNoteProvider(mediaId));
    final c = AppColors.of(context);
    final text = Theme.of(context).textTheme;

    return noteAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (note) {
        final hasNote = note != null && note.isNotEmpty;
        return Material(
          color: c.surface1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.cover),
            side: BorderSide(
              color: hasNote ? c.border : c.text3.withValues(alpha: 0.35),
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.cover),
            onTap: () => _openNoteDialog(context, ref, current: note),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(13, 4, 4, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      child: Text(
                        hasNote ? note : 'detail_note_placeholder'.tr(),
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodyMedium?.copyWith(
                          color: hasNote ? c.text1 : c.text3,
                          fontStyle:
                              hasNote ? FontStyle.normal : FontStyle.italic,
                        ),
                      ),
                    ),
                  ),
                  if (hasNote)
                    IconButton(
                      icon: Icon(Icons.close_rounded, size: 18, color: c.text3),
                      tooltip: 'sheet_remove_button'.tr(),
                      onPressed: () => ref
                          .read(firestoreReviewRepositoryProvider)
                          .deleteNote(uid, mediaId),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      child:
                          Icon(Icons.edit_outlined, size: 16, color: c.text3),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openNoteDialog(
    BuildContext context,
    WidgetRef ref, {
    String? current,
  }) async {
    final controller = TextEditingController(text: current ?? '');

    final saved = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('detail_note_dialog_title'.tr()),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 5,
          maxLength: 500,
          decoration: InputDecoration(hintText: 'detail_note_hint'.tr()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('dialog_cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: Text('dialog_save'.tr()),
          ),
        ],
      ),
    );

    controller.dispose();
    if (saved == null) return;

    final repo = ref.read(firestoreReviewRepositoryProvider);
    if (saved.trim().isEmpty) {
      await repo.deleteNote(uid, mediaId);
    } else {
      await repo.saveNote(uid, mediaId, saved);
    }
  }
}

// ── Prochain épisode ──────────────────────────────────────────────────────────

class _NextEpisodeCard extends StatefulWidget {
  const _NextEpisodeCard({required this.media, required this.next});

  final MediaModel media;
  final NextAiringEpisode next;

  @override
  State<_NextEpisodeCard> createState() => _NextEpisodeCardState();
}

class _NextEpisodeCardState extends State<_NextEpisodeCard> {
  late bool _reminderOn =
      NotificationPrefsRepository.instance.isEnabled(widget.media.id);
  bool _busy = false;

  Future<void> _toggleReminder() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final prefs = NotificationPrefsRepository.instance;
      if (_reminderOn) {
        await prefs.disable(widget.media.id);
      } else {
        final granted = await NotificationService.instance.requestPermission();
        if (!granted) return;
        await prefs.enable(
          widget.media.id,
          title: widget.media.displayTitle,
          isManga: false,
          currentCount: widget.next.episode - 1,
        );
      }
      if (mounted) setState(() => _reminderOn = !_reminderOn);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    final locale = context.locale.toString();
    final airingAt = widget.next.airingAt.toLocal();

    final weekday =
        DateFormat.E(locale).format(airingAt).replaceAll('.', '').toUpperCase();
    final time = DateFormat.Hm(locale).format(airingAt);
    final delay = airingAt.difference(DateTime.now());
    final countdown =
        airingCountdown(delay.isNegative ? Duration.zero : delay);

    return Container(
      padding: const EdgeInsets.fromLTRB(13, 10, 8, 10),
      decoration: BoxDecoration(
        color: c.surface1,
        borderRadius: BorderRadius.circular(AppRadius.cover),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: c.surface2,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  weekday,
                  style: text.labelSmall?.copyWith(
                      fontSize: 9, color: c.text2, letterSpacing: 0.4),
                ),
                Text(
                  '${airingAt.day}',
                  style: text.titleMedium?.copyWith(height: 1.1),
                ),
              ],
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'detail_episode_number'
                      .tr(namedArgs: {'number': '${widget.next.episode}'}),
                  style: text.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  '${countdown.key.tr(namedArgs: {'count': '${countdown.count}'})} · $time',
                  style: text.bodySmall?.copyWith(color: c.text2),
                ),
              ],
            ),
          ),
          Semantics(
            button: true,
            toggled: _reminderOn,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.full),
              onTap: _busy ? null : _toggleReminder,
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(minHeight: AppSpacing.minTouch),
                child: Center(
                  widthFactor: 1,
                  child: AnimatedContainer(
                    duration: AppMotion.press,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: _reminderOn
                          ? c.accent.withValues(alpha: 0.16)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppRadius.full),
                      border: Border.all(
                        color: _reminderOn
                            ? Colors.transparent
                            : c.accentText.withValues(alpha: 0.45),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_reminderOn) ...[
                          Icon(Icons.check_rounded,
                              size: 14, color: c.accentText),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          _reminderOn
                              ? 'detail_reminder_on'.tr()
                              : 'detail_reminder'.tr(),
                          style: text.labelMedium?.copyWith(
                              color: c.accentText, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
