import 'package:flutter/material.dart';
import 'package:nextarc/core/theme/app_tokens.dart';

/// Sélecteur segmenté (Anime / Manga, thème, …).
class SegmentedControl<T> extends StatelessWidget {
  const SegmentedControl({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
  });

  final List<({T value, String label})> segments;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labelStyle = Theme.of(context).textTheme.labelMedium;

    // Sombre : piste surface/1, segment actif surface/2.
    // Clair : piste surface/2, segment actif blanc avec ombre légère.
    final track = isDark ? c.surface1 : c.surface2;
    final active = isDark ? c.surface2 : c.surface1;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xxs),
      decoration: BoxDecoration(
        color: track,
        borderRadius: BorderRadius.circular(AppRadius.cover),
      ),
      child: Row(
        children: [
          for (final segment in segments)
            Expanded(
              child: Semantics(
                button: true,
                selected: segment.value == selected,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    if (segment.value != selected) onChanged(segment.value);
                  },
                  child: AnimatedContainer(
                    duration: AppMotion.press,
                    constraints: const BoxConstraints(minHeight: 36),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xs, vertical: 9),
                    decoration: BoxDecoration(
                      color: segment.value == selected
                          ? active
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(9),
                      boxShadow: segment.value == selected && !isDark
                          ? const [
                              BoxShadow(
                                color: Color(0x1A0C1226),
                                blurRadius: 3,
                                offset: Offset(0, 1),
                              ),
                            ]
                          : null,
                    ),
                    child: Text(
                      segment.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: labelStyle?.copyWith(
                        color:
                            segment.value == selected ? c.text1 : c.text3,
                        fontWeight: segment.value == selected
                            ? FontWeight.w700
                            : FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
