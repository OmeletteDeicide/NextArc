import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:nextarc/features/browse/domain/filter_params.dart';

/// Ouvre le bottom sheet de filtres et retourne les nouveaux [FilterParams],
/// ou null si l'utilisateur a annulé.
Future<FilterParams?> showFilterSheet(
  BuildContext context, {
  required FilterParams current,
}) {
  return showModalBottomSheet<FilterParams>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _FilterSheet(current: current),
  );
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.current});
  final FilterParams current;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late FilterParams _params;

  @override
  void initState() {
    super.initState();
    _params = widget.current;
    // Tab 0 = Anime, Tab 1 = Manga
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: _params.mediaType == 'MANGA' ? 1 : 0,
    );
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) return;
      setState(() {
        _params = _params.copyWith(
          mediaType: _tabController.index == 0 ? 'ANIME' : 'MANGA',
          genres: const [],
          formats: const [],
        );
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _apply() => Navigator.of(context).pop(_params);
  void _reset() => setState(() => _params = FilterParams(
        mediaType: _params.mediaType,
      ));

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isAnime = _params.mediaType == 'ANIME';
    final genres =
        isAnime ? FilterParams.animeGenres : FilterParams.mangaGenres;
    final currentYear = DateTime.now().year;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Column(
          children: [
            // ── Poignée ──────────────────────────────────────────────────
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: cs.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // ── En-tête ───────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text('browse_filters'.tr(),
                      style: Theme.of(context).textTheme.titleLarge),
                  const Spacer(),
                  if (_params.activeCount > 0)
                    TextButton(
                      onPressed: _reset,
                      child: Text('browse_reset'.tr()),
                    ),
                ],
              ),
            ),

            // ── Onglets Anime / Manga ─────────────────────────────────────
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Anime'),
                Tab(text: 'Manga'),
              ],
            ),

            // ── Corps scrollable ──────────────────────────────────────────
            Expanded(
              child: ListView(
                controller: scrollController,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                children: [
                  // ── Tri ─────────────────────────────────────────────────
                  _SectionLabel('filter_sort'.tr()),
                  _ChipWrap(
                    children: FilterParams.sortOptions.map((opt) {
                      final sel = _params.sort == opt.value;
                      return ChoiceChip(
                        label: Text(opt.label),
                        selected: sel,
                        onSelected: (_) => setState(
                            () => _params = _params.copyWith(sort: opt.value)),
                      );
                    }).toList(),
                  ),

                  // ── Genres ───────────────────────────────────────────────
                  _SectionLabel('filter_genres'.tr()),
                  _ChipWrap(
                    children: genres.map((g) {
                      final sel = _params.genres.contains(g);
                      return FilterChip(
                        label: Text(g),
                        selected: sel,
                        onSelected: (v) {
                          final list = List<String>.from(_params.genres);
                          v ? list.add(g) : list.remove(g);
                          setState(
                              () => _params = _params.copyWith(genres: list));
                        },
                      );
                    }).toList(),
                  ),

                  // ── Format (anime seulement) ──────────────────────────────
                  if (isAnime) ...[
                    _SectionLabel('filter_format'.tr()),
                    _ChipWrap(
                      children: FilterParams.animeFormats.map((f) {
                        final sel = _params.formats.contains(f.value);
                        return FilterChip(
                          label: Text(f.label),
                          selected: sel,
                          onSelected: (v) {
                            final list = List<String>.from(_params.formats);
                            v ? list.add(f.value) : list.remove(f.value);
                            setState(
                                () => _params = _params.copyWith(formats: list));
                          },
                        );
                      }).toList(),
                    ),
                  ],

                  // ── Statut ───────────────────────────────────────────────
                  _SectionLabel('filter_status'.tr()),
                  _ChipWrap(
                    children: FilterParams.statusOptions.map((s) {
                      final sel = _params.status == s.value;
                      return ChoiceChip(
                        label: Text(s.label),
                        selected: sel,
                        onSelected: (_) {
                          setState(() => _params = sel
                              ? _params.copyWith(clearStatus: true)
                              : _params.copyWith(status: s.value));
                        },
                      );
                    }).toList(),
                  ),

                  // ── Années ───────────────────────────────────────────────
                  _SectionLabel('filter_year'.tr()),
                  Row(
                    children: [
                      Expanded(
                        child: _YearField(
                          label: 'filter_year_from'.tr(),
                          value: _params.yearFrom,
                          minYear: 1960,
                          maxYear: currentYear + 2,
                          onChanged: (v) => setState(() => _params = v == null
                              ? _params.copyWith(clearYearFrom: true)
                              : _params.copyWith(yearFrom: v)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _YearField(
                          label: 'filter_year_to'.tr(),
                          value: _params.yearTo,
                          minYear: 1960,
                          maxYear: currentYear + 2,
                          onChanged: (v) => setState(() => _params = v == null
                              ? _params.copyWith(clearYearTo: true)
                              : _params.copyWith(yearTo: v)),
                        ),
                      ),
                    ],
                  ),

                  // ── Score minimum ─────────────────────────────────────────
                  _SectionLabel(
                      '${'filter_min_score'.tr()} : ${_params.minScore != null ? '${_params.minScore}/10' : 'filter_any'.tr()}'),
                  Slider(
                    value: (_params.minScore ?? 0).toDouble(),
                    min: 0,
                    max: 9,
                    divisions: 9,
                    label: _params.minScore != null
                        ? '${_params.minScore}/10'
                        : 'filter_any'.tr(),
                    onChanged: (v) {
                      final iv = v.round();
                      setState(() => _params = iv == 0
                          ? _params.copyWith(clearMinScore: true)
                          : _params.copyWith(minScore: iv));
                    },
                  ),

                  const SizedBox(height: 80),
                ],
              ),
            ),

            // ── Bouton Appliquer ──────────────────────────────────────────
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton(
                  onPressed: _apply,
                  style:
                      FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  child: Text('filter_apply'.tr()),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── Widgets helpers ───────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 6),
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .labelLarge
            ?.copyWith(color: Theme.of(context).colorScheme.primary),
      ),
    );
  }
}

class _ChipWrap extends StatelessWidget {
  const _ChipWrap({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 8, runSpacing: 6, children: children);
  }
}

class _YearField extends StatelessWidget {
  const _YearField({
    required this.label,
    required this.value,
    required this.minYear,
    required this.maxYear,
    required this.onChanged,
  });

  final String label;
  final int? value;
  final int minYear;
  final int maxYear;
  final void Function(int?) onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: value?.toString() ?? '',
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
        suffixIcon: value != null
            ? IconButton(
                icon: const Icon(Icons.close, size: 16),
                onPressed: () => onChanged(null),
              )
            : null,
      ),
      keyboardType: TextInputType.number,
      onChanged: (s) {
        final v = int.tryParse(s);
        if (v == null || s.isEmpty) {
          onChanged(null);
        } else if (v >= minYear && v <= maxYear) {
          onChanged(v);
        }
      },
    );
  }
}
