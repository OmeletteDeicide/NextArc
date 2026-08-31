import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nextarc/features/calendar/domain/calendar_provider.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  late DateTime _selectedDay;
  late List<DateTime> _days;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDay = DateTime(now.year, now.month, now.day);
    _days = List.generate(
      14,
      (i) => _selectedDay.add(Duration(days: i)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final calAsync = ref.watch(airingCalendarProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('calendar_title'.tr()),
      ),
      body: calAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 12),
              Text(e.toString()),
              const SizedBox(height: 16),
              FilledButton.icon(
                icon: const Icon(Icons.refresh),
                label: Text('action_retry'.tr()),
                onPressed: () => ref.invalidate(airingCalendarProvider),
              ),
            ],
          ),
        ),
        data: (calendar) {
          // Jours qui ont des épisodes
          final activeDays = calendar.keys.toSet();

          return Column(
            children: [
              // ── Sélecteur de jour ──────────────────────────────────────
              SizedBox(
                height: 80,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  itemCount: _days.length,
                  itemBuilder: (context, i) {
                    final day = _days[i];
                    final isSelected = day == _selectedDay;
                    final hasEpisodes = activeDays.contains(day);

                    return GestureDetector(
                      onTap: () => setState(() => _selectedDay = day),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 52,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? cs.primary
                              : cs.onSurface.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected
                                ? cs.primary
                                : cs.outline.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _shortDayName(day),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? Colors.white.withValues(alpha: 0.8)
                                    : cs.onSurface.withValues(alpha: 0.5),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${day.day}',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isSelected
                                    ? Colors.white
                                    : cs.onSurface,
                              ),
                            ),
                            if (hasEpisodes)
                              Container(
                                width: 5,
                                height: 5,
                                margin: const EdgeInsets.only(top: 2),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isSelected
                                      ? Colors.white.withValues(alpha: 0.8)
                                      : cs.primary,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              Divider(
                  height: 1,
                  color: cs.outline.withValues(alpha: 0.15)),

              // ── Liste des épisodes du jour sélectionné ─────────────────
              Expanded(
                child: _buildDayContent(
                    context, calendar[_selectedDay] ?? [], cs),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDayContent(
      BuildContext context, List<AiringEntry> entries, ColorScheme cs) {
    if (entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_available_outlined,
                size: 56, color: cs.onSurface.withValues(alpha: 0.2)),
            const SizedBox(height: 16),
            Text(
              'calendar_empty'.tr(),
              style: TextStyle(
                  fontSize: 15,
                  color: cs.onSurface.withValues(alpha: 0.45)),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: entries.length,
      itemBuilder: (context, i) => _AiringCard(entry: entries[i]),
    );
  }

  /// Nom court du jour localisé (Lu, Ma, Me…).
  String _shortDayName(DateTime day) {
    final locale = Localizations.localeOf(context).languageCode;
    const fr = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
    const en = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const es = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];

    final names = locale == 'fr'
        ? fr
        : locale == 'es'
            ? es
            : en;
    return names[(day.weekday - 1) % 7];
  }
}

// ── Carte épisode ─────────────────────────────────────────────────────────────

class _AiringCard extends ConsumerWidget {
  const _AiringCard({required this.entry});
  final AiringEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final media = entry.listEntry.media;
    final now = DateTime.now();
    final isAired = entry.airingAt.isBefore(now);
    final cardBg = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF161C26)
        : cs.surfaceContainerLowest;

    return GestureDetector(
      onTap: () => context.push(
        '/detail/${media.id}',
        extra: {'coverUrl': media.coverImage},
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isAired
                ? cs.outline.withValues(alpha: 0.1)
                : cs.primary.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          children: [
            // Jaquette
            ClipRRect(
              borderRadius:
                  const BorderRadius.horizontal(left: Radius.circular(16)),
              child: SizedBox(
                width: 64,
                height: 88,
                child: media.coverImage != null
                    ? CachedNetworkImage(
                        imageUrl: media.coverImage!,
                        fit: BoxFit.cover,
                        color: isAired
                            ? Colors.black.withValues(alpha: 0.35)
                            : null,
                        colorBlendMode:
                            isAired ? BlendMode.darken : null,
                      )
                    : Container(color: cs.surfaceContainerHighest),
              ),
            ),

            const SizedBox(width: 12),

            // Titre + ep + heure
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    media.displayTitle,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isAired
                          ? cs.onSurface.withValues(alpha: 0.45)
                          : cs.onSurface,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'calendar_episode'.tr(
                        namedArgs: {'ep': entry.episode.toString()}),
                    style: TextStyle(
                      fontSize: 12,
                      color: isAired
                          ? cs.onSurface.withValues(alpha: 0.35)
                          : cs.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            // Heure de diffusion
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Column(
                children: [
                  if (isAired)
                    Icon(Icons.check_circle_outline,
                        size: 18,
                        color: cs.onSurface.withValues(alpha: 0.3))
                  else
                    Icon(Icons.access_time_rounded,
                        size: 14, color: cs.primary),
                  const SizedBox(height: 2),
                  Text(
                    _formatTime(entry.airingAt),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isAired
                          ? cs.onSurface.withValues(alpha: 0.3)
                          : cs.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
