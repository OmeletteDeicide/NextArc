import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nextarc/core/theme/app_tokens.dart';
import 'package:nextarc/core/theme/app_typography.dart';
import 'package:nextarc/core/widgets/ds/ds.dart';
import 'package:nextarc/features/watchlist/domain/media_list_entry.dart';

// Briques visuelles communes aux trois fiches d'édition (AniList, NextArc,
// invité). Chaque fiche garde sa logique d'enregistrement.

/// Nombre de segments de la note (1 segment = 1 point sur 10).
const int kScoreSegments = 10;

/// Note après un appui sur le segment [index] (0 → 9) : toucher la note
/// actuelle l'efface, sinon la note devient le numéro du segment.
double scoreAfterSegmentTap(double current, int index) {
  final target = (index + 1).toDouble();
  return current == target ? 0 : target;
}

/// Note correspondant à une position horizontale sur la barre de segments.
double scoreFromPosition(double dx, double width) {
  if (width <= 0) return 0;
  final ratio = (dx / width).clamp(0.0, 1.0);
  return (ratio * kScoreSegments).ceilToDouble().clamp(0, 10).toDouble();
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
Future<bool> confirmRemoveFromList(BuildContext context, String content) async {
  final c = AppColors.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('sheet_delete_dialog_title'.tr()),
      content: Text(content),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text('dialog_cancel'.tr()),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: c.favourite,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text('dialog_confirm_delete'.tr()),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

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
          ?.copyWith(fontSize: 15, fontWeight: FontWeight.w800, color: color ?? c.text1),
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

/// Boutons − / + de 44 px autour d'une barre en dégradé qu'on peut glisser
/// (quand le total est connu).
class ProgressStepper extends StatelessWidget {
  const ProgressStepper({
    super.key,
    required this.progress,
    required this.total,
    required this.onChanged,
  });

  final int progress;
  final int? total;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final knownTotal = total != null && total! > 0;
    final canDecrement = progress > 0;
    final canIncrement = !knownTotal || progress < total!;

    return Row(
      children: [
        _RoundStepButton(
          icon: Icons.remove_rounded,
          tooltip: '−1',
          onTap: canDecrement ? () => onChanged(progress - 1) : null,
        ),
        const SizedBox(width: 13),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              void seek(double dx) {
                final next =
                    progressFromPosition(dx, constraints.maxWidth, total!);
                if (next != progress) onChanged(next);
              }

              final bar = GradientProgressBar(
                value: knownTotal ? progress / total! : 0,
                height: 8,
                animate: false,
              );
              if (!knownTotal) return bar;

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
          onTap: canIncrement ? () => onChanged(progress + 1) : null,
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
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final enabled = onTap != null;
    return Tooltip(
      message: tooltip,
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
          increasedValue: '${(score + 1).clamp(0, 10)} / 10',
          decreasedValue: '${(score - 1).clamp(0, 10)} / 10',
          onIncrease: () => set((score.floorToDouble() + 1).clamp(0, 10)),
          onDecrease: () => set((score.ceilToDouble() - 1).clamp(0, 10)),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (d) {
              final index = (d.localPosition.dx / width * kScoreSegments)
                  .floor()
                  .clamp(0, kScoreSegments - 1);
              set(scoreAfterSegmentTap(score, index));
            },
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
