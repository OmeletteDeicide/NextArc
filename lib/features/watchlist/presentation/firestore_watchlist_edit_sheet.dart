import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nextarc/core/services/notification_prefs_repository.dart';
import 'package:nextarc/core/services/notification_service.dart';
import 'package:nextarc/core/theme/app_tokens.dart';
import 'package:nextarc/features/watchlist/domain/firestore_watchlist_providers.dart';
import 'package:nextarc/features/watchlist/domain/guest_watchlist_entry.dart';
import 'package:nextarc/features/watchlist/domain/media_list_entry.dart';
import 'package:nextarc/features/watchlist/presentation/edit_sheet_parts.dart';
import 'package:nextarc/features/watchlist/presentation/favourite_button.dart';

/// BottomSheet pour ajouter ou modifier un média dans la watchlist Firestore.
Future<void> showFirestoreWatchlistEditSheet(
  BuildContext context,
  WidgetRef ref, {
  required int animeId,
  required String animeTitle,
  required String? coverImage,
  int? totalEpisodes,
  int? airedEpisodes,
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
      animeId: animeId,
      animeTitle: animeTitle,
      coverImage: coverImage,
      totalEpisodes: totalEpisodes,
      airedEpisodes: airedEpisodes,
      existing: existing,
      isManga: isManga,
      genres: genres,
      duration: duration,
    ),
  );
}

class _FirestoreEditSheet extends ConsumerStatefulWidget {
  const _FirestoreEditSheet({
    required this.animeId,
    required this.animeTitle,
    required this.coverImage,
    this.totalEpisodes,
    this.airedEpisodes,
    this.existing,
    this.isManga = false,
    this.genres,
    this.duration,
  });

  final int animeId;
  final String animeTitle;
  final String? coverImage;
  final int? totalEpisodes;

  /// Épisodes déjà sortis (série en cours sans total connu).
  final int? airedEpisodes;
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

  void _setStatus(ListStatus s) => setState(() {
        _selectedStatus = s;
        if (s == ListStatus.planning) {
          _progress = 0;
          _score = 0;
        }
        if (s == ListStatus.completed && widget.totalEpisodes != null) {
          _progress = widget.totalEpisodes!;
        }
      });

  void _setScore(double v) => setState(() {
        // Note ≥ 8 → ❤️ coché automatiquement, sauf si l'utilisateur a déjà
        // choisi lui-même dans cette fiche
        const threshold = GuestWatchlistEntry.autoFavouriteScore;
        if (!_favouriteTouched && _score < threshold && v >= threshold) {
          _favourite = true;
        }
        _score = v;
      });

  Future<void> _setNotif(bool v) async {
    final granted =
        v ? await NotificationService.instance.requestPermission() : true;
    if (!granted) return;
    if (v) {
      await NotificationPrefsRepository.instance.enable(
        widget.animeId,
        title: widget.animeTitle,
        isManga: widget.isManga,
        currentCount: widget.totalEpisodes,
      );
    } else {
      await NotificationPrefsRepository.instance.disable(widget.animeId);
    }
    if (mounted) setState(() => _notifEnabled = v);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final isEditing = widget.existing != null;

    return EditSheetFrame(
      children: [
        EditSheetHeader(
          title: isEditing ? 'sheet_edit_title'.tr() : 'sheet_add_title'.tr(),
          mediaTitle: widget.animeTitle,
          trailing: [
            FavouriteButton(
              value: _favourite,
              onChanged: (v) => setState(() {
                _favourite = v;
                _favouriteTouched = true;
              }),
            ),
          ],
        ),
        EditSheetSection(
          label: 'sheet_status_label'.tr(),
          child: StatusSelector(
            selected: _selectedStatus,
            onChanged: _setStatus,
          ),
        ),
        EditSheetSection(
          label: widget.isManga
              ? 'sheet_progress_chapters'.tr()
              : 'sheet_progress_episodes'.tr(),
          value: ProgressValue(
            progress: _progress,
            total: widget.totalEpisodes,
            aired: widget.airedEpisodes,
            isManga: widget.isManga,
            onChanged: (v) => setState(() => _progress = v),
          ),
          child: ProgressStepper(
            progress: _progress,
            total: widget.totalEpisodes,
            aired: widget.airedEpisodes,
            onChanged: (v) => setState(() => _progress = v),
          ),
        ),
        if (_selectedStatus != ListStatus.planning)
          EditSheetSection(
            label: 'sheet_score_label'.tr(),
            value: _score > 0
                ? EditSheetValue('★ ${formatSheetScore(context, _score)}',
                    color: c.star)
                : EditSheetValue('sheet_score_unrated'.tr(), color: c.text3),
            child: ScoreSegments(score: _score, onChanged: _setScore),
          ),
        NotifToggleCard(
          enabled: _notifEnabled,
          isManga: widget.isManga,
          onChanged: _setNotif,
        ),
        EditSheetActions(
          isEditing: isEditing,
          isSaving: _isSaving,
          isDeleting: _isDeleting,
          onSave: _save,
          onDelete: _delete,
        ),
      ],
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
        showEditSheetSnackBar(
          context,
          widget.existing != null
              ? 'sheet_snackbar_guest_updated'.tr()
              : 'sheet_snackbar_guest_added'.tr(),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        showEditSheetSnackBar(
          context,
          'sheet_snackbar_error'.tr(namedArgs: {'error': e.toString()}),
          error: true,
        );
      }
    }
  }

  Future<void> _delete() async {
    final confirmed = await confirmRemoveFromList(
      context,
      'sheet_delete_dialog_content_guest'
          .tr(namedArgs: {'title': widget.animeTitle}),
    );
    if (!confirmed || !mounted) return;

    setState(() => _isDeleting = true);
    try {
      await ref.read(firestoreWatchlistProvider.notifier).remove(widget.animeId);
      HapticFeedback.lightImpact();

      if (mounted) {
        Navigator.of(context).pop();
        showEditSheetSnackBar(context, 'sheet_snackbar_guest_removed'.tr());
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDeleting = false);
        showEditSheetSnackBar(
          context,
          'sheet_snackbar_error'.tr(namedArgs: {'error': e.toString()}),
          error: true,
        );
      }
    }
  }
}
