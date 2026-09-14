import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Bouton ❤️ des sheets d'édition : met le média dans les favoris,
/// indépendamment de la note.
class FavouriteButton extends StatelessWidget {
  const FavouriteButton({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: 'sheet_favourite_tooltip'.tr(),
      onPressed: () {
        HapticFeedback.selectionClick();
        onChanged(!value);
      },
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 150),
        transitionBuilder: (child, anim) =>
            ScaleTransition(scale: anim, child: child),
        child: Icon(
          value ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          key: ValueKey(value),
          color: value ? Colors.redAccent : cs.onSurface.withValues(alpha: 0.45),
        ),
      ),
    );
  }
}
