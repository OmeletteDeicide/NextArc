import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nextarc/core/services/notification_prefs_repository.dart';
import 'package:nextarc/core/services/notification_service.dart';
import 'package:nextarc/core/theme/app_tokens.dart';
import 'package:nextarc/features/watchlist/data/mutation_repository.dart';
import 'package:nextarc/features/watchlist/domain/media_list_entry.dart';
import 'package:nextarc/features/watchlist/domain/watchlist_providers.dart';
import 'package:nextarc/features/watchlist/presentation/edit_sheet_parts.dart';

/// BottomSheet pour ajouter ou modifier un anime dans la liste AniList.
///
/// [animeId]    — id de l'anime à modifier
/// [animeTitle] — titre affiché dans le header
/// [existing]   — entrée existante si déjà dans la liste (null = nouvel ajout)
Future<void> showWatchlistEditSheet(
  BuildContext context,
  WidgetRef ref, {
  required int animeId,
  required String animeTitle,
  int? totalEpisodes,
  DateTime? startDate,
  MediaListEntry? existing,
  bool isManga = false,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _WatchlistEditSheet(
      animeId: animeId,
      animeTitle: animeTitle,
      totalEpisodes: totalEpisodes,
      startDate: startDate,
      existing: existing,
      isManga: isManga,
    ),
  );
}

class _WatchlistEditSheet extends ConsumerStatefulWidget {
  const _WatchlistEditSheet({
    required this.animeId,
    required this.animeTitle,
    this.totalEpisodes,
    this.startDate,
    this.existing,
    this.isManga = false,
  });

  final int animeId;
  final String animeTitle;
  final int? totalEpisodes;
  final DateTime? startDate;
  final MediaListEntry? existing;
  final bool isManga;

  @override
  ConsumerState<_WatchlistEditSheet> createState() =>
      _WatchlistEditSheetState();
}

class _WatchlistEditSheetState extends ConsumerState<_WatchlistEditSheet> {
  late ListStatus _selectedStatus;
  late double _score;
  late int _progress;
  late bool _notifEnabled;
  bool _isSaving = false;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.existing?.status ?? ListStatus.planning;
    _score = widget.existing?.score ?? 0;
    _progress = widget.existing?.progress ?? 0;
    _notifEnabled =
        NotificationPrefsRepository.instance.isEnabled(widget.animeId);
  }

  void _setStatus(ListStatus s) => setState(() {
        _selectedStatus = s;
        // Prévu → remet progression et note à 0
        if (s == ListStatus.planning) {
          _progress = 0;
          _score = 0;
        }
        // Terminé → met la progression au maximum
        if (s == ListStatus.completed && widget.totalEpisodes != null) {
          _progress = widget.totalEpisodes!;
        }
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
          value: EditSheetValue('$_progress/${widget.totalEpisodes ?? '?'}'),
          child: ProgressStepper(
            progress: _progress,
            total: widget.totalEpisodes,
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
            child: ScoreSegments(
              score: _score,
              onChanged: (v) => setState(() => _score = v),
            ),
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

  // ── Actions ─────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final repo = MutationRepository();
      await repo.saveEntry(
        mediaId: widget.animeId,
        status: _selectedStatus,
        score: _score > 0 ? _score : null,
        progress: _progress > 0 ? _progress : null,
      );

      // Notifications de sortie : programme si "Prévu" + date connue
      final notifs = NotificationService.instance;
      if (_selectedStatus == ListStatus.planning &&
          widget.startDate != null &&
          widget.startDate!.isAfter(DateTime.now())) {
        await notifs.requestPermission();
        await notifs.scheduleReleaseNotifications(
          animeId: widget.animeId,
          title: widget.animeTitle,
          startDate: widget.startDate!,
        );
      } else {
        // Annule les notifs si statut changé (ex: "Prévu" → "En cours")
        await notifs.cancelReleaseNotifications(widget.animeId);
      }

      // Rafraîchit les listes après sauvegarde
      ref.invalidate(userListProvider);
      ref.invalidate(userMangaListProvider);
      HapticFeedback.lightImpact();

      if (mounted) {
        Navigator.of(context).pop();
        showEditSheetSnackBar(
          context,
          widget.existing != null
              ? 'sheet_snackbar_updated'.tr()
              : 'sheet_snackbar_added'.tr(),
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
      'sheet_delete_dialog_content_anilist'
          .tr(namedArgs: {'title': widget.animeTitle}),
    );
    if (!confirmed || !mounted) return;

    setState(() => _isDeleting = true);
    try {
      final repo = MutationRepository();
      await repo.deleteEntry(widget.existing!.id);

      // Annule les notifs de sortie liées à cet anime
      await NotificationService.instance
          .cancelReleaseNotifications(widget.animeId);

      ref.invalidate(userListProvider);
      ref.invalidate(userMangaListProvider);
      HapticFeedback.lightImpact();

      if (mounted) {
        Navigator.of(context).pop();
        showEditSheetSnackBar(context, 'sheet_snackbar_removed'.tr());
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
