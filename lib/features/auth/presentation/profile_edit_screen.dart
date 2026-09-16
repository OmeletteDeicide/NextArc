import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nextarc/core/theme/app_tokens.dart';
import 'package:nextarc/core/widgets/ds/ds.dart';
import 'package:nextarc/features/auth/data/profile_service.dart';
import 'package:nextarc/features/auth/domain/auth_providers.dart';

/// Message lisible pour une erreur d'enregistrement du profil.
String profileSaveErrorKey(Object error) {
  if (error is FirebaseException) {
    return switch (error.code) {
      // Stockage des photos pas encore activé côté Firebase (bucket absent)
      'object-not-found' || 'bucket-not-found' => 'profile_edit_error_storage',
      'unauthorized' || 'permission-denied' => 'profile_edit_error_denied',
      'network-request-failed' ||
      'unavailable' ||
      'retry-limit-exceeded' =>
        'profile_edit_error_network',
      _ => 'auth_error_generic',
    };
  }
  return 'auth_error_generic';
}

/// Écran de modification du profil NextArc (pseudo + avatar).
class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _svc = ProfileService();
  final _picker = ImagePicker();

  File? _pickedImage;
  bool _saving = false;
  String? _errorKey;

  /// Pseudo affiché à l'ouverture de l'écran.
  String _initialName = '';

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).valueOrNull?.user;
    _initialName = user?.displayName ?? '';
    _nameCtrl.text = _initialName;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final source = await _showImageSourceSheet();
    if (source == null) return;

    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 512,
      maxHeight: 512,
    );
    if (picked == null) return;
    setState(() => _pickedImage = File(picked.path));
  }

  Future<ImageSource?> _showImageSourceSheet() async {
    return showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text('profile_edit_gallery'.tr()),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: Text('profile_edit_camera'.tr()),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _errorKey = null;
    });

    try {
      // Upload avatar si nouvelle image sélectionnée
      if (_pickedImage != null) await _svc.updateAvatar(_pickedImage!);

      // Seulement si l'utilisateur a changé le pseudo affiché : sinon un
      // pseudo AniList serait enregistré comme « choisi »
      final newName = _nameCtrl.text.trim();
      if (newName != _initialName) {
        await _svc.updateDisplayName(newName);
      }

      // Relit le compte (identité NextArc + AniList lié)
      await ref.read(authProvider.notifier).refreshUser();

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _errorKey = profileSaveErrorKey(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    final user = ref.watch(authProvider).valueOrNull?.user;
    final currentAvatar = _pickedImage != null ? null : user?.avatar;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screen - 4, AppSpacing.xs, AppSpacing.screen, 0),
              child: Row(
                children: [
                  Tooltip(
                    message:
                        MaterialLocalizations.of(context).backButtonTooltip,
                    child: InkResponse(
                      radius: 24,
                      onTap: () => Navigator.of(context).maybePop(),
                      child: SizedBox(
                        width: AppSpacing.minTouch,
                        height: AppSpacing.minTouch,
                        child: Center(
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                                color: c.surface2, shape: BoxShape.circle),
                            child: Icon(Icons.arrow_back_rounded,
                                size: 18, color: c.text2),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text('profile_edit_title'.tr(),
                      style: text.headlineSmall
                          ?.copyWith(fontSize: 19, color: c.text1)),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                    22, AppSpacing.lg, 22, AppSpacing.lg + bottomInset),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Avatar ───────────────────────────────────────
                      Center(
                        child: Semantics(
                          button: true,
                          label: 'profile_edit_change_photo'.tr(),
                          child: GestureDetector(
                            onTap: _saving ? null : _pickImage,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  width: 112,
                                  height: 112,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: c.accentGradient,
                                    image: _pickedImage != null
                                        ? DecorationImage(
                                            image: FileImage(_pickedImage!),
                                            fit: BoxFit.cover)
                                        : currentAvatar != null
                                            ? DecorationImage(
                                                image:
                                                    CachedNetworkImageProvider(
                                                        currentAvatar),
                                                fit: BoxFit.cover)
                                            : null,
                                  ),
                                  child: (_pickedImage == null &&
                                          currentAvatar == null)
                                      ? const Icon(Icons.person_rounded,
                                          size: 52, color: Colors.white)
                                      : null,
                                ),
                                Positioned(
                                  right: -2,
                                  bottom: -2,
                                  child: Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      gradient: c.accentGradient,
                                      shape: BoxShape.circle,
                                      border:
                                          Border.all(color: c.base, width: 3),
                                    ),
                                    child: const Icon(
                                        Icons.photo_camera_rounded,
                                        size: 16,
                                        color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Center(
                        child: TextButton(
                          style: TextButton.styleFrom(
                              foregroundColor: c.accentText),
                          onPressed: _saving ? null : _pickImage,
                          child: Text('profile_edit_change_photo'.tr()),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // ── Pseudo ───────────────────────────────────────
                      TextFormField(
                        controller: _nameCtrl,
                        enabled: !_saving,
                        textCapitalization: TextCapitalization.words,
                        maxLength: 40,
                        decoration: InputDecoration(
                          labelText: 'auth_field_name'.tr(),
                          prefixIcon: const Icon(Icons.person_outline),
                          helperText: 'profile_edit_name_hint'.tr(),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'auth_field_name_required'.tr()
                            : null,
                      ),

                      // ── Erreur ───────────────────────────────────────
                      if (_errorKey != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: c.favourite.withValues(alpha: 0.12),
                            borderRadius:
                                BorderRadius.circular(AppRadius.cover),
                            border: Border.all(
                                color: c.favourite.withValues(alpha: 0.35)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline_rounded,
                                  size: 18, color: c.statusDroppedText),
                              const SizedBox(width: AppSpacing.xs),
                              Expanded(
                                child: Text(
                                  _errorKey!.tr(),
                                  style: text.bodyMedium?.copyWith(
                                      color: c.statusDroppedText),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: AppSpacing.lg),
                      AppButton(
                        label: 'profile_edit_save'.tr(),
                        expand: true,
                        loading: _saving,
                        onPressed: _save,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
