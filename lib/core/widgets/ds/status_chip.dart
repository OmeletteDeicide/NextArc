import 'package:flutter/material.dart';
import 'package:nextarc/core/theme/app_tokens.dart';
import 'package:nextarc/features/watchlist/domain/media_list_entry.dart';

/// Chip de statut de liste.
/// - [selected] null → badge informatif aux couleurs du statut ;
/// - [selected] non null → chip sélectionnable (dégradé quand sélectionnée).
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.status,
    this.selected,
    this.onTap,
  });

  final ListStatus status;
  final bool? selected;
  final VoidCallback? onTap;

  /// Couleurs texte / fond d'un statut.
  static ({Color foreground, Color background}) colorsFor(
    ListStatus status,
    AppColors c,
  ) =>
      switch (status) {
        ListStatus.current => (
            foreground: c.statusCurrent,
            background: c.statusCurrent.withValues(alpha: 0.14),
          ),
        ListStatus.completed => (
            foreground: c.statusCompletedText,
            background: c.accent.withValues(alpha: 0.16),
          ),
        ListStatus.planning => (foreground: c.text2, background: c.surface2),
        ListStatus.paused => (
            foreground: c.star,
            background: c.star.withValues(alpha: 0.14),
          ),
        ListStatus.dropped => (
            foreground: c.statusDroppedText,
            background: c.favourite.withValues(alpha: 0.14),
          ),
      };

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final labelStyle = Theme.of(context).textTheme.labelMedium;
    final isSelectable = selected != null;
    final isSelected = selected ?? false;

    final Color foreground;
    final BoxDecoration decoration;
    if (isSelectable) {
      foreground = isSelected ? Colors.white : c.text2;
      decoration = BoxDecoration(
        gradient: isSelected ? c.accentGradient : null,
        color: isSelected ? null : c.surface2,
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(
          color: isSelected ? Colors.transparent : c.border,
        ),
      );
    } else {
      final colors = colorsFor(status, c);
      foreground = colors.foreground;
      decoration = BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(AppRadius.full),
      );
    }

    final chip = AnimatedContainer(
      duration: AppMotion.press,
      padding: EdgeInsets.symmetric(
        horizontal: isSelectable ? 14 : 12,
        vertical: isSelectable ? 10 : 7,
      ),
      decoration: decoration,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isSelectable && status == ListStatus.current) ...[
            Container(
              width: 6,
              height: 6,
              decoration:
                  BoxDecoration(color: foreground, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            status.label,
            style: labelStyle?.copyWith(color: foreground, fontSize: 11.5),
          ),
        ],
      ),
    );

    if (onTap == null) return chip;

    return Semantics(
      button: true,
      selected: isSelected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        // Zone tactile ≥ 44 px sans grossir le visuel
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSpacing.minTouch),
          child: Align(widthFactor: 1, heightFactor: 1, child: chip),
        ),
      ),
    );
  }
}
