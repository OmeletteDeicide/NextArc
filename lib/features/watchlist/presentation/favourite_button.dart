import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nextarc/core/theme/app_tokens.dart';

/// Bouton ❤️ des sheets d'édition : met le média dans les favoris,
/// indépendamment de la note. Pastille ronde de 40 px (zone tactile 44).
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
    final c = AppColors.of(context);
    return Tooltip(
      message: 'sheet_favourite_tooltip'.tr(),
      child: Semantics(
        button: true,
        toggled: value,
        child: InkResponse(
          radius: 24,
          onTap: () {
            HapticFeedback.selectionClick();
            onChanged(!value);
          },
          child: SizedBox(
            width: AppSpacing.minTouch,
            height: AppSpacing.minTouch,
            child: Center(
              child: AnimatedContainer(
                duration: AppMotion.press,
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: value
                      ? c.favourite.withValues(alpha: 0.16)
                      : c.surface2,
                ),
                child: AnimatedSwitcher(
                  duration: AppMotion.press,
                  transitionBuilder: (child, anim) =>
                      ScaleTransition(scale: anim, child: child),
                  child: Icon(
                    value
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    key: ValueKey(value),
                    size: 19,
                    color: value ? c.favourite : c.text3,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
