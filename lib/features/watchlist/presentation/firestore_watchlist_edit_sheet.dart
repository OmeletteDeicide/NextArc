import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nextarc/core/services/notification_service.dart';
import 'package:nextarc/core/services/notification_prefs_repository.dart';
import 'package:nextarc/features/watchlist/domain/firestore_watchlist_providers.dart';
import 'package:nextarc/features/watchlist/domain/guest_watchlist_entry.dart';
import 'package:nextarc/features/watchlist/domain/media_list_entry.dart';
import 'package:nextarc/features/watchlist/presentation/favourite_button.dart';

/// BottomSheet pour ajouter ou modifier un média dans la watchlist Firestore.
Future<void> showFirestoreWatchlistEditSheet(
  BuildContext context,
  WidgetRef ref, {
  required int animeId,
  required String animeTitle,
  required String? coverImage,
  int? totalEpisodes,
  GuestWatchlistEntry? existing,
  bool isManga = false,
  List<String>? genres,
  int? duration,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _FirestoreEditSheet(
      ref: ref,
      animeId: animeId,
      animeTitle: animeTitle,
      coverImage: coverImage,
      totalEpisodes: totalEpisodes,
      existing: existing,
      isManga: isManga,
      genres: genres,
      duration: duration,
    ),
  );
}

class _FirestoreEditSheet extends ConsumerStatefulWidget {
  const _FirestoreEditSheet({
    required this.ref,
    required this.animeId,
    required this.animeTitle,
    required this.coverImage,
    this.totalEpisodes,
    this.existing,
    this.isManga = false,
    this.genres,
    this.duration,
  });

  final WidgetRef ref;
  final int animeId;
  final String animeTitle;
  final String? coverImage;
  final int? totalEpisodes;
  final GuestWatchlistEntry? existing;
  final bool isManga;
  final List<String>? genres;
  final int? duration;

  @override
  ConsumerState<_FirestoreEditSheet> createState() =>
      _FirestoreEditSheetState();
}

class _FirestoreEditSheetState extends ConsumerState<_FirestoreEditSheet> {
  late ListStatus _selectedStatus;
  late double _score;
  late int _progress;
  late bool _notifEnabled;
  late bool _favourite;

  /// L'utilisateur a choisi lui-même le ❤️ : la note ne le modifie plus.
  bool _favouriteTouched = false;
  bool _isSaving = false;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.existing?.status ?? ListStatus.planning;
    _score = widget.existing?.score ?? 0;
    _progress = widget.existing?.progress ?? 0;
    _favourite = widget.existing?.favourite ?? false;
    _notifEnabled =
        NotificationPrefsRepository.instance.isEnabled(widget.animeId);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;
    final cs = Theme.of(context).colorScheme;
    final sheetBg = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF161C26)
        : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        // Clavier + barre de navigation système (edge-to-edge)
        bottom: MediaQuery.viewInsetsOf(context).bottom +
            MediaQuery.viewPaddingOf(context).bottom +
            24,
        top: 16,
        left: 20,
        right: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.onSurface.withValues(alpha: 0.24),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Titre + titre du média + ❤️
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEditing
                          ? 'sheet_edit_title'.tr()
                          : 'sheet_add_title'.tr(),
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.animeTitle,
                      style: TextStyle(
                          color: cs.onSurface.withValues(alpha: 0.54),
                          fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              FavouriteButton(
                value: _favourite,
                onChanged: (v) => setState(() {
                  _favourite = v;
                  _favouriteTouched = true;
                }),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Statut
          Text('sheet_status_label'.tr(),
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ListStatus.values
                .map((s) => _StatusChip(
                      status: s,
                      selected: _selectedStatus == s,
                      onTap: () => setState(() {
                        _selectedStatus = s;
                        if (s == ListStatus.planning) {
                          _progress = 0;
                          _score = 0;
                        }
                        if (s == ListStatus.completed &&
                            widget.totalEpisodes != null) {
                          _progress = widget.totalEpisodes!;
                        }
                      }),
                    ))
                .toList(),
          ),

          const SizedBox(height: 24),

          // Progression
          Row(
            children: [
              Text(
                widget.isManga
                    ? 'sheet_progress_chapters'.tr()
                    : 'sheet_progress_episodes'.tr(),
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const Spacer(),
              Text(
                widget.isManga
                    ? '$_progress ch. / ${widget.totalEpisodes ?? '?'}'
                    : '$_progress / ${widget.totalEpisodes ?? '?'}',
                style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.54),
                    fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton(
                onPressed:
                    _progress > 0 ? () => setState(() => _progress--) : null,
                icon: const Icon(Icons.remove_circle_outline),
                color: cs.onSurface.withValues(alpha: 0.54),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: cs.primary,
                    thumbColor: cs.primary,
                    inactiveTrackColor:
                        cs.onSurface.withValues(alpha: 0.12),
                    overlayColor: cs.primary.withValues(alpha: 0.2),
                  ),
                  child: Slider(
                    value: _progress.toDouble(),
                    min: 0,
                    max: (widget.totalEpisodes ?? 2000).toDouble(),
                    divisions: widget.totalEpisodes,
                    onChanged: (v) => setState(() => _progress = v.round()),
                  ),
                ),
              ),
              IconButton(
                onPressed: widget.totalEpisodes == null ||
                        _progress < widget.totalEpisodes!
                    ? () => setState(() => _progress++)
                    : null,
                icon: const Icon(Icons.add_circle_outline),
                color: cs.onSurface.withValues(alpha: 0.54),
              ),
            ],
          ),

          // Note
          if (_selectedStatus != ListStatus.planning) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Text('sheet_score_label'.tr(),
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                const Spacer(),
                if (_score > 0) ...[
                  const Icon(Icons.star_rounded,
                      size: 16, color: Color(0xFFFFC107)),
                  const SizedBox(width: 4),
                  Text(
                    _score % 1 == 0
                        ? _score.toInt().toString()
                        : _score.toStringAsFixed(1),
                    style: const TextStyle(
                        color: Color(0xFFFFC107),
                        fontWeight: FontWeight.bold,
                        fontSize: 15),
                  ),
                ] else
                  Text('sheet_score_unrated'.tr(),
                      style: TextStyle(
                          color: cs.onSurface.withValues(alpha: 0.38),
                          fontSize: 13)),
              ],
            ),
            const SizedBox(height: 8),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: const Color(0xFFFFC107),
                thumbColor: const Color(0xFFFFC107),
                inactiveTrackColor: cs.onSurface.withValues(alpha: 0.12),
                overlayColor:
                    const Color(0xFFFFC107).withValues(alpha: 0.2),
              ),
              child: Slider(
                value: _score,
                min: 0,
                max: 10,
                divisions: 20,
                onChanged: (v) => setState(() {
                  // Note ≥ 8 → ❤️ coché automatiquement, sauf si
                  // l'utilisateur a déjà choisi lui-même dans cette fiche
                  const threshold = GuestWatchlistEntry.autoFavouriteScore;
                  if (!_favouriteTouched && _score < threshold && v >= threshold) {
                    _favourite = true;
                  }
                  _score = v;
                }),
              ),
            ),
          ],

          const SizedBox(height: 20),

          // Toggle notifications
          _NotifToggle(
            enabled: _notifEnabled,
            isManga: widget.isManga,
            onChanged: (v) async {
              final granted = v
                  ? await NotificationService.instance.requestPermission()
                  : true;
              if (!granted) return;
              if (v) {
                await NotificationPrefsRepository.instance.enable(
                  widget.animeId,
                  title: widget.animeTitle,
                  isManga: widget.isManga,
                  currentCount: widget.totalEpisodes,
                );
              } else {
                await NotificationPrefsRepository.instance
                    .disable(widget.animeId);
              }
              if (mounted) setState(() => _notifEnabled = v);
            },
          ),

          const SizedBox(height: 16),

          // Boutons
          Row(
            children: [
              if (isEditing) ...[
                OutlinedButton.icon(
                  icon: _isDeleting
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child:
                              CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.delete_outline, size: 18),
                  label: Text('sheet_remove_button'.tr()),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent),
                  ),
                  onPressed: _isSaving || _isDeleting ? null : _delete,
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: FilledButton.icon(
                  icon: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check, size: 18),
                  label: Text(isEditing
                      ? 'sheet_update_button'.tr()
                      : 'sheet_add_button'.tr()),
                  onPressed: _isSaving || _isDeleting ? null : _save,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final entry = GuestWatchlistEntry(
        animeId: widget.animeId,
        title: widget.animeTitle,
        coverImage: widget.coverImage,
        status: _selectedStatus,
        score: _score > 0 ? _score : null,
        progress: _progress > 0 ? _progress : null,
        episodes: widget.totalEpisodes,
        mediaType: widget.isManga ? 'MANGA' : 'ANIME',
        genres: widget.genres ?? widget.existing?.genres,
        duration: widget.duration ?? widget.existing?.duration,
        favourite: _favourite,
      );

      await ref.read(firestoreWatchlistProvider.notifier).upsert(entry);
      HapticFeedback.lightImpact();

      if (mounted) {
        Navigator.of(context).pop();
        final cs = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.existing != null
                  ? 'sheet_snackbar_guest_updated'.tr()
                  : 'sheet_snackbar_guest_added'.tr(),
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
            backgroundColor: cs.surfaceContainerHighest,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('sheet_snackbar_error'
                .tr(namedArgs: {'error': e.toString()})),
            backgroundColor: Colors.red.shade800,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('sheet_delete_dialog_title'.tr()),
        content: Text('sheet_delete_dialog_content_guest'.tr(
            namedArgs: {'title': widget.animeTitle})),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('dialog_cancel'.tr()),
          ),
          FilledButton(
            style:
                FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('dialog_confirm_delete'.tr()),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isDeleting = true);
    try {
      await ref
          .read(firestoreWatchlistProvider.notifier)
          .remove(widget.animeId);
      HapticFeedback.lightImpact();

      if (mounted) {
        Navigator.of(context).pop();
        final cs = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'sheet_snackbar_guest_removed'.tr(),
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
            backgroundColor: cs.surfaceContainerHighest,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDeleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('sheet_snackbar_error'
                .tr(namedArgs: {'error': e.toString()})),
            backgroundColor: Colors.red.shade800,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }
}

// ── Toggle notifications ──────────────────────────────────────────────────────

class _NotifToggle extends StatelessWidget {
  const _NotifToggle({
    required this.enabled,
    required this.isManga,
    required this.onChanged,
  });

  final bool enabled;
  final bool isManga;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final label =
        isManga ? 'sheet_notif_chapters'.tr() : 'sheet_notif_episodes'.tr();

    return Row(
      children: [
        Icon(
          enabled
              ? Icons.notifications_active_rounded
              : Icons.notifications_none_rounded,
          size: 20,
          color:
              enabled ? cs.primary : cs.onSurface.withValues(alpha: 0.45),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: enabled
                  ? cs.onSurface
                  : cs.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ),
        Switch(
          value: enabled,
          onChanged: onChanged,
          activeThumbColor: cs.primary,
          activeTrackColor: cs.primary.withValues(alpha: 0.4),
        ),
      ],
    );
  }
}

// ── Chip de statut ────────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.status,
    required this.selected,
    required this.onTap,
  });

  final ListStatus status;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? cs.primary
              : cs.onSurface.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? cs.primary
                : cs.onSurface.withValues(alpha: 0.24),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _iconFor(status),
              size: 14,
              color: selected
                  ? Colors.white
                  : cs.onSurface.withValues(alpha: 0.54),
            ),
            const SizedBox(width: 6),
            Text(
              status.label,
              style: TextStyle(
                fontSize: 13,
                fontWeight:
                    selected ? FontWeight.bold : FontWeight.normal,
                color: selected
                    ? Colors.white
                    : cs.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(ListStatus s) => switch (s) {
        ListStatus.current => Icons.play_circle_outline,
        ListStatus.completed => Icons.check_circle_outline,
        ListStatus.planning => Icons.bookmark_border,
        ListStatus.paused => Icons.pause_circle_outline,
        ListStatus.dropped => Icons.cancel_outlined,
      };
}
