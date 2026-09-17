import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nextarc/core/theme/app_tokens.dart';
import 'package:nextarc/core/theme/app_typography.dart';
import 'package:nextarc/core/widgets/ds/ds.dart';
import 'package:nextarc/features/auth/domain/profile_banner.dart';
import 'package:nextarc/features/watchlist/domain/firestore_watchlist_providers.dart';

/// Bannière choisie dans la feuille. [source] null = retirer le choix
/// (retour à AniList puis au dégradé).
typedef BannerPick = ({
  BannerSource? source,
  String? url,
  String? label,
  File? file,
});

/// Feuille « Choisir une bannière » : image de l'appareil ou jaquette de la
/// liste. Renvoie null si l'utilisateur ferme sans choisir.
Future<BannerPick?> showBannerPicker(
  BuildContext context, {
  String? selectedUrl,
}) {
  return showModalBottomSheet<BannerPick>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _BannerPickerSheet(selectedUrl: selectedUrl),
  );
}

class _BannerPickerSheet extends ConsumerStatefulWidget {
  const _BannerPickerSheet({this.selectedUrl});

  final String? selectedUrl;

  @override
  ConsumerState<_BannerPickerSheet> createState() => _BannerPickerSheetState();
}

class _BannerPickerSheetState extends ConsumerState<_BannerPickerSheet> {
  late String? _selectedUrl = widget.selectedUrl;
  String? _selectedLabel;

  Future<void> _pickFromDevice() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1600,
      maxHeight: 1600,
    );
    if (picked == null || !mounted) return;
    Navigator.of(context).pop<BannerPick>((
      source: BannerSource.device,
      url: null,
      label: null,
      file: File(picked.path),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final covers = [
      ...?ref.watch(firestoreWatchlistProvider).valueOrNull,
    ].where((e) => e.coverImage != null).toList()
      ..sort((a, b) => (b.updatedAt ?? DateTime(0))
          .compareTo(a.updatedAt ?? DateTime(0)));

    return ConstrainedBox(
      constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.88),
      child: Container(
        decoration: BoxDecoration(
          color: c.surface1,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          border: Border(top: BorderSide(color: c.border)),
        ),
        padding: EdgeInsets.fromLTRB(18, 12, 18, 18 + bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: c.text3.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text('banner_sheet_title'.tr(),
                      style: text.titleLarge?.copyWith(color: c.text1)),
                ),
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: c.accentText),
                  onPressed: () => Navigator.of(context).pop<BannerPick>(
                      (source: null, url: null, label: null, file: null)),
                  child: Text('banner_sheet_remove'.tr()),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Material(
              color: c.surface2,
              borderRadius: BorderRadius.circular(14),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: _pickFromDevice,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: c.accent.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Icon(Icons.upload_rounded,
                            size: 18, color: c.accentText),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('banner_sheet_device'.tr(),
                                style: text.titleSmall
                                    ?.copyWith(color: c.text1)),
                            const SizedBox(height: 2),
                            Text('banner_sheet_device_hint'.tr(),
                                style: text.bodySmall?.copyWith(
                                    color: c.text2, fontSize: 10.5)),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: c.text3),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'banner_sheet_list'
                  .tr(namedArgs: {'count': '${covers.length}'})
                  .toUpperCase(),
              style: AppTypography.overline(c.text3),
            ),
            const SizedBox(height: 10),
            if (covers.isEmpty)
              Text('banner_sheet_empty'.tr(),
                  style: text.bodySmall?.copyWith(color: c.text2))
            else
              Flexible(
                child: GridView.builder(
                  shrinkWrap: true,
                  itemCount: covers.length,
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    mainAxisExtent: 66,
                  ),
                  itemBuilder: (context, index) {
                    final entry = covers[index];
                    return _CoverTile(
                      url: entry.coverImage!,
                      title: entry.title,
                      selected: entry.coverImage == _selectedUrl,
                      onTap: () => setState(() {
                        _selectedUrl = entry.coverImage;
                        _selectedLabel = entry.title;
                      }),
                    );
                  },
                ),
              ),
            const SizedBox(height: 10),
            Text('banner_sheet_crop_hint'.tr(),
                style: text.bodySmall
                    ?.copyWith(color: c.text3, fontSize: 10.5, height: 1.5)),
            const SizedBox(height: 14),
            AppButton(
              label: 'banner_sheet_use'.tr(),
              expand: true,
              onPressed: _selectedLabel == null
                  ? null
                  : () => Navigator.of(context).pop<BannerPick>((
                        source: BannerSource.cover,
                        url: _selectedUrl,
                        label: _selectedLabel,
                        file: null,
                      )),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoverTile extends StatelessWidget {
  const _CoverTile({
    required this.url,
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final String url;
  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: title,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
                color: selected ? c.accent : Colors.transparent, width: 2),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: Stack(
              fit: StackFit.expand,
              children: [
                CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.cover,
                  placeholder: (_, _) => ColoredBox(color: c.surface2),
                  errorWidget: (_, _, _) => ColoredBox(color: c.surface2),
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Color(0xCC060A15), Color(0x00060A15)],
                    ),
                  ),
                ),
                Positioned(
                  left: 7,
                  right: 28,
                  bottom: 6,
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                ),
                if (selected)
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: c.accentGradient,
                      ),
                      child: const Icon(Icons.check_rounded,
                          size: 13, color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
