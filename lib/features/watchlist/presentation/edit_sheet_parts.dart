import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nextarc/core/theme/app_tokens.dart';
import 'package:nextarc/core/theme/app_typography.dart';
import 'package:nextarc/core/widgets/ds/ds.dart';
import 'package:nextarc/features/watchlist/domain/list_items.dart';
import 'package:nextarc/features/watchlist/domain/media_list_entry.dart';

// Briques visuelles communes aux trois fiches d'édition (AniList, NextArc,
// invité). Chaque fiche garde sa logique d'enregistrement.

/// Nombre de segments de la note (1 segment = 1 point sur 10).
const int kScoreSegments = 10;

/// Note après un appui sur le segment [index] (0 → 9) : toucher la note
/// actuelle l'efface, sinon la note devient la note visée.
double scoreAfterTap(double current, double target) =>
    current == target ? 0 : target;

/// Note visée à une position horizontale sur la barre de segments, au
/// demi-point : moitié gauche d'un segment = « ,5 », moitié droite = entier.
double scoreFromPosition(double dx, double width) {
  if (width <= 0) return 0;
  final raw = (dx / width).clamp(0.0, 1.0) * kScoreSegments;
  return ((raw * 2).ceil() / 2).clamp(0.5, 10.0).toDouble();
}

/// Progression maximale acceptée quand le total est inconnu (règles Firestore).
const int kMaxProgress = 50000;

/// Pas d'un appui long sur − / + selon le nombre de répétitions déjà faites :
/// 1 par 1 au début, puis 5, 25 et enfin 100 par 100 pour les très longues
/// séries (One Piece, manga à plus de 1 000 chapitres).
int progressRepeatStep(int tick) {
  if (tick < 12) return 1;
  if (tick < 36) return 5;
  if (tick < 60) return 25;
  return 100;
}

/// Progression bornée entre 0 et le total, sinon le nombre d'épisodes déjà
/// sortis, sinon [kMaxProgress].
int clampProgress(int value, int? total, {int? aired}) {
  final max = progressCeiling(total: total, aired: aired) ?? kMaxProgress;
  return value.clamp(0, max);
}

/// Progression saisie au clavier, bornée ; null si la saisie n'est pas un
/// nombre.
int? parseProgressInput(String input, int? total, {int? aired}) {
  final value = int.tryParse(input.trim());
  if (value == null) return null;
  return clampProgress(value, total, aired: aired);
}

/// Progression correspondant à une position sur la barre de progression.
int progressFromPosition(double dx, double width, int total) {
  if (width <= 0 || total <= 0) return 0;
  return ((dx / width).clamp(0.0, 1.0) * total).round();
}

/// Note affichée : « 8 » ou « 7,5 » (virgule hors anglais).
String formatSheetScore(BuildContext context, double score) {
  final raw =
      score % 1 == 0 ? score.toInt().toString() : score.toStringAsFixed(1);
  return context.locale.languageCode == 'en' ? raw : raw.replaceAll('.', ',');
}

/// Snackbar de confirmation / d'erreur des fiches (style du thème).
void showEditSheetSnackBar(BuildContext context, String message,
    {bool error = false}) {
  final c = AppColors.of(context);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: error ? c.favourite : null,
      duration: const Duration(seconds: 2),
    ),
  );
}

/// Dialogue de confirmation avant de retirer un média.
Future<bool> confirmRemoveFromList(BuildContext context, String content) =>
    showConfirmDialog(
      context,
      title: 'sheet_delete_dialog_title'.tr(),
      message: content,
      confirmLabel: 'dialog_confirm_delete'.tr(),
      destructive: true,
    );

// ── Cadre ─────────────────────────────────────────────────────────────────────

/// Fond de la fiche : surface 1, coins 24, poignée, marges edge-to-edge.
class EditSheetFrame extends StatelessWidget {
  const EditSheetFrame({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final media = MediaQuery.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      constraints: BoxConstraints(maxHeight: media.size.height * 0.92),
      decoration: BoxDecoration(
        color: c.surface1,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0x17FFFFFF) : c.border,
          ),
        ),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          // Clavier + barre de navigation système (edge-to-edge)
          media.viewInsets.bottom + media.viewPadding.bottom + 22,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: c.text3.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(height: 20),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}

// ── En-tête ───────────────────────────────────────────────────────────────────

class EditSheetHeader extends StatelessWidget {
  const EditSheetHeader({
    super.key,
    required this.title,
    required this.mediaTitle,
    this.trailing = const [],
  });

  final String title;
  final String mediaTitle;
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: text.headlineSmall
                      ?.copyWith(fontSize: 19, color: c.text1)),
              const SizedBox(height: 4),
              Text(
                mediaTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.bodySmall?.copyWith(color: c.text2, fontSize: 11.5),
              ),
            ],
          ),
        ),
        for (final widget in trailing) ...[
          const SizedBox(width: AppSpacing.xs),
          widget,
        ],
      ],
    );
  }
}

/// Badge « Invité » de la fiche locale.
class EditSheetBadge extends StatelessWidget {
  const EditSheetBadge({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.surface2,
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: Text(
        label.toUpperCase(),
        style: AppTypography.overline(c.text2).copyWith(fontSize: 9),
      ),
    );
  }
}

// ── Section ───────────────────────────────────────────────────────────────────

/// Sur-titre mono (STATUT, PROGRESSION…) + valeur à droite + contenu.
class EditSheetSection extends StatelessWidget {
  const EditSheetSection({
    super.key,
    required this.label,
    required this.child,
    this.value,
  });

  final String label;
  final Widget? value;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(label.toUpperCase(),
                  style: AppTypography.overline(c.text3)),
            ),
            ?value,
          ],
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

/// Valeur de section en Sora 800 15.
class EditSheetValue extends StatelessWidget {
  const EditSheetValue(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Text(
      text,
      style: Theme.of(context)
          .textTheme
          .titleLarge
          ?.copyWith(fontSize: 15, color: color ?? c.text1),
    );
  }
}

// ── Statut ────────────────────────────────────────────────────────────────────

class StatusSelector extends StatelessWidget {
  const StatusSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final ListStatus selected;
  final ValueChanged<ListStatus> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.xs,
      children: [
        for (final status in ListStatus.values)
          StatusChip(
            status: status,
            selected: status == selected,
            onTap: () {
              HapticFeedback.selectionClick();
              onChanged(status);
            },
          ),
      ],
    );
  }
}

// ── Progression ───────────────────────────────────────────────────────────────

/// Valeur « 12/24 » de la section Progression : un appui ouvre la saisie
/// directe du numéro (indispensable pour les séries de plus de 1 000
/// épisodes ou chapitres).
class ProgressValue extends StatelessWidget {
  const ProgressValue({
    super.key,
    required this.progress,
    required this.total,
    required this.isManga,
    required this.onChanged,
    this.aired,
  });

  final int progress;
  final int? total;

  /// Épisodes déjà sortis quand le total est inconnu.
  final int? aired;
  final bool isManga;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Semantics(
      button: true,
      label: 'sheet_progress_edit'.tr(),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.cover),
        onTap: () async {
          final value = await showProgressInputDialog(
            context,
            progress: progress,
            total: total,
            aired: aired,
            isManga: isManga,
          );
          if (value != null && value != progress) onChanged(value);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              EditSheetValue(
                  formatProgress(progress, total: total, aired: aired)),
              const SizedBox(width: 6),
              Icon(Icons.edit_rounded, size: 14, color: c.accentText),
            ],
          ),
        ),
      ),
    );
  }
}

/// Saisie directe de la progression. Renvoie la valeur bornée, ou null si
/// l'utilisateur annule.
Future<int?> showProgressInputDialog(
  BuildContext context, {
  required int progress,
  required int? total,
  required bool isManga,
  int? aired,
}) {
  return showDialog<int>(
    context: context,
    builder: (_) => _ProgressInputDialog(
      progress: progress,
      total: total,
      aired: aired,
      isManga: isManga,
    ),
  );
}

class _ProgressInputDialog extends StatefulWidget {
  const _ProgressInputDialog({
    required this.progress,
    required this.total,
    required this.isManga,
    this.aired,
  });

  final int progress;
  final int? total;
  final int? aired;
  final bool isManga;

  @override
  State<_ProgressInputDialog> createState() => _ProgressInputDialogState();
}

class _ProgressInputDialogState extends State<_ProgressInputDialog> {
  late final _controller = TextEditingController(text: '${widget.progress}')
    ..selection = TextSelection(
        baseOffset: 0, extentOffset: '${widget.progress}'.length);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = parseProgressInput(_controller.text, widget.total,
        aired: widget.aired);
    if (value != null) Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final total = widget.total;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF101A33) : Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: isDark
            ? BorderSide(color: Colors.white.withValues(alpha: 0.1))
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              (widget.isManga
                      ? 'sheet_progress_input_chapters'
                      : 'sheet_progress_input_episodes')
                  .tr(),
              style: text.headlineSmall?.copyWith(fontSize: 17, color: c.text1),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(5),
              ],
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              style: text.headlineSmall?.copyWith(color: c.text1),
              decoration: InputDecoration(
                suffixText: total != null && total > 0
                    ? '/ $total'
                    : (widget.aired ?? 0) > 0
                        ? 'sheet_progress_released'
                            .tr(namedArgs: {'count': '${widget.aired}'})
                        : null,
              ),
            ),
            const SizedBox(height: 17),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'dialog_cancel'.tr(),
                    variant: AppButtonVariant.secondary,
                    expand: true,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AppButton(
                    label: 'sheet_progress_input_confirm'.tr(),
                    expand: true,
                    onPressed: _submit,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Boutons − / + de 44 px autour d'une barre en dégradé qu'on peut glisser
/// (quand le total est connu). Un appui long sur − / + fait défiler de plus
/// en plus vite.
class ProgressStepper extends StatefulWidget {
  const ProgressStepper({
    super.key,
    required this.progress,
    required this.total,
    required this.onChanged,
    this.aired,
  });

  final int progress;
  final int? total;

  /// Épisodes déjà sortis : repère de la barre quand le total est inconnu.
  final int? aired;
  final ValueChanged<int> onChanged;

  @override
  State<ProgressStepper> createState() => _ProgressStepperState();
}

class _ProgressStepperState extends State<ProgressStepper> {
  Timer? _repeat;
  int _tick = 0;

  /// Échelle de la barre : total, sinon épisodes sortis.
  int? get _ceiling =>
      progressCeiling(total: widget.total, aired: widget.aired);

  /// Dernière valeur envoyée pendant un appui long : le parent ne s'est pas
  /// forcément reconstruit entre deux répétitions.
  int? _repeatValue;

  /// Applique [delta] et renvoie false si la butée est atteinte.
  bool _step(int delta) {
    final current = _repeatValue ?? widget.progress;
    final next =
        clampProgress(current + delta, widget.total, aired: widget.aired);
    if (next == current) return false;
    if (_repeat != null) _repeatValue = next;
    widget.onChanged(next);
    return true;
  }

  void _startRepeat(int direction) {
    _stopRepeat();
    _tick = 0;
    HapticFeedback.mediumImpact();
    _repeatValue = widget.progress;
    _repeat = Timer.periodic(const Duration(milliseconds: 90), (_) {
      // Butée atteinte : inutile de continuer
      if (!_step(direction * progressRepeatStep(_tick++))) _stopRepeat();
    });
  }

  void _stopRepeat() {
    _repeat?.cancel();
    _repeat = null;
    _repeatValue = null;
  }

  @override
  void dispose() {
    _stopRepeat();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ceiling = _ceiling;
    final progress = widget.progress;
    final canDecrement = progress > 0;
    final canIncrement = ceiling == null || progress < ceiling;

    return Row(
      children: [
        _RoundStepButton(
          icon: Icons.remove_rounded,
          tooltip: '−1',
          onTap: canDecrement ? () => _step(-1) : null,
          onLongPressStart: canDecrement ? () => _startRepeat(-1) : null,
          onLongPressEnd: _stopRepeat,
        ),
        const SizedBox(width: 13),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              void seek(double dx) {
                final next =
                    progressFromPosition(dx, constraints.maxWidth, ceiling!);
                if (next != progress) widget.onChanged(next);
              }

              final bar = GradientProgressBar(
                value: ceiling == null
                    ? 0
                    : (progress / ceiling).clamp(0.0, 1.0).toDouble(),
                height: 8,
                animate: false,
              );
              if (ceiling == null) return bar;

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) => seek(d.localPosition.dx),
                onHorizontalDragUpdate: (d) => seek(d.localPosition.dx),
                child: SizedBox(
                  height: AppSpacing.minTouch,
                  child: Center(child: bar),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 13),
        _RoundStepButton(
          icon: Icons.add_rounded,
          tooltip: '+1',
          onTap: canIncrement ? () => _step(1) : null,
          onLongPressStart: canIncrement ? () => _startRepeat(1) : null,
          onLongPressEnd: _stopRepeat,
        ),
      ],
    );
  }
}

class _RoundStepButton extends StatelessWidget {
  const _RoundStepButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.onLongPressStart,
    this.onLongPressEnd,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final VoidCallback? onLongPressStart;
  final VoidCallback? onLongPressEnd;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final enabled = onTap != null;
    return Tooltip(
      message: tooltip,
      // Le tooltip ne doit pas intercepter l'appui long
      triggerMode: TooltipTriggerMode.manual,
      child: GestureDetector(
        onLongPressStart:
            onLongPressStart == null ? null : (_) => onLongPressStart!(),
        onLongPressEnd: (_) => onLongPressEnd?.call(),
        onLongPressCancel: () => onLongPressEnd?.call(),
        child: Material(
          color: c.surface2,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: enabled
                ? () {
                    HapticFeedback.selectionClick();
                    onTap!();
                  }
                : null,
            child: SizedBox(
              width: AppSpacing.minTouch,
              height: AppSpacing.minTouch,
              child: Icon(
                icon,
                size: 20,
                color: enabled ? c.text1 : c.text3.withValues(alpha: 0.5),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Note en 10 segments ───────────────────────────────────────────────────────

class ScoreSegments extends StatelessWidget {
  const ScoreSegments({
    super.key,
    required this.score,
    required this.onChanged,
  });

  /// Note de 0 à 10 (les demi-points AniList remplissent un demi-segment).
  final double score;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        void set(double next) {
          if (next == score) return;
          HapticFeedback.selectionClick();
          onChanged(next);
        }

        return Semantics(
          slider: true,
          value: score == 0 ? 'sheet_score_unrated'.tr() : '$score / 10',
          increasedValue: '${(score + 0.5).clamp(0, 10)} / 10',
          decreasedValue: '${(score - 0.5).clamp(0, 10)} / 10',
          onIncrease: () => set((score + 0.5).clamp(0, 10).toDouble()),
          onDecrease: () => set((score - 0.5).clamp(0, 10).toDouble()),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (d) => set(scoreAfterTap(
                score, scoreFromPosition(d.localPosition.dx, width))),
            onHorizontalDragUpdate: (d) =>
                set(scoreFromPosition(d.localPosition.dx, width)),
            child: SizedBox(
              height: AppSpacing.minTouch,
              child: Row(
                children: [
                  for (var i = 0; i < kScoreSegments; i++) ...[
                    if (i > 0) const SizedBox(width: 5),
                    Expanded(
                      child: _Segment(
                        fill: (score - i).clamp(0.0, 1.0),
                        color: c.star,
                        empty: c.surface2,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.fill,
    required this.color,
    required this.empty,
  });

  final double fill;
  final Color color;
  final Color empty;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.full),
      child: SizedBox(
        height: 8,
        child: ColoredBox(
          color: empty,
          child: AnimatedFractionallySizedBox(
            duration: AppMotion.press,
            alignment: Alignment.centerLeft,
            widthFactor: fill,
            heightFactor: 1,
            child: ColoredBox(color: color),
          ),
        ),
      ),
    );
  }
}

// ── Notifications ─────────────────────────────────────────────────────────────

class NotifToggleCard extends StatelessWidget {
  const NotifToggleCard({
    super.key,
    required this.enabled,
    required this.isManga,
    required this.onChanged,
  });

  final bool enabled;
  final bool isManga;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    final label =
        isManga ? 'sheet_notif_chapters'.tr() : 'sheet_notif_episodes'.tr();

    return Material(
      color: c.surface2.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(AppRadius.cover),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.cover),
        onTap: () => onChanged(!enabled),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(15, 6, 10, 6),
          child: Row(
            children: [
              Icon(
                enabled
                    ? Icons.notifications_active_rounded
                    : Icons.notifications_none_rounded,
                size: 18,
                color: enabled ? c.accentText : c.text3,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: text.titleSmall?.copyWith(
                    fontSize: 12.5,
                    color: enabled ? c.text1 : c.text2,
                  ),
                ),
              ),
              Switch(value: enabled, onChanged: onChanged),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Actions ───────────────────────────────────────────────────────────────────

class EditSheetActions extends StatelessWidget {
  const EditSheetActions({
    super.key,
    required this.isEditing,
    required this.isSaving,
    required this.isDeleting,
    required this.onSave,
    required this.onDelete,
  });

  final bool isEditing;
  final bool isSaving;
  final bool isDeleting;
  final VoidCallback onSave;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final busy = isSaving || isDeleting;
    return Row(
      children: [
        if (isEditing) ...[
          AppButton(
            label: 'sheet_remove_button'.tr(),
            variant: AppButtonVariant.destructive,
            loading: isDeleting,
            onPressed: busy ? null : onDelete,
          ),
          const SizedBox(width: 11),
        ],
        Expanded(
          child: AppButton(
            label: isEditing
                ? 'sheet_update_button'.tr()
                : 'sheet_add_button'.tr(),
            expand: true,
            loading: isSaving,
            onPressed: busy ? null : onSave,
          ),
        ),
      ],
    );
  }
}
