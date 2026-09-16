import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nextarc/core/theme/app_tokens.dart';
import 'package:nextarc/core/theme/app_typography.dart';
import 'package:nextarc/core/widgets/ds/ds.dart';
import 'package:nextarc/features/browse/domain/active_filters.dart';
import 'package:nextarc/features/browse/domain/browse_provider.dart';
import 'package:nextarc/features/browse/domain/filter_params.dart';

/// Ouvre la feuille de filtres et retourne les nouveaux [FilterParams],
/// ou null si l'utilisateur a fermé sans valider.
Future<FilterParams?> showFilterSheet(
  BuildContext context, {
  required FilterParams current,
}) {
  return showModalBottomSheet<FilterParams>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _FilterSheet(current: current),
  );
}

// ── Libellés partagés (écran et feuille) ──────────────────────────────────────

/// Libellé d'un filtre actif (« Action », « TV », « En cours », « 2018–2024 »,
/// « Score 8+ »).
String activeFilterLabel(ActiveFilter filter) {
  switch (filter.kind) {
    case ActiveFilterKind.genre:
      return filter.value;
    case ActiveFilterKind.format:
      return FilterParams.animeFormats
          .firstWhere((f) => f.value == filter.value,
              orElse: () => (value: filter.value, label: filter.value))
          .label;
    case ActiveFilterKind.status:
      return FilterParams.statusOptions
          .firstWhere((s) => s.value == filter.value,
              orElse: () => (value: filter.value, label: filter.value))
          .label;
    case ActiveFilterKind.year:
      final parts = filter.value.split('-');
      final from = parts.first;
      final to = parts.length > 1 ? parts[1] : '';
      if (from.isNotEmpty && to.isNotEmpty) return '$from–$to';
      if (from.isNotEmpty) {
        return 'filter_year_since'.tr(namedArgs: {'year': from});
      }
      return 'filter_year_until'.tr(namedArgs: {'year': to});
    case ActiveFilterKind.minScore:
      return 'filter_score_chip'.tr(namedArgs: {'score': filter.value});
  }
}

/// « 3 filtres », « 1 filtre ».
String filterCountLabel(int count) => count == 1
    ? 'filter_count_one'.tr()
    : 'filter_count'.tr(namedArgs: {'count': '$count'});

/// Total de résultats lisible (AniList plafonne le total).
String resultCountLabel(BuildContext context, int total) {
  final numbers = NumberFormat.decimalPattern(context.locale.toString());
  if (total >= anilistTotalCap) {
    return 'browse_results_many'
        .tr(namedArgs: {'count': numbers.format(anilistTotalCap)});
  }
  return switch (total) {
    0 => 'browse_results_zero'.tr(),
    1 => 'browse_results_one'.tr(),
    _ => 'browse_results'.tr(namedArgs: {'count': numbers.format(total)}),
  };
}

/// Chip de filtre actif avec un × (fond accent 18 %, bordure 45 %).
class ActiveFilterChip extends StatelessWidget {
  const ActiveFilterChip({
    super.key,
    required this.label,
    required this.onRemove,
  });

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Semantics(
      button: true,
      label: '${'filter_remove'.tr()} $label',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.full),
        onTap: () {
          HapticFeedback.selectionClick();
          onRemove();
        },
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSpacing.minTouch),
          child: Center(
            widthFactor: 1,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 7, 9, 7),
              decoration: BoxDecoration(
                color: c.accent.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(AppRadius.full),
                border:
                    Border.all(color: c.accentText.withValues(alpha: 0.45)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: c.statusCompletedText, fontSize: 11.5),
                  ),
                  const SizedBox(width: 5),
                  Icon(Icons.close_rounded, size: 14, color: c.accentText),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Barre d'état de liste : « N résultats » à gauche, « N filtres » +
/// Réinitialiser à droite.
class FilterStatusBar extends StatelessWidget {
  const FilterStatusBar({
    super.key,
    required this.resultLabel,
    required this.filterCount,
    required this.onReset,
  });

  final String? resultLabel;
  final int filterCount;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    return SizedBox(
      height: 36,
      child: Row(
        children: [
          Expanded(
            child: resultLabel == null
                ? Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: 84,
                      height: 12,
                      decoration: BoxDecoration(
                        color: c.surface2,
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                    ),
                  )
                : Text(resultLabel!,
                    style: text.labelMedium
                        ?.copyWith(color: c.text1, fontSize: 12.5)),
          ),
          if (filterCount > 0) ...[
            Text(filterCountLabel(filterCount),
                style: text.labelMedium
                    ?.copyWith(color: c.text2, fontSize: 11.5)),
            const SizedBox(width: 9),
            _OutlinePill(label: 'browse_reset'.tr(), onTap: onReset),
          ],
        ],
      ),
    );
  }
}

class _OutlinePill extends StatelessWidget {
  const _OutlinePill({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.full),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(color: c.border),
        ),
        child: Text(
          label,
          style: Theme.of(context)
              .textTheme
              .labelMedium
              ?.copyWith(color: c.accentText, fontSize: 11),
        ),
      ),
    );
  }
}

// ── Feuille ───────────────────────────────────────────────────────────────────

class _FilterSheet extends ConsumerStatefulWidget {
  const _FilterSheet({required this.current});

  final FilterParams current;

  @override
  ConsumerState<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<_FilterSheet> {
  late FilterParams _params = widget.current;

  /// Paramètres utilisés pour compter les résultats (après un court délai,
  /// pour ne pas lancer une requête à chaque chip touchée).
  late FilterParams _countParams = widget.current;
  Timer? _countTimer;

  @override
  void dispose() {
    _countTimer?.cancel();
    super.dispose();
  }

  void _update(FilterParams next) {
    setState(() => _params = next);
    _countTimer?.cancel();
    _countTimer = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _countParams = _params);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    final isAnime = _params.mediaType == 'ANIME';
    final genres =
        isAnime ? FilterParams.animeGenres : FilterParams.mangaGenres;
    final active = activeFiltersOf(_params);
    final media = MediaQuery.of(context);

    final countAsync =
        ref.watch(filteredBrowseProvider((params: _countParams, page: 1)));
    final upToDate = identical(_countParams, _params);
    final total = upToDate ? countAsync.valueOrNull?.total : null;
    final String cta;
    if (total == null) {
      cta = 'filter_see_results'.tr();
    } else if (total == 0) {
      cta = 'browse_results_zero'.tr();
    } else {
      cta = 'filter_see'.tr(namedArgs: {
        'results': resultCountLabel(context, total),
      });
    }

    return Container(
      constraints: BoxConstraints(maxHeight: media.size.height * 0.92),
      decoration: BoxDecoration(
        color: c.surface1,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        border: Border(top: BorderSide(color: c.border)),
      ),
      padding: EdgeInsets.fromLTRB(
          AppSpacing.screen, 12, AppSpacing.screen, 16 + media.viewInsets.bottom),
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
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: Text('browse_filters'.tr(),
                    style: text.headlineSmall
                        ?.copyWith(fontSize: 18, color: c.text1)),
              ),
              if (active.isNotEmpty) ...[
                Text(filterCountLabel(active.length),
                    style: text.labelMedium
                        ?.copyWith(color: c.text2, fontSize: 11.5)),
                const SizedBox(width: 9),
                _OutlinePill(
                  label: 'browse_reset'.tr(),
                  onTap: () =>
                      _update(FilterParams(mediaType: _params.mediaType)),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          SegmentedControl<String>(
            segments: const [
              (value: 'ANIME', label: 'Anime'),
              (value: 'MANGA', label: 'Manga'),
            ],
            selected: _params.mediaType,
            // Genres et formats diffèrent entre anime et manga
            onChanged: (type) => _update(_params.copyWith(
              mediaType: type,
              genres: const [],
              formats: const [],
            )),
          ),
          if (active.isNotEmpty)
            SizedBox(
              height: AppSpacing.minTouch,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: active.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) => ActiveFilterChip(
                  label: activeFilterLabel(active[i]),
                  onRemove: () => _update(active[i].remove(_params)),
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.xs),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                _Section(
                  label: 'filter_sort'.tr(),
                  child: _PillWrap(children: [
                    for (final opt in FilterParams.sortOptions)
                      _SelectPill(
                        label: opt.label,
                        selected: _params.sort == opt.value,
                        onTap: () =>
                            _update(_params.copyWith(sort: opt.value)),
                      ),
                  ]),
                ),
                _Section(
                  label: 'filter_genres'.tr(),
                  trailing: _params.genres.isEmpty
                      ? null
                      : '${_params.genres.length}',
                  child: _PillWrap(children: [
                    for (final g in genres)
                      _SelectPill(
                        label: g,
                        selected: _params.genres.contains(g),
                        onTap: () {
                          final list = List<String>.from(_params.genres);
                          list.contains(g) ? list.remove(g) : list.add(g);
                          _update(_params.copyWith(genres: list));
                        },
                      ),
                  ]),
                ),
                if (isAnime)
                  _Section(
                    label: 'filter_format'.tr(),
                    child: _PillWrap(children: [
                      for (final f in FilterParams.animeFormats)
                        _SelectPill(
                          label: f.label,
                          selected: _params.formats.contains(f.value),
                          onTap: () {
                            final list = List<String>.from(_params.formats);
                            list.contains(f.value)
                                ? list.remove(f.value)
                                : list.add(f.value);
                            _update(_params.copyWith(formats: list));
                          },
                        ),
                    ]),
                  ),
                _Section(
                  label: 'filter_status'.tr(),
                  child: _PillWrap(children: [
                    for (final s in FilterParams.statusOptions)
                      _SelectPill(
                        label: s.label,
                        selected: _params.status == s.value,
                        onTap: () => _update(_params.status == s.value
                            ? _params.copyWith(clearStatus: true)
                            : _params.copyWith(status: s.value)),
                      ),
                  ]),
                ),
                _Section(
                  label: 'filter_year'.tr(),
                  child: Row(
                    children: [
                      Expanded(
                        child: _YearField(
                          label: 'filter_year_from'.tr(),
                          value: _params.yearFrom,
                          onChanged: (v) => _update(v == null
                              ? _params.copyWith(clearYearFrom: true)
                              : _params.copyWith(yearFrom: v)),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _YearField(
                          label: 'filter_year_to'.tr(),
                          value: _params.yearTo,
                          onChanged: (v) => _update(v == null
                              ? _params.copyWith(clearYearTo: true)
                              : _params.copyWith(yearTo: v)),
                        ),
                      ),
                    ],
                  ),
                ),
                _Section(
                  label: 'filter_min_score'.tr(),
                  child: SegmentedControl<int>(
                    segments: [
                      for (final step in minScoreSteps)
                        (
                          value: step ?? 0,
                          label: step == null ? 'filter_any'.tr() : '$step+',
                        ),
                    ],
                    selected: _params.minScore ?? 0,
                    onChanged: (v) => _update(v == 0
                        ? _params.copyWith(clearMinScore: true)
                        : _params.copyWith(minScore: v)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: cta,
            expand: true,
            onPressed: () => Navigator.of(context).pop(_params),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.label, required this.child, this.trailing});

  final String label;
  final String? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(label.toUpperCase(),
                    style: AppTypography.overline(c.text3)),
              ),
              if (trailing != null)
                Text(trailing!, style: AppTypography.overline(c.accentText)),
            ],
          ),
          const SizedBox(height: 9),
          child,
        ],
      ),
    );
  }
}

class _PillWrap extends StatelessWidget {
  const _PillWrap({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) =>
      Wrap(spacing: 8, runSpacing: 8, children: children);
}

/// Chip sélectionnable de 36 px (dégradé accent quand choisie).
class _SelectPill extends StatelessWidget {
  const _SelectPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: AppMotion.press,
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 13),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: selected ? c.accentGradient : null,
            color: selected ? null : c.surface2,
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: selected ? Colors.white : c.text2,
                  fontSize: 12,
                ),
          ),
        ),
      ),
    );
  }
}

class _YearField extends StatelessWidget {
  const _YearField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  static const _minYear = 1960;

  final String label;
  final int? value;
  final void Function(int?) onChanged;

  @override
  Widget build(BuildContext context) {
    final maxYear = DateTime.now().year + 2;
    return TextFormField(
      initialValue: value?.toString() ?? '',
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
      ),
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(4),
      ],
      onChanged: (s) {
        final v = int.tryParse(s);
        if (v == null) {
          onChanged(null);
        } else if (v >= _minYear && v <= maxYear) {
          onChanged(v);
        }
      },
    );
  }
}
