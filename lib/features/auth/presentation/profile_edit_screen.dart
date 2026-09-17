import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nextarc/core/theme/app_tokens.dart';
import 'package:nextarc/core/theme/app_typography.dart';
import 'package:nextarc/core/widgets/ds/ds.dart';
import 'package:nextarc/features/auth/data/profile_service.dart';
import 'package:nextarc/features/auth/domain/auth_providers.dart';
import 'package:nextarc/features/auth/domain/profile_banner.dart';
import 'package:nextarc/features/auth/domain/user_model.dart';
import 'package:nextarc/features/auth/presentation/banner_picker_sheet.dart';
import 'package:nextarc/features/auth/presentation/profile_banner_view.dart';

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

/// Longueur maximale du pseudo.
const int profileNameMaxLength = 24;

/// Écran « Modifier le profil » : aperçu, photo, pseudo et bannière.
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

  // Bannière en cours d'édition
  BannerSource? _bannerSource;
  String? _bannerUrl;
  String? _bannerLabel;
  File? _bannerFile;
  bool _bannerChanged = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).valueOrNull?.user;
    _initialName = user?.displayName ?? '';
    _nameCtrl.text = _initialName;
    _bannerSource = user?.bannerSource;
    _bannerUrl = user?.bannerUrl;
    _bannerLabel = user?.bannerLabel;
    _nameCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  // ── Photo ─────────────────────────────────────────────────────────────────

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
    final c = AppColors.of(context);
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: c.surface1,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.photo_library_outlined, color: c.accentText),
              title: Text('profile_edit_gallery'.tr()),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: Icon(Icons.camera_alt_outlined, color: c.accentText),
              title: Text('profile_edit_camera'.tr()),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
  }

  // ── Bannière ──────────────────────────────────────────────────────────────

  void _setBanner(BannerPick pick) {
    setState(() {
      _bannerSource = pick.source;
      _bannerUrl = pick.url;
      _bannerLabel = pick.label;
      _bannerFile = pick.file;
      _bannerChanged = true;
    });
  }

  Future<void> _openBannerPicker() async {
    final pick = await showBannerPicker(
      context,
      selectedUrl: _bannerSource == BannerSource.cover ? _bannerUrl : null,
    );
    if (pick != null) _setBanner(pick);
  }

  // ── Enregistrement ────────────────────────────────────────────────────────

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

      if (_bannerChanged) {
        await _svc.updateBanner(
          source: _bannerSource,
          url: _bannerUrl,
          label: _bannerLabel,
          file: _bannerFile,
        );
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
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final anilistBanner = user?.bannerImage;

    final selected = _bannerFile != null
        ? BannerSource.device
        : effectiveBannerSource(
            source: _bannerSource,
            chosenUrl: _bannerUrl,
            anilistBanner: anilistBanner,
          );
    final previewUrl = _bannerFile != null
        ? null
        : resolveBannerUrl(
            source: _bannerSource,
            chosenUrl: _bannerUrl,
            anilistBanner: anilistBanner,
          );
    final chipLabel = switch (selected) {
      BannerSource.cover =>
        'banner_chip_cover'.tr(namedArgs: {'title': _bannerLabel ?? ''}),
      BannerSource.device => 'banner_chip_device'.tr(),
      BannerSource.anilist => 'banner_chip_anilist'.tr(),
      BannerSource.gradient => 'banner_chip_gradient'.tr(),
    };

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screen - 4, AppSpacing.xs, AppSpacing.screen, 8),
              child: Row(
                children: [
                  RoundIconButton(
                    icon: Icons.arrow_back_rounded,
                    tooltip:
                        MaterialLocalizations.of(context).backButtonTooltip,
                    color: c.accentText,
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('profile_edit_title'.tr(),
                        style: text.titleLarge?.copyWith(color: c.text1)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screen, AppSpacing.xs, AppSpacing.screen,
                    AppSpacing.md),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Aperçu ───────────────────────────────────────
                      Row(
                        children: [
                          Expanded(child: _Overline('profile_edit_preview'.tr())),
                          TextButton(
                            style: TextButton.styleFrom(
                                foregroundColor: c.accentText),
                            onPressed: _saving ? null : _openBannerPicker,
                            child: Text('profile_edit_change_banner'.tr()),
                          ),
                        ],
                      ),
                      _Preview(
                        bannerUrl: previewUrl,
                        bannerFile: _bannerFile,
                        chipLabel: chipLabel,
                        avatarFile: _pickedImage,
                        avatarUrl: user?.avatar,
                        name: _nameCtrl.text.trim().isEmpty
                            ? _initialName
                            : _nameCtrl.text.trim(),
                      ),

                      // ── Photo ────────────────────────────────────────
                      const SizedBox(height: 18),
                      _Overline('profile_edit_photo_section'.tr()),
                      const SizedBox(height: 10),
                      _PhotoRow(
                        user: user,
                        pickedImage: _pickedImage,
                        onChange: _saving ? null : _pickImage,
                      ),

                      // ── Pseudo ───────────────────────────────────────
                      const SizedBox(height: 18),
                      _Overline('profile_edit_name_section'.tr()),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _nameCtrl,
                        enabled: !_saving,
                        textCapitalization: TextCapitalization.words,
                        maxLength: profileNameMaxLength,
                        style: text.titleSmall?.copyWith(color: c.text1),
                        decoration: InputDecoration(
                          hintText: 'auth_field_name'.tr(),
                          helperText: 'profile_edit_name_hint'.tr(),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'auth_field_name_required'.tr()
                            : null,
                      ),

                      // ── Bannière ─────────────────────────────────────
                      const SizedBox(height: 12),
                      _Overline('profile_edit_banner_section'.tr()),
                      const SizedBox(height: 10),
                      _BannerOption(
                        preview: _bannerFile != null
                            ? Image.file(_bannerFile!, fit: BoxFit.cover)
                            : (_bannerSource == BannerSource.cover ||
                                        _bannerSource == BannerSource.device) &&
                                    _bannerUrl != null
                                ? CachedNetworkImage(
                                    imageUrl: _bannerUrl!, fit: BoxFit.cover)
                                : Icon(Icons.image_outlined,
                                    size: 16, color: c.accentText),
                        title: selected == BannerSource.device
                            ? 'banner_device_title'.tr()
                            : 'banner_cover_title'.tr(),
                        subtitle: selected == BannerSource.cover
                            ? (_bannerLabel ?? '')
                            : selected == BannerSource.device
                                ? 'banner_device_subtitle'.tr()
                                : 'banner_pick_subtitle'.tr(),
                        selected: selected == BannerSource.cover ||
                            selected == BannerSource.device,
                        onTap: _saving ? null : _openBannerPicker,
                      ),
                      if (anilistBanner != null) ...[
                        const SizedBox(height: 9),
                        _BannerOption(
                          preview: CachedNetworkImage(
                              imageUrl: anilistBanner, fit: BoxFit.cover),
                          title: 'banner_anilist_title'.tr(),
                          subtitle: 'banner_anilist_subtitle'.tr(namedArgs: {
                            'name': user?.anilistName ?? user?.name ?? '',
                          }),
                          selected: selected == BannerSource.anilist,
                          onTap: _saving
                              ? null
                              : () => _setBanner((
                                    source: BannerSource.anilist,
                                    url: null,
                                    label: null,
                                    file: null,
                                  )),
                        ),
                      ],
                      const SizedBox(height: 9),
                      _BannerOption(
                        preview: DecoratedBox(
                          decoration: BoxDecoration(
                              gradient: profileHeaderGradient(context)),
                        ),
                        title: 'banner_gradient_title'.tr(),
                        subtitle: 'banner_gradient_subtitle'.tr(),
                        selected: selected == BannerSource.gradient,
                        onTap: _saving
                            ? null
                            : () => _setBanner((
                                  source: BannerSource.gradient,
                                  url: null,
                                  label: null,
                                  file: null,
                                )),
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
                    ],
                  ),
                ),
              ),
            ),
            // ── Enregistrer (fixe en bas) ──────────────────────────────────
            Container(
              padding: EdgeInsets.fromLTRB(
                  AppSpacing.screen, 12, AppSpacing.screen, 12 + bottomInset),
              decoration: BoxDecoration(
                color: c.navBar,
                border: Border(top: BorderSide(color: c.border)),
              ),
              child: AppButton(
                label: 'profile_edit_save'.tr(),
                expand: true,
                loading: _saving,
                onPressed: _save,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Widgets ───────────────────────────────────────────────────────────────────

class _Overline extends StatelessWidget {
  const _Overline(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Text(label.toUpperCase(),
      style: AppTypography.overline(AppColors.of(context).text3));
}

/// Aperçu de l'en-tête du Profil, avec un scrim sombre qui garantit la
/// lisibilité du pseudo quelle que soit l'image.
class _Preview extends StatelessWidget {
  const _Preview({
    required this.bannerUrl,
    required this.bannerFile,
    required this.chipLabel,
    required this.avatarFile,
    required this.avatarUrl,
    required this.name,
  });

  final String? bannerUrl;
  final File? bannerFile;
  final String chipLabel;
  final File? avatarFile;
  final String? avatarUrl;
  final String name;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    final ImageProvider? avatar = avatarFile != null
        ? FileImage(avatarFile!)
        : avatarUrl != null
            ? CachedNetworkImageProvider(avatarUrl!)
            : null;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 130,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ProfileBannerImage(url: bannerUrl, file: bannerFile),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Color(0xEB060A15), Color(0x26060A15)],
                  stops: [0.08, 0.7],
                ),
              ),
            ),
            Positioned(
              right: 12,
              top: 12,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xB3060A15),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text(
                  chipLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.labelSmall?.copyWith(
                      color: const Color(0xFFC3CDEA),
                      fontWeight: FontWeight.w700),
                ),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Column(
                children: [
                  Container(
                    width: 62,
                    height: 62,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: c.accentGradient,
                      border: Border.all(
                          color: const Color(0xB3060A15), width: 3),
                      image: avatar == null
                          ? null
                          : DecorationImage(image: avatar, fit: BoxFit.cover),
                    ),
                    child: avatar == null
                        ? Text(
                            name.isEmpty
                                ? '?'
                                : name.characters.first.toUpperCase(),
                            style: text.headlineSmall
                                ?.copyWith(color: Colors.white),
                          )
                        : null,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleMedium?.copyWith(
                        color: Colors.white, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoRow extends StatelessWidget {
  const _PhotoRow({
    required this.user,
    required this.pickedImage,
    required this.onChange,
  });

  final UserModel? user;
  final File? pickedImage;
  final VoidCallback? onChange;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    final url = user?.avatar;
    final ImageProvider? image = pickedImage != null
        ? FileImage(pickedImage!)
        : url != null
            ? CachedNetworkImageProvider(url)
            : null;

    final subtitle = pickedImage != null
        ? 'profile_edit_photo_new'.tr()
        : user?.customPhoto == true
            ? 'profile_edit_photo_custom'.tr()
            : user?.hasAnilist == true && url != null
                ? 'profile_edit_photo_anilist'.tr()
                : 'profile_edit_photo_account'.tr();

    return Container(
      padding: const EdgeInsets.fromLTRB(13, 12, 8, 12),
      decoration: BoxDecoration(
        color: c.surface1,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: c.accentGradient,
              image: image == null
                  ? null
                  : DecorationImage(image: image, fit: BoxFit.cover),
            ),
            child: image == null
                ? const Icon(Icons.person_rounded, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('profile_edit_photo_title'.tr(),
                    style: text.titleSmall?.copyWith(color: c.text1)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: text.bodySmall
                        ?.copyWith(color: c.text2, fontSize: 10.5)),
              ],
            ),
          ),
          TextButton(
            onPressed: onChange,
            style: TextButton.styleFrom(
              backgroundColor: c.surface2,
              foregroundColor: c.text1,
              minimumSize: const Size(0, AppSpacing.minTouch),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              shape: const StadiumBorder(),
            ),
            child: Text('profile_edit_change'.tr()),
          ),
        ],
      ),
    );
  }
}

class _BannerOption extends StatelessWidget {
  const _BannerOption({
    required this.preview,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final Widget preview;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final text = Theme.of(context).textTheme;

    return Semantics(
      selected: selected,
      child: Material(
        color: selected ? c.accent.withValues(alpha: 0.14) : c.surface1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: selected
                ? c.accent.withValues(alpha: 0.5)
                : Colors.transparent,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: ColoredBox(
                    color: c.surface2,
                    child: SizedBox(width: 52, height: 34, child: preview),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: text.titleSmall?.copyWith(
                              color: selected ? c.text1 : c.text2)),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodySmall
                              ?.copyWith(color: c.text2, fontSize: 10.5),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: selected ? c.accentGradient : null,
                    border: selected
                        ? null
                        : Border.all(color: c.text3, width: 1.5),
                  ),
                  child: selected
                      ? const Icon(Icons.check_rounded,
                          size: 13, color: Colors.white)
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
