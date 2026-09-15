import 'package:flutter/material.dart';
import 'package:nextarc/core/theme/app_tokens.dart';

/// Tuile de statistique : grand nombre + libellé.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.value,
    required this.label,
    this.valueColor,
    this.onTap,
  });

  final String value;
  final String label;
  final Color? valueColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final text = Theme.of(context).textTheme;

    return Material(
      color: c.surface1,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Réduit plutôt que de couper les longues valeurs (« 41j 16h »)
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  maxLines: 1,
                  style: text.headlineMedium
                      ?.copyWith(color: valueColor ?? c.text1),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: text.bodySmall?.copyWith(color: c.text2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
