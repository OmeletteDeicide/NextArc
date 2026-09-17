import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nextarc/core/widgets/ds/ds.dart';
import 'package:nextarc/features/auth/domain/auth_providers.dart';

/// Demande confirmation puis délie AniList du compte NextArc (Profil et
/// Paramètres).
Future<void> confirmUnlinkAnilist(BuildContext context, WidgetRef ref) async {
  final confirmed = await showConfirmDialog(
    context,
    title: 'anilist_unlink_title'.tr(),
    message: 'anilist_unlink_body'.tr(),
    confirmLabel: 'profile_anilist_unlink'.tr(),
    destructive: true,
  );
  if (!confirmed) return;
  await ref.read(authProvider.notifier).unlinkAnilist();
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('anilist_unlink_done'.tr())),
    );
  }
}
