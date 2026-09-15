import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nextarc/core/constants/app_links.dart';
import 'package:nextarc/core/theme/app_tokens.dart';
import 'package:nextarc/core/theme/app_typography.dart';
import 'package:nextarc/core/theme/zigzag_background.dart';
import 'package:nextarc/core/widgets/ds/ds.dart';
import 'package:nextarc/features/activity/domain/activity_providers.dart';
import 'package:nextarc/features/activity/domain/month_activity.dart';
import 'package:nextarc/features/auth/domain/auth_providers.dart';
import 'package:nextarc/features/share/domain/share_card_data.dart';
import 'package:nextarc/features/share/domain/share_providers.dart';
import 'package:nextarc/features/stats/domain/month_story.dart';
import 'package:nextarc/features/stats/domain/stats_model.dart';
import 'package:nextarc/features/stats/domain/stats_provider.dart';
import 'package:nextarc/features/stats/domain/user_title.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Les cartes de partage sont toujours sombres, quel que soit le thème.
const AppColors _card = AppColors.dark;

class ShareStatsScreen extends ConsumerWidget {
  const ShareStatsScreen({super.key, this.openPreviousMonth = false});

  /// Ouvre directement la carte récap du mois précédent (message de début
  /// de mois).
  final bool openPreviousMonth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(statsProvider);
    final c = AppColors.of(context);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screen - 4, AppSpacing.xs, AppSpacing.screen, 0),
              child: Row(
                children: [
                  Tooltip(
                    message:
                        MaterialLocalizations.of(context).backButtonTooltip,
                    child: InkResponse(
                      radius: 24,
                      onTap: () => context.canPop()
                          ? context.pop()
                          : context.go('/profile'),
                      child: SizedBox(
                        width: AppSpacing.minTouch,
                        height: AppSpacing.minTouch,
                        child: Center(
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                                color: c.surface2, shape: BoxShape.circle),
                            child: Icon(Icons.arrow_back_rounded,
                                size: 18, color: c.text2),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'share_stats_title'.tr(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.headlineSmall
                          ?.copyWith(fontSize: 19, color: c.text1),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: statsAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Text(e.toString(),
                        textAlign: TextAlign.center,
                        style: text.bodyMedium?.copyWith(color: c.text2)),
                  ),
                ),
                data: (stats) => _ShareBody(
                    stats: stats, openPreviousMonth: openPreviousMonth),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Identité affichée sur les cartes (selon les interrupteurs) ────────────────

class _ShareIdentity {
  const _ShareIdentity({
    required this.title,
    required this.showTitle,
    required this.showCrown,
    this.avatarUrl,
    this.name,
  });

  final UserTitle title;
  final bool showTitle;

  /// Couronne affichée (Arcer uniquement).
  final bool showCrown;

  /// Photo et pseudo, uniquement si l'utilisateur les a activés.
  final String? avatarUrl;
  final String? name;

  bool get isVisible => showTitle || avatarUrl != null;
}

// ── Corps principal : carrousel de cartes + options ───────────────────────────

class _ShareBody extends ConsumerStatefulWidget {
  const _ShareBody({required this.stats, required this.openPreviousMonth});
  final StatsModel stats;
  final bool openPreviousMonth;

  @override
  ConsumerState<_ShareBody> createState() => _ShareBodyState();
}

class _ShareBodyState extends ConsumerState<_ShareBody> {
  final _pageController = PageController();

  /// Une clé de capture par carte possible (stats, préférés, 2 récaps).
  final _cardKeys = List.generate(4, (_) => GlobalKey());
  int _page = 0;
  bool _sharing = false;
  bool _jumpedToPreviousMonth = false;

  bool _showTitle = true;
  bool _showPhoto = false; // vie privée : désactivé par défaut
  bool _showCrown = true;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _share({
    required int page,
    required List<String> imageUrls,
    required String text,
  }) async {
    if (_sharing) return;
    setState(() => _sharing = true);

    try {
      // Les images réseau doivent être chargées avant la capture
      await Future.wait(imageUrls.map(
        (url) => precacheImage(CachedNetworkImageProvider(url), context),
      ));
      await Future.delayed(const Duration(milliseconds: 150));

      final boundary = _cardKeys[page].currentContext!.findRenderObject()
          as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/nextarc_share_$page.png');
      await file.writeAsBytes(pngBytes);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        text: '$text\n${AppLinks.playStore}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('share_error'.tr())),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final user = ref.watch(authProvider).whenOrNull(data: (a) => a.user);
    final favourites =
        ref.watch(shareFavouritesProvider).whenOrNull(data: (f) => f) ??
            const <FavouriteCover>[];
    final collage = favourites.take(collageSize(favourites.length)).toList();

    final title = widget.stats.title;
    final avatarUrl = user?.avatar;
    final identity = _ShareIdentity(
      title: title,
      showTitle: _showTitle,
      showCrown: title.isArcer && _showCrown,
      avatarUrl: _showPhoto ? avatarUrl : null,
      name: _showPhoto ? user?.displayName : null,
    );

    // Récaps : mois en cours, et mois précédent (complet) en début de mois
    final now = DateTime.now();
    MonthlyRecap? recapOf(String month) => ref
        .watch(monthlyRecapProvider(month))
        .whenOrNull(data: (r) => r.isEmpty ? null : r);
    final previousRecap = now.day <= 7 || widget.openPreviousMonth
        ? recapOf(previousMonthKey(now))
        : null;
    final currentRecap = recapOf(monthKey(now));
    final localizations = MaterialLocalizations.of(context);

    _ShareCard recapCard(MonthlyRecap recap, {required bool previous}) {
      final month = localizations.formatMonthYear(recap.date);
      return (
        card: _RecapCard(recap: recap, identity: identity),
        images: _recapCovers(recap).map((c) => c.coverUrl).toList(),
        text: 'share_recap_text'.tr(namedArgs: {'month': month}),
        isPreviousMonth: previous,
      );
    }

    final cards = <_ShareCard>[
      (
        card: _StatsCard(stats: widget.stats, identity: identity),
        images: [
          ?widget.stats.bestAnime?.media.coverImage,
          ?widget.stats.bestManga?.media.coverImage,
        ],
        text: 'share_stats_text'.tr(),
        isPreviousMonth: false,
      ),
      if (collage.isNotEmpty)
        (
          card: _FavouritesCard(
              covers: collage, total: favourites.length, identity: identity),
          images: collage.map((c) => c.coverUrl).toList(),
          text: 'share_favourites_text'.tr(),
          isPreviousMonth: false,
        ),
      if (previousRecap != null) recapCard(previousRecap, previous: true),
      if (currentRecap != null) recapCard(currentRecap, previous: false),
    ];
    final page = math.min(_page, cards.length - 1);

    // Arrivée depuis le message de début de mois : carte du mois précédent
    if (widget.openPreviousMonth && !_jumpedToPreviousMonth) {
      final index = cards.indexWhere((c) => c.isPreviousMonth);
      if (index > 0) {
        _jumpedToPreviousMonth = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_pageController.hasClients) _pageController.jumpToPage(index);
        });
      }
    }

    final imageUrls = [?identity.avatarUrl, ...cards[page].images];

    return Column(
      children: [
        // ── Aperçu des cartes ─────────────────────────────────────────────
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: cards.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (_, i) => Center(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
                child:
                    RepaintBoundary(key: _cardKeys[i], child: cards[i].card),
              ),
            ),
          ),
        ),

        if (cards.length > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < cards.length; i++)
                  AnimatedContainer(
                    duration: AppMotion.transition,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == page ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i == page ? c.accentText : c.text3,
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                  ),
              ],
            ),
          ),

        // ── Options ───────────────────────────────────────────────────────
        _OptionSwitch(
          label: 'share_option_title'.tr(),
          value: _showTitle,
          onChanged: (v) => setState(() => _showTitle = v),
        ),
        if (avatarUrl != null)
          _OptionSwitch(
            label: 'share_option_photo'.tr(),
            value: _showPhoto,
            onChanged: (v) => setState(() => _showPhoto = v),
          ),
        if (title.isArcer)
          _OptionSwitch(
            label: 'share_option_crown'.tr(),
            value: _showCrown,
            onChanged: (v) => setState(() => _showCrown = v),
          ),

        // ── Bouton partager ───────────────────────────────────────────────
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.screen, AppSpacing.xs, AppSpacing.screen, 16),
            child: AppButton(
              label: 'share_stats_button'.tr(),
              icon: Icons.ios_share_rounded,
              expand: true,
              loading: _sharing,
              onPressed: () => _share(
                page: page,
                imageUrls: imageUrls,
                text: cards[page].text,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Une carte du carrousel : widget, images à précharger, texte de partage.
typedef _ShareCard = ({
  Widget card,
  List<String> images,
  String text,
  bool isPreviousMonth,
});

/// Jaquettes mises en avant dans un récap.
List<FavouriteCover> _recapCovers(MonthlyRecap recap) => [
      for (final item in recap.highlights)
        if (item.coverImage != null)
          FavouriteCover(
            coverUrl: item.coverImage!,
            title: item.title,
            score: item.score,
          ),
    ].take(3).toList();

class _OptionSwitch extends StatelessWidget {
  const _OptionSwitch({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return SwitchListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.screen + 4),
      title: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(color: c.text1),
      ),
      value: value,
      onChanged: onChanged,
    );
  }
}

// ── Carte récap du mois ───────────────────────────────────────────────────────

class _RecapCard extends StatelessWidget {
  const _RecapCard({required this.recap, required this.identity});

  final MonthlyRecap recap;
  final _ShareIdentity identity;

  @override
  Widget build(BuildContext context) {
    final locale = context.locale.toString();
    final covers = _recapCovers(recap);
    final showChapters = recap.episodesWatched == 0 && recap.chaptersRead > 0;

    return _CardFrame(
      identity: identity,
      stamp: DateFormat.yMMM(locale).format(recap.date).toUpperCase(),
      content: (w, h) => [
        _CardOverline(
          'share_overline_month'.tr(namedArgs: {
            'month': DateFormat.MMMM(locale).format(recap.date),
          }),
          w: w,
        ),
        SizedBox(height: w * 0.025),
        _CardHero(
          '${heroDuration(recap.watchTimeMinutes + recap.readTimeMinutes)}\n'
          '${'share_hero_tail'.tr()}',
          w: w,
        ),
        SizedBox(height: h * 0.028),
        _CardStatsRow(
          w: w,
          items: [
            (
              value: '${showChapters ? recap.chaptersRead : recap.episodesWatched}',
              label: showChapters
                  ? 'share_card_chapters'.tr()
                  : 'share_card_episodes'.tr(),
              color: null,
            ),
            (
              value: formatCardScore(
                meanScoreOf(recap.highlights.map((i) => i.score)),
                languageCode: context.locale.languageCode,
              ),
              label: 'share_stat_mean'.tr(),
              color: _card.star,
            ),
            (
              value: '${recap.completed}',
              label: 'share_card_completed'.tr(),
              color: null,
            ),
          ],
        ),
        if (covers.isNotEmpty) ...[
          SizedBox(height: h * 0.028),
          _CardOverline('share_top_month'.tr(), w: w),
          SizedBox(height: w * 0.025),
          Expanded(child: _RankedCovers(covers: covers, w: w)),
        ] else
          const Spacer(),
      ],
    );
  }
}

// ── Carte stats (cumul total) ─────────────────────────────────────────────────

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.stats, required this.identity});

  final StatsModel stats;
  final _ShareIdentity identity;

  @override
  Widget build(BuildContext context) {
    final numbers = NumberFormat.decimalPattern(context.locale.toString());
    final best = [
      if (stats.bestAnime?.media.coverImage != null)
        FavouriteCover(
          coverUrl: stats.bestAnime!.media.coverImage!,
          title: stats.bestAnime!.media.displayTitle,
          score: stats.bestAnime!.score,
        ),
      if (stats.bestManga?.media.coverImage != null)
        FavouriteCover(
          coverUrl: stats.bestManga!.media.coverImage!,
          title: stats.bestManga!.media.displayTitle,
          score: stats.bestManga!.score,
        ),
    ];

    return _CardFrame(
      identity: identity,
      stamp: 'share_stamp_total'.tr().toUpperCase(),
      content: (w, h) => [
        _CardOverline('share_overline_stats'.tr(), w: w),
        SizedBox(height: w * 0.025),
        _CardHero(
          '${heroDuration(stats.watchTimeMinutes + stats.readTimeMinutes)}\n'
          '${'share_hero_tail'.tr()}',
          w: w,
        ),
        SizedBox(height: h * 0.028),
        _CardStatsRow(
          w: w,
          items: [
            (
              value: numbers.format(stats.episodesWatched),
              label: 'share_card_episodes'.tr(),
              color: null,
            ),
            (
              value: formatCardScore(stats.meanScore,
                  languageCode: context.locale.languageCode),
              label: 'share_stat_mean'.tr(),
              color: _card.star,
            ),
            (
              value: numbers.format(stats.animeCompleted + stats.mangaCompleted),
              label: 'share_card_completed'.tr(),
              color: null,
            ),
          ],
        ),
        if (best.isNotEmpty) ...[
          SizedBox(height: h * 0.028),
          _CardOverline('share_best_scores'.tr(), w: w),
          SizedBox(height: w * 0.025),
          Expanded(child: _RankedCovers(covers: best, w: w, slots: 3)),
        ] else if (stats.topGenres.isNotEmpty) ...[
          SizedBox(height: h * 0.028),
          _CardOverline('share_card_genres'.tr(), w: w),
          SizedBox(height: w * 0.025),
          _CardGenres(genres: stats.topGenres, w: w),
          const Spacer(),
        ] else
          const Spacer(),
      ],
    );
  }
}

// ── Carte « Mes préférés » ─────────────────────────────────────────────────────

class _FavouritesCard extends StatelessWidget {
  const _FavouritesCard({
    required this.covers,
    required this.total,
    required this.identity,
  });

  final List<FavouriteCover> covers;
  final int total;
  final _ShareIdentity identity;

  @override
  Widget build(BuildContext context) {
    return _CardFrame(
      identity: identity,
      stamp: DateFormat.yMMM(context.locale.toString())
          .format(DateTime.now())
          .toUpperCase(),
      content: (w, h) => [
        _CardOverline('share_card_favourites'.tr(), w: w),
        SizedBox(height: w * 0.025),
        _CardHero(
          total == 1
              ? 'share_fav_count_one'.tr()
              : 'share_fav_count'.tr(namedArgs: {'count': '$total'}),
          w: w,
        ),
        SizedBox(height: h * 0.03),
        Expanded(child: _CoverCollage(covers: covers, w: w)),
      ],
    );
  }
}

// ── Cadre commun des cartes (fond, en-tête, identité, pied) ───────────────────

class _CardFrame extends StatelessWidget {
  const _CardFrame({
    required this.identity,
    required this.stamp,
    required this.content,
  });

  final _ShareIdentity identity;

  /// Repère en haut à droite (« SEPT. 2026 », « TOTAL »).
  final String stamp;

  /// Contenu entre l'en-tête et le pied ; doit contenir un élément flexible
  /// (Spacer / Expanded) pour occuper la hauteur restante.
  final List<Widget> Function(double w, double h) content;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 9 / 16,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;

          return ClipRRect(
            borderRadius: BorderRadius.circular(w * 0.05),
            child: Stack(
              children: [
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment(-0.17, -1),
                        end: Alignment(0.17, 1),
                        colors: [
                          Color(0xFF141A38),
                          Color(0xFF0A0F22),
                          Color(0xFF060A15),
                        ],
                        stops: [0, 0.45, 1],
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: ZigzagBackground(
                    color: _card.violet,
                    opacity: 0.38,
                    alwaysVisible: true,
                    child: const SizedBox.expand(),
                  ),
                ),
                Positioned(
                  right: -w * 0.17,
                  top: -w * 0.15,
                  child: Container(
                    width: w * 0.72,
                    height: w * 0.72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          _card.violet.withValues(alpha: 0.5),
                          _card.violet.withValues(alpha: 0),
                        ],
                        stops: const [0, 0.68],
                      ),
                    ),
                  ),
                ),
                // Zone de sécurité 9:16 : rien à moins de ~180 px (sur 1920)
                // des bords haut et bas, où Instagram pose son interface
                Padding(
                  padding: EdgeInsets.fromLTRB(
                      w * 0.07, h * 0.094, w * 0.07, h * 0.094),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _CardHeader(stamp: stamp, w: w),
                      SizedBox(height: h * 0.03),
                      ...content(w, h),
                      SizedBox(height: h * 0.022),
                      _CardFooter(identity: identity, w: w),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CardHeader extends StatelessWidget {
  const _CardHeader({required this.stamp, required this.w});

  final String stamp;
  final double w;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(w * 0.022),
          child: Image.asset(
            'assets/images/logo.png',
            width: w * 0.079,
            height: w * 0.079,
            fit: BoxFit.cover,
          ),
        ),
        SizedBox(width: w * 0.025),
        Text(
          'NextArc',
          style: TextStyle(
            fontFamily: AppTypography.bodyFamily,
            color: const Color(0xFFC3CDEA),
            fontWeight: FontWeight.w700,
            fontSize: w * 0.032,
            letterSpacing: w * 0.0006,
          ),
        ),
        const Spacer(),
        Text(
          stamp,
          style: AppTypography.overline(const Color(0xFF7B88AE))
              .copyWith(fontSize: w * 0.026, letterSpacing: 0),
        ),
      ],
    );
  }
}

class _CardOverline extends StatelessWidget {
  const _CardOverline(this.text, {required this.w});

  final String text;
  final double w;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppTypography.overline(const Color(0xFF8B9AC6))
          .copyWith(fontSize: w * 0.027, letterSpacing: w * 0.0043),
    );
  }
}

/// Grand texte en Archivo Black (« 9 H 36 / DE VIE / EN PLUS. »).
class _CardHero extends StatelessWidget {
  const _CardHero(this.text, {required this.w});

  final String text;
  final double w;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.displayLarge?.copyWith(
              fontSize: w * 0.128,
              height: 0.92,
              letterSpacing: -w * 0.0044,
              color: const Color(0xFFF7F9FF),
            ),
      ),
    );
  }
}

typedef _CardStat = ({String value, String label, Color? color});

class _CardStatsRow extends StatelessWidget {
  const _CardStatsRow({required this.items, required this.w});

  final List<_CardStat> items;
  final double w;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return IntrinsicHeight(
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: w * 0.035),
                child: Container(
                  width: 1,
                  color: Colors.white.withValues(alpha: 0.14),
                ),
              ),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      items[i].value,
                      maxLines: 1,
                      style: text.titleLarge?.copyWith(
                        fontSize: w * 0.064,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -w * 0.0022,
                        color: items[i].color ?? const Color(0xFFF7F9FF),
                      ),
                    ),
                  ),
                  SizedBox(height: w * 0.005),
                  Text(
                    items[i].label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppTypography.bodyFamily,
                      fontSize: w * 0.026,
                      fontWeight: FontWeight.w600,
                      color: _card.text2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Jaquettes numérotées « 01 · 02 · 03 », dimensionnées à la place restante.
class _RankedCovers extends StatelessWidget {
  const _RankedCovers({required this.covers, required this.w, this.slots = 3});

  final List<FavouriteCover> covers;
  final double w;

  /// Nombre de colonnes réservées (garde la taille des jaquettes stable).
  final int slots;

  @override
  Widget build(BuildContext context) {
    final rankStyle = Theme.of(context).textTheme.displayLarge?.copyWith(
      fontSize: w * 0.042,
      height: 1,
      color: Colors.white,
      shadows: const [Shadow(color: Color(0x99000000), blurRadius: 6)],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final gap = w * 0.027;
        final cellWidth = math.min(
          (constraints.maxWidth - gap * (slots - 1)) / slots,
          constraints.maxHeight / 1.5,
        );
        final cellHeight = cellWidth * 1.5;

        return Align(
          alignment: Alignment.topLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < covers.length; i++) ...[
                if (i > 0) SizedBox(width: gap),
                ClipRRect(
                  borderRadius: BorderRadius.circular(w * 0.03),
                  child: SizedBox(
                    width: cellWidth,
                    height: cellHeight,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CachedNetworkImage(
                          imageUrl: covers[i].coverUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, _) =>
                              ColoredBox(color: _card.surface2),
                          errorWidget: (_, _, _) =>
                              ColoredBox(color: _card.surface2),
                        ),
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0x66000000), Color(0x00000000)],
                              stops: [0, 0.35],
                            ),
                          ),
                        ),
                        Positioned(
                          left: w * 0.02,
                          top: w * 0.02,
                          child: Text(coverRank(i), style: rankStyle),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Mosaïque de jaquettes (lignes de 3), dimensionnée pour tenir dans la carte.
class _CoverCollage extends StatelessWidget {
  const _CoverCollage({required this.covers, required this.w});

  final List<FavouriteCover> covers;
  final double w;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const columns = 3;
        const coverRatio = 1.5; // hauteur / largeur d'une jaquette
        final rows = (covers.length / columns).ceil();
        final gap = w * 0.025;

        final maxCellWidth =
            (constraints.maxWidth - gap * (columns - 1)) / columns;
        final maxCellHeight =
            (constraints.maxHeight - gap * (rows - 1)) / rows;
        final cellHeight = math.min(maxCellWidth * coverRatio, maxCellHeight);
        final cellWidth = cellHeight / coverRatio;

        return Align(
          alignment: Alignment.topCenter,
          child: Wrap(
            spacing: gap,
            runSpacing: gap,
            alignment: WrapAlignment.center,
            children: [
              for (final cover in covers)
                ClipRRect(
                  borderRadius: BorderRadius.circular(w * 0.025),
                  child: SizedBox(
                    width: cellWidth,
                    height: cellHeight,
                    child: CachedNetworkImage(
                      imageUrl: cover.coverUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => ColoredBox(color: _card.surface2),
                      errorWidget: (_, _, _) =>
                          ColoredBox(color: _card.surface2),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _CardGenres extends StatelessWidget {
  const _CardGenres({required this.genres, required this.w});

  final List<GenreStat> genres;
  final double w;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: w * 0.02,
      runSpacing: w * 0.018,
      children: [
        for (final g in genres.take(4))
          Container(
            padding: EdgeInsets.symmetric(
                horizontal: w * 0.035, vertical: w * 0.018),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(w * 0.02),
            ),
            child: Text(
              g.name,
              style: TextStyle(
                fontFamily: AppTypography.bodyFamily,
                color: _card.text1,
                fontSize: w * 0.032,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}

// ── Pied : identité + « Dispo sur Google Play » ───────────────────────────────

class _CardFooter extends StatelessWidget {
  const _CardFooter({required this.identity, required this.w});

  final _ShareIdentity identity;
  final double w;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = identity.avatarUrl;
    final title = identity.title;
    final titleColor = title.isArcer ? _card.star : const Color(0xFFB9A0FF);

    final Widget left;
    if (!identity.isVisible) {
      left = Text(
        'NextArc',
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontSize: w * 0.042,
              fontWeight: FontWeight.w800,
              color: const Color(0xFFF7F9FF),
            ),
      );
    } else {
      left = Row(
        children: [
          if (avatarUrl != null) ...[
            Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: w * 0.054,
                  backgroundColor: _card.surface2,
                  backgroundImage: CachedNetworkImageProvider(avatarUrl),
                ),
                if (identity.showCrown)
                  Positioned(
                    top: -w * 0.03,
                    right: -w * 0.025,
                    child: Transform.rotate(
                      angle: 0.35,
                      child: Text('👑',
                          style: TextStyle(fontSize: w * 0.045, height: 1)),
                    ),
                  ),
              ],
            ),
            SizedBox(width: w * 0.03),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (identity.name != null)
                  Text(
                    identity.name!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppTypography.bodyFamily,
                      color: const Color(0xFFF7F9FF),
                      fontWeight: FontWeight.w800,
                      fontSize: w * 0.035,
                    ),
                  ),
                if (identity.showTitle) ...[
                  if (identity.name != null) SizedBox(height: w * 0.01),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Sans photo, la couronne accompagne le titre
                      if (identity.showCrown && avatarUrl == null) ...[
                        Text('👑', style: TextStyle(fontSize: w * 0.028)),
                        SizedBox(width: w * 0.012),
                      ],
                      Flexible(
                        child: Text(
                          title.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: AppTypography.bodyFamily,
                            color: titleColor,
                            fontWeight: FontWeight.w700,
                            fontSize: w * 0.029,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      );
    }

    return Container(
      padding: EdgeInsets.only(top: w * 0.04),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
        ),
      ),
      child: Row(
        children: [
          Expanded(child: left),
          SizedBox(width: w * 0.02),
          Container(
            padding: EdgeInsets.symmetric(
                horizontal: w * 0.035, vertical: w * 0.025),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F9FF),
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: Text(
              'share_card_store'.tr(),
              style: TextStyle(
                fontFamily: AppTypography.bodyFamily,
                color: const Color(0xFF0A0F22),
                fontWeight: FontWeight.w800,
                fontSize: w * 0.027,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
