import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nextarc/core/theme/app_tokens.dart';
import 'package:nextarc/core/widgets/ds/ds.dart';
import 'package:nextarc/features/watchlist/domain/list_items.dart';
import 'package:nextarc/features/watchlist/domain/removed_history.dart';
import 'package:nextarc/features/watchlist/domain/removed_history_providers.dart';
import 'package:nextarc/features/watchlist/presentation/edit_sheet_parts.dart';
import 'package:nextarc/features/watchlist/presentation/removed_actions.dart';

/// « Il y a 5 min », « il y a 3 h », « il y a 2 j ».
String removedAgoLabel(DateTime removedAt, DateTime now) {
  final elapsed = now.difference(removedAt);
  if (elapsed.inMinutes < 1) return 'removed_ago_now'.tr();
  if (elapsed.inHours < 1) {
    return 'removed_ago_minutes'
        .tr(namedArgs: {'count': '${elapsed.inMinutes}'});
  }
  if (elapsed.inDays < 1) {
    return 'removed_ago_hours'.tr(namedArgs: {'count': '${elapsed.inHours}'});
  }
  return 'removed_ago_days'.tr(namedArgs: {'count': '${elapsed.inDays}'});
}

/// Titres retirés de la liste depuis moins de 30 jours, restaurables tels
/// qu'ils étaient.
class RecentlyRemovedScreen extends ConsumerWidget {
  const RecentlyRemovedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    final history = ref.watch(removedHistoryProvider);
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    Future<void> clearAll() async {
      final confirmed = await showConfirmDialog(
        context,
        title: 'removed_clear_title'.tr(),
        message: 'removed_clear_body'.tr(),
        confirmLabel: 'removed_clear_confirm'.tr(),
        destructive: true,
      );
      final owner = ref.read(removedHistoryOwnerProvider);
      if (!confirmed || owner == null) return;
      await ref.read(removedHistoryRepositoryProvider).clear(owner);
      ref.invalidate(removedHistoryProvider);
    }

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
                  RoundIconButton(
                    icon: Icons.arrow_back_rounded,
                    tooltip:
                        MaterialLocalizations.of(context).backButtonTooltip,
                    color: c.accentText,
                    onTap: () => context.pop(),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('removed_title'.tr(),
                        style: text.titleLarge?.copyWith(color: c.text1)),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screen, AppSpacing.xs, AppSpacing.screen, 0),
              child: Text(
                'removed_intro'.tr(),
                style: text.bodySmall?.copyWith(color: c.text2, height: 1.5),
              ),
            ),
            Expanded(
              child: history.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (_, _) => const _EmptyHistory(),
                data: (items) => items.isEmpty
                    ? const _EmptyHistory()
                    : ListView(
                        padding: EdgeInsets.fromLTRB(AppSpacing.screen,
                            AppSpacing.md, AppSpacing.screen,
                            AppSpacing.lg + bottomInset),
                        children: [
                          for (final removed in items) ...[
                            _RemovedRow(removed: removed),
                            const SizedBox(height: AppSpacing.xs),
                          ],
                          const SizedBox(height: AppSpacing.sm),
                          Center(
                            child: TextButton(
                              style: TextButton.styleFrom(
                                  foregroundColor: c.statusDroppedText),
                              onPressed: clearAll,
                              child: Text('removed_clear'.tr()),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RemovedRow extends StatefulWidget {
  const _RemovedRow({required this.removed});

  final RemovedEntry removed;

  @override
  State<_RemovedRow> createState() => _RemovedRowState();
}

class _RemovedRowState extends State<_RemovedRow> {
  bool _busy = false;

  Future<void> _restore() async {
    setState(() => _busy = true);
    final restored = await restoreRemovedEntry(context, widget.removed);
    if (!mounted) return;
    setState(() => _busy = false);
    if (restored) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('removed_restored'
            .tr(namedArgs: {'title': widget.removed.entry.title})),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    final entry = widget.removed.entry;
    final score = (entry.score ?? 0) > 0
        ? '★ ${formatSheetScore(context, entry.score!)}'
        : null;
    final meta = [
      entry.isManga ? 'Manga' : 'Anime',
      entry.status.label,
      formatProgress(entry.progress ?? 0, total: entry.episodes),
      ?score,
    ].join(' · ');

    return Container(
      padding: const EdgeInsets.fromLTRB(11, 11, 8, 11),
      decoration: BoxDecoration(
        color: c.surface1,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: MediaCover(imageUrl: entry.coverImage, radius: 8),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (entry.favourite) ...[
                      Icon(Icons.favorite_rounded,
                          size: 13, color: c.favourite),
                      const SizedBox(width: 4),
                    ],
                    Expanded(
                      child: Text(
                        entry.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleSmall?.copyWith(color: c.text1),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall
                        ?.copyWith(color: c.text2, fontSize: 10.5)),
                const SizedBox(height: 2),
                Text(
                  removedAgoLabel(widget.removed.removedAt, DateTime.now()),
                  style: text.bodySmall
                      ?.copyWith(color: c.text3, fontSize: 10.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          TextButton(
            onPressed: _busy ? null : _restore,
            style: TextButton.styleFrom(
              backgroundColor: c.surface2,
              foregroundColor: c.accentText,
              minimumSize: const Size(0, AppSpacing.minTouch),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              shape: const StadiumBorder(),
            ),
            child: Text('removed_restore'.tr()),
          ),
        ],
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: c.surface1,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(Icons.history_rounded, size: 28, color: c.text3),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text('removed_empty_title'.tr(),
                style: text.titleMedium?.copyWith(color: c.text1)),
            const SizedBox(height: 6),
            Text(
              'removed_empty_body'.tr(),
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: c.text2, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
