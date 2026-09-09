import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nextarc/features/auth/domain/auth_providers.dart';
import 'package:nextarc/features/auth/domain/user_model.dart';
import 'package:nextarc/features/detail/domain/detail_providers.dart';
import 'package:nextarc/features/discover/domain/media_model.dart';
import 'package:nextarc/features/share/presentation/share_media_sheet.dart';
import 'package:nextarc/features/reviews/domain/review_providers.dart';
import 'package:nextarc/features/watchlist/domain/firestore_watchlist_providers.dart';
import 'package:nextarc/features/watchlist/presentation/firestore_watchlist_edit_sheet.dart';
import 'package:nextarc/features/watchlist/presentation/guest_watchlist_edit_sheet.dart';
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
                    label: Text('action_retry'.tr()),
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

  void _openSheet({required UserModel? user}) {
    final totalCount = widget.anime.isManga
        ? widget.anime.chapters
        : widget.anime.episodes;

    if (user?.hasAnilist == true) {
      final entry = ref.read(userListEntryProvider(widget.anime.id));
      showWatchlistEditSheet(
        context,
        ref,
        animeId: widget.anime.id,
        animeTitle: widget.anime.displayTitle,
        totalEpisodes: totalCount,
        startDate: widget.anime.startDate,
        existing: entry,
        isManga: widget.anime.isManga,
      );
    } else if (user?.hasFirebase == true) {
      final firestoreEntry =
          ref.read(firestoreListEntryProvider(widget.anime.id));
      showFirestoreWatchlistEditSheet(
        context,
        ref,
        animeId: widget.anime.id,
        animeTitle: widget.anime.displayTitle,
        coverImage: widget.anime.coverImage,
        totalEpisodes: totalCount,
        existing: firestoreEntry,
        isManga: widget.anime.isManga,
      );
    } else {
      final guestEntry = ref.read(guestListEntryProvider(widget.anime.id));
      showGuestWatchlistEditSheet(
        context,
        ref,
        animeId: widget.anime.id,
        animeTitle: widget.anime.displayTitle,
        coverImage: widget.anime.coverImage,
        totalEpisodes: totalCount,
        existing: guestEntry,
        isManga: widget.anime.isManga,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final anime = widget.anime;
    final user = ref.watch(authProvider).whenOrNull<UserModel?>(
          data: (a) => a.user,
        );
    final userEntry =
        user?.hasAnilist == true ? ref.watch(userListEntryProvider(anime.id)) : null;
    final firestoreEntry =
        user?.hasFirebase == true && user?.hasAnilist != true
            ? ref.watch(firestoreListEntryProvider(anime.id))
            : null;
    final guestEntry =
        user == null ? ref.watch(guestListEntryProvider(anime.id)) : null;
    final hasEntry =
        userEntry != null || firestoreEntry != null || guestEntry != null;

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
            backgroundColor: hasEntry ? cs.primary : fabInactiveBg,
            onPressed: () => _openSheet(user: user),
            child: Icon(
              hasEntry ? Icons.bookmark : Icons.bookmark_add_outlined,
              color: hasEntry ? Colors.white : cs.primary,
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
            actions: [
              IconButton(
                icon: const Icon(Icons.ios_share_rounded),
                tooltip: 'share_media_title'.tr(),
                onPressed: () => showShareMediaSheet(context, anime),
              ),
            ],
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
                                if (!anime.isManga && anime.episodes != null)
                                  _InfoChip(
                                    icon: Icons.play_circle_outline,
                                    label: 'detail_episodes_count'.tr(
                                        namedArgs: {'count': '${anime.episodes}'}),
                                  ),
                                if (anime.isManga && anime.chapters != null)
                                  _InfoChip(
                                    icon: Icons.menu_book_outlined,
                                    label: 'detail_chapters_count'.tr(
                                        namedArgs: {'count': '${anime.chapters}'}),
                                  ),
                                if (anime.isManga &&
                                    anime.countryOfOrigin != null &&
                                    anime.countryOfOrigin != 'JP')
                                  _InfoChip(
                                    icon: Icons.public,
                                    label: anime.countryOfOrigin == 'KR'
                                        ? 'label_manhwa'.tr()
                                        : 'label_manhua'.tr(),
                                    color: Theme.of(context).colorScheme.primary,
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
                    Text(
                      'detail_synopsis'.tr(),
                      style: const TextStyle(
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
                  if (hasEntry) ...[
                    GestureDetector(
                      onTap: () => _openSheet(user: user),
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
                                    (userEntry?.status ??
                                                firestoreEntry?.status ??
                                                guestEntry?.status)
                                            ?.label ??
                                        'detail_in_list'.tr(),
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: cs.onPrimaryContainer),
                                  ),
                                  Text(
                                    (userEntry?.progressLabel ??
                                            firestoreEntry?.progressLabel ??
                                            guestEntry?.progressLabel ??
                                            '') +
                                        (() {
                                          final score = userEntry
                                                  ?.formattedScore ??
                                              firestoreEntry?.formattedScore ??
                                              guestEntry?.formattedScore;
                                          return score != null
                                              ? '  •  ⭐ $score'
                                              : '';
                                        })(),
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
                        label: Text('detail_add_to_watchlist'.tr()),
                        onPressed: () => _openSheet(user: user),
                      ),
                    ),
                  ],

                  // ── Note personnelle (Firebase uniquement) ────────────
                  if (user?.hasFirebase == true) ...[
                    const SizedBox(height: 16),
                    _PersonalNoteCard(
                      mediaId: anime.id,
                      uid: user!.firebaseUid!,
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
        'FINISHED' => 'detail_status_finished'.tr(),
        'RELEASING' => 'detail_status_releasing'.tr(),
        'NOT_YET_RELEASED' => 'detail_status_not_yet_released'.tr(),
        'CANCELLED' => 'detail_status_cancelled'.tr(),
        'HIATUS' => 'detail_status_hiatus'.tr(),
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

// ── Note personnelle (Firestore) ──────────────────────────────────────────────

class _PersonalNoteCard extends ConsumerWidget {
  const _PersonalNoteCard({required this.mediaId, required this.uid});

  final int mediaId;
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final noteAsync = ref.watch(reviewNoteProvider(mediaId));
    final cs = Theme.of(context).colorScheme;

    return noteAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (note) {
        final hasNote = note != null && note.isNotEmpty;
        return GestureDetector(
          onTap: () => _openNoteDialog(context, ref, current: note),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: hasNote
                  ? cs.secondaryContainer.withValues(alpha: 0.5)
                  : cs.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: hasNote
                    ? cs.secondary.withValues(alpha: 0.4)
                    : cs.onSurface.withValues(alpha: 0.12),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  hasNote ? Icons.sticky_note_2_rounded : Icons.note_add_outlined,
                  size: 18,
                  color: hasNote
                      ? cs.secondary
                      : cs.onSurface.withValues(alpha: 0.4),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: hasNote
                      ? Text(
                          note!,
                          style: TextStyle(
                            fontSize: 13,
                            color: cs.onSurface.withValues(alpha: 0.8),
                            height: 1.5,
                          ),
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                        )
                      : Text(
                          'detail_note_placeholder'.tr(),
                          style: TextStyle(
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                            color: cs.onSurface.withValues(alpha: 0.38),
                          ),
                        ),
                ),
                if (hasNote) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _deleteNote(context, ref),
                    child: Icon(
                      Icons.close,
                      size: 16,
                      color: cs.onSurface.withValues(alpha: 0.38),
                    ),
                  ),
                ] else ...[
                  Icon(
                    Icons.edit_outlined,
                    size: 14,
                    color: cs.onSurface.withValues(alpha: 0.3),
                  ),
                ],
              ],
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
    final cs = Theme.of(context).colorScheme;

    final saved = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('detail_note_dialog_title'.tr()),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 5,
          maxLength: 500,
          decoration: InputDecoration(
            hintText: 'detail_note_hint'.tr(),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: cs.primary),
            ),
          ),
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

  Future<void> _deleteNote(BuildContext context, WidgetRef ref) async {
    await ref.read(firestoreReviewRepositoryProvider).deleteNote(uid, mediaId);
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
