import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nextarc/features/auth/data/profile_service.dart';
import 'package:nextarc/features/auth/domain/auth_providers.dart';
import 'package:nextarc/features/auth/domain/user_model.dart';

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
  bool _uploading = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).value?.user;
    _nameCtrl.text = user?.name ?? user?.displayName ?? '';
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
      _error = null;
    });

    try {
      // Upload avatar si nouvelle image sélectionnée
      if (_pickedImage != null) {
        setState(() => _uploading = true);
        await _svc.updateAvatar(_pickedImage!);
        setState(() => _uploading = false);
      }

      // Mise à jour du pseudo
      final newName = _nameCtrl.text.trim();
      final currentUser = fb.FirebaseAuth.instance.currentUser;
      if (newName != (currentUser?.displayName ?? '')) {
        await _svc.updateDisplayName(newName);
      }

      // Rafraîchit l'état auth
      final fbUser = fb.FirebaseAuth.instance.currentUser;
      if (fbUser != null) {
        final updatedUser = UserModel.fromFirebase(fbUser);
        ref.read(authProvider.notifier).updateUser(updatedUser);
      }

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _uploading = false;
        _saving = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final user = ref.watch(authProvider).value?.user;
    final currentAvatar = _pickedImage != null
        ? null
        : user?.avatar;

    return Scaffold(
      appBar: AppBar(
        title: Text('profile_edit_title'.tr()),
        actions: [
          TextButton(
            onPressed: (_saving || _uploading) ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text('profile_edit_save'.tr()),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const SizedBox(height: 16),

              // ── Avatar ───────────────────────────────────────────────
              GestureDetector(
                onTap: _pickImage,
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 56,
                      backgroundColor: cs.surfaceContainerHighest,
                      backgroundImage: _pickedImage != null
                          ? FileImage(_pickedImage!) as ImageProvider
                          : (currentAvatar != null
                              ? CachedNetworkImageProvider(currentAvatar)
                              : null),
                      child: (_pickedImage == null && currentAvatar == null)
                          ? Icon(Icons.person,
                              size: 56,
                              color: cs.onSurface.withValues(alpha: 0.4))
                          : null,
                    ),
                    if (_uploading)
                      const CircularProgressIndicator()
                    else
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: cs.primary,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: cs.surface, width: 2),
                        ),
                        child: Icon(Icons.camera_alt,
                            size: 16, color: cs.onPrimary),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 8),
              TextButton(
                onPressed: _pickImage,
                child: Text('profile_edit_change_photo'.tr()),
              ),

              const SizedBox(height: 24),

              // ── Pseudo ───────────────────────────────────────────────
              TextFormField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'auth_field_name'.tr(),
                  prefixIcon: const Icon(Icons.person_outline),
                  border: const OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'auth_field_name_required'.tr()
                    : null,
              ),

              // ── Erreur ───────────────────────────────────────────────
              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cs.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _error!,
                    style: TextStyle(color: cs.onErrorContainer, fontSize: 13),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
