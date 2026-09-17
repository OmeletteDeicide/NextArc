import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nextarc/core/router/app_router.dart';
import 'package:nextarc/core/services/notification_prefs_repository.dart';
import 'package:nextarc/core/services/notification_service.dart';
import 'package:nextarc/core/theme/app_tokens.dart';
import 'package:nextarc/core/theme/app_typography.dart';
import 'package:nextarc/core/widgets/ds/ds.dart';
import 'package:nextarc/features/browse/domain/browse_provider.dart';
import 'package:nextarc/features/browse/domain/filter_params.dart';
import 'package:nextarc/features/calendar/domain/calendar_groups.dart';
import 'package:nextarc/features/calendar/domain/calendar_provider.dart';
import 'package:nextarc/features/discover/domain/discover_hero.dart';

/// Calendrier des sorties : liste chronologique groupée par semaine, sans
/// sélecteur de jour (seuls les jours qui ont des sorties apparaissent).
class CalendarScreen extends ConsumerWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    final calAsync = ref.watch(airingCalendarProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screen - 4, AppSpacing.xs, AppSpacing.screen, 6),
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
                    child: Text('calendar_title'.tr(),
                        style: text.headlineSmall
                            ?.copyWith(fontSize: 19, color: c.text1)),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                    decoration: BoxDecoration(
                      color: c.surface2,
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                    child: Text('calendar_range'.tr(),
                        style: text.labelMedium
                            ?.copyWith(color: c.text2, fontSize: 11)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: calAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (_, _) => _CalendarEmpty(
                  icon: Icons.wifi_off_rounded,
                  title: 'browse_error_title'.tr(),
                  body: 'calendar_error_body'.tr(),
                  primaryLabel: 'action_retry'.tr(),
                  onPrimary: () => ref.invalidate(airingCalendarProvider),
                ),
                data: (calendar) {
                  final layout = buildCalendarLayout<AiringEntry>(
                    calendar.values.expand((day) => day),
                    airingAt: (e) => e.airingAt,
                    now: DateTime.now(),
                  );
                  if (layout.isEmpty) {
                    return _CalendarEmpty(
                      icon: Icons.event_busy_rounded,
                      title: 'calendar_empty_title'.tr(),
                      body: 'calendar_empty_body'.tr(),
                      primaryLabel: 'calendar_empty_airing'.tr(),
                      onPrimary: () {
                        ref.read(browseFilterProvider.notifier).state =
                            const FilterParams(
                          mediaType: 'ANIME',
                          status: 'RELEASING',
                          sort: 'POPULARITY_DESC',
                        );
                        context.push(AppRoutes.browse);
                      },
                      secondaryLabel: 'calendar_empty_list'.tr(),
                      onSecondary: () => context.go(AppRoutes.watchlist),
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: () async =>
                        ref.refresh(airingCalendarProvider.future),
                    child: _CalendarList(layout: layout),
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

class _CalendarList extends StatelessWidget {
  const _CalendarList({required this.layout});

  final CalendarLayout<AiringEntry> layout;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    final locale = context.locale.toString();
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    String weekTitle(CalendarWeek week) => switch (week) {
          CalendarWeek.thisWeek => 'calendar_this_week'.tr(),
          CalendarWeek.nextWeek => 'calendar_next_week'.tr(),
          CalendarWeek.later => 'calendar_later'.tr(),
        };

    return ListView(
      padding: EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.xs,
          AppSpacing.screen, AppSpacing.xl + bottomInset),
      children: [
        if (layout.pinned != null) ...[
          _PinnedRelease(entry: layout.pinned!),
          const SizedBox(height: AppSpacing.md),
        ],
        for (final week in layout.weeks) ...[
          Row(
            children: [
              Text(weekTitle(week.week),
                  style: text.titleLarge?.copyWith(fontSize: 14, color: c.text1)),
              const SizedBox(width: 10),
              Expanded(child: Container(height: 1, color: c.border)),
              const SizedBox(width: 10),
              Text(
                week.count == 1
                    ? 'calendar_releases_one'.tr()
                    : 'calendar_releases'
                        .tr(namedArgs: {'count': '${week.count}'}),
                style: AppTypography.overline(c.accentText)
                    .copyWith(fontSize: 10.5, letterSpacing: 0),
              ),
            ],
          ),
          const SizedBox(height: 11),
          for (final day in week.days) ...[
            Text(
              DateFormat('EEEE d', locale).format(day.date).toUpperCase(),
              style: AppTypography.overline(c.text3)
                  .copyWith(letterSpacing: 1.2),
            ),
            const SizedBox(height: 9),
            for (final entry in day.items) ...[
              _ReleaseRow(entry: entry),
              const SizedBox(height: 9),
            ],
            const SizedBox(height: 2),
          ],
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

/// Prochaine sortie du jour, mise en avant.
class _PinnedRelease extends StatelessWidget {
  const _PinnedRelease({required this.entry});

  final AiringEntry entry;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    final locale = context.locale.toString();
    final at = entry.airingAt.toLocal();
    final delay = at.difference(DateTime.now());
    final countdown =
        airingCountdown(delay.isNegative ? Duration.zero : delay);

    return Material(
      type: MaterialType.transparency,
      child: Ink(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            c.accent.withValues(alpha: 0.18),
            c.violet.withValues(alpha: 0.18),
          ]),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.accentText.withValues(alpha: 0.34)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.push('/detail/${entry.media.id}'),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                SizedBox(
                  width: 52,
                  child: MediaCover(
                      imageUrl: entry.media.coverImage, radius: 9),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${'calendar_today'.tr()} · ${DateFormat.Hm(locale).format(at)}'
                            .toUpperCase(),
                        style: AppTypography.overline(c.statusCompletedText)
                            .copyWith(fontSize: 9.5),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        entry.media.displayTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleLarge
                            ?.copyWith(fontSize: 14, color: c.text1),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${'detail_episode_number'.tr(namedArgs: {
                              'number': '${entry.episode}'
                            })} · ${countdown.key.tr(namedArgs: {
                              'count': '${countdown.count}'
                            })}',
                        style: text.bodySmall
                            ?.copyWith(color: c.text2, fontSize: 10.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                _ReminderBell(entry: entry, size: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReleaseRow extends StatelessWidget {
  const _ReleaseRow({required this.entry});

  final AiringEntry entry;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    final locale = context.locale.toString();
    final at = entry.airingAt.toLocal();

    return Material(
      color: c.surface1,
      borderRadius: BorderRadius.circular(AppRadius.card),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/detail/${entry.media.id}'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(11, 11, 6, 11),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: c.surface2,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      DateFormat.E(locale)
                          .format(at)
                          .replaceAll('.', '')
                          .toUpperCase(),
                      style: text.labelSmall?.copyWith(
                          color: c.text2, fontSize: 9, letterSpacing: 0),
                    ),
                    Text('${at.day}',
                        style: text.titleLarge?.copyWith(
                            fontSize: 14, height: 1, color: c.text1)),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.media.displayTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleSmall
                          ?.copyWith(color: c.text1, fontSize: 12.5),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'calendar_episode_time'.tr(namedArgs: {
                        'episode': '${entry.episode}',
                        'time': DateFormat.Hm(locale).format(at),
                      }),
                      style: text.bodySmall
                          ?.copyWith(color: c.text2, fontSize: 10.5),
                    ),
                  ],
                ),
              ),
              _ReminderBell(entry: entry, size: 36),
            ],
          ),
        ),
      ),
    );
  }
}

/// Rappel de sortie : même cloche que la fiche d'édition (accent), pleine
/// quand le rappel est actif.
class _ReminderBell extends StatefulWidget {
  const _ReminderBell({required this.entry, required this.size});

  final AiringEntry entry;
  final double size;

  @override
  State<_ReminderBell> createState() => _ReminderBellState();
}

class _ReminderBellState extends State<_ReminderBell> {
  late bool _on =
      NotificationPrefsRepository.instance.isEnabled(widget.entry.media.id);
  bool _busy = false;

  Future<void> _toggle() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final prefs = NotificationPrefsRepository.instance;
      if (_on) {
        await prefs.disable(widget.entry.media.id);
      } else {
        final granted = await NotificationService.instance.requestPermission();
        if (!granted) return;
        await prefs.enable(
          widget.entry.media.id,
          title: widget.entry.media.displayTitle,
          isManga: false,
          currentCount: widget.entry.episode - 1,
        );
      }
      HapticFeedback.selectionClick();
      if (mounted) setState(() => _on = !_on);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Tooltip(
      message: _on ? 'detail_reminder_on'.tr() : 'detail_reminder'.tr(),
      child: Semantics(
        button: true,
        toggled: _on,
        child: InkResponse(
          radius: 24,
          onTap: _busy ? null : _toggle,
          child: SizedBox(
            width: AppSpacing.minTouch,
            height: AppSpacing.minTouch,
            child: Center(
              child: AnimatedContainer(
                duration: AppMotion.press,
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _on ? c.accent.withValues(alpha: 0.18) : c.surface2,
                ),
                child: Icon(
                  _on
                      ? Icons.notifications_active_rounded
                      : Icons.notifications_none_rounded,
                  size: widget.size * 0.45,
                  color: _on ? c.accentText : c.text3,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CalendarEmpty extends StatelessWidget {
  const _CalendarEmpty({
    required this.icon,
    required this.title,
    required this.body,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  final IconData icon;
  final String title;
  final String body;
  final String primaryLabel;
  final VoidCallback onPrimary;
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
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: c.surface1,
                borderRadius: BorderRadius.circular(17),
              ),
              child: Icon(icon, size: 26, color: c.text3),
            ),
            const SizedBox(height: 13),
            Text(title,
                textAlign: TextAlign.center,
                style: text.headlineSmall
                    ?.copyWith(fontSize: 16, color: c.text1)),
            const SizedBox(height: 6),
            Text(body,
                textAlign: TextAlign.center,
                style: text.bodyMedium?.copyWith(color: c.text2, height: 1.55)),
            const SizedBox(height: AppSpacing.md),
            AppButton(label: primaryLabel, expand: true, onPressed: onPrimary),
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
