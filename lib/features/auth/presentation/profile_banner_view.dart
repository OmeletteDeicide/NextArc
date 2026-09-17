import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:nextarc/core/theme/app_tokens.dart';

/// Dégradé NextArc des en-têtes de profil (bannière par défaut).
LinearGradient profileHeaderGradient(BuildContext context) {
  final c = AppColors.of(context);
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return isDark
      ? LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [const Color(0xFF1B2140), c.surface1],
          stops: const [0, 0.7],
        )
      : LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [c.accent, c.violet],
        );
}

/// Image de bannière (réseau ou fichier local) recadrée au centre, ou le
/// dégradé NextArc quand il n'y a pas d'image. Pendant le chargement comme
/// en cas d'erreur, c'est aussi le dégradé qui s'affiche : jamais une image
/// cassée.
class ProfileBannerImage extends StatelessWidget {
  const ProfileBannerImage({super.key, this.url, this.file});

  final String? url;
  final File? file;

  @override
  Widget build(BuildContext context) {
    final gradient = DecoratedBox(
      decoration: BoxDecoration(gradient: profileHeaderGradient(context)),
    );
    if (file != null) {
      return Image.file(file!,
          fit: BoxFit.cover, errorBuilder: (_, _, _) => gradient);
    }
    if (url == null) return gradient;
    return CachedNetworkImage(
      imageUrl: url!,
      fit: BoxFit.cover,
      alignment: Alignment.center,
      placeholder: (_, _) => gradient,
      errorWidget: (_, _, _) => gradient,
    );
  }
}
