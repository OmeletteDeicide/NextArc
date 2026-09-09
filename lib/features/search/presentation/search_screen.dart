import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nextarc/core/constants/app_constants.dart';
import 'package:nextarc/core/widgets/anime_card.dart';
import 'package:nextarc/features/auth/domain/auth_providers.dart';
import 'package:nextarc/features/auth/domain/user_model.dart';
import 'package:nextarc/features/search/domain/search_history_service.dart';
import 'package:nextarc/features/search/domain/search_providers.dart';
import 'package:nextarc/features/watchlist/presentation/watchlist_sheet_helper.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<String> _history = [];

  @override
  void initState() {
    super.initState();
    _history = SearchHistoryService.instance.history;
  }

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: AppConstants.searchDebounceMs),
      () {
        ref.read(searchQueryProvider.notifier).state = value;
        if (value.trim().isNotEmpty) {
          SearchHistoryService.instance.add(value.trim()).then((_) {
            if (mounted) setState(() => _history = SearchHistoryService.instance.history);
          });
        }
      },
    );
  }

  void _applyHistory(String query) {
    HapticFeedback.selectionClick();
    _controller.text = query;
    _controller.selection =
        TextSelection.collapsed(offset: query.length);
    ref.read(searchQueryProvider.notifier).state = query;
    SearchHistoryService.instance.add(query);
  }

  void _removeHistory(String query) {
    SearchHistoryService.instance.remove(query).then((_) {
      if (mounted) setState(() => _history = SearchHistoryService.instance.history);
    });
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(searchResultsProvider);
    final query = ref.watch(searchQueryProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          onChanged: _onSearchChanged,
          style: TextStyle(color: cs.onSurface),
          decoration: InputDecoration(
            hintText: 'search_hint'.tr(),
            hintStyle:
                TextStyle(color: cs.onSurface.withValues(alpha: 0.4)),
            border: InputBorder.none,
            suffixIcon: query.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear,
                        size: 18,
                        color: cs.onSurface.withValues(alpha: 0.5)),
                    onPressed: () {
                      _controller.clear();
                      ref.read(searchQueryProvider.notifier).state = '';
                    },
                  )
                : null,
          ),
        ),
      ),
      body: results.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _buildError(error),
        data: (result) {
          if (result == null) return _buildIdle(cs);
          if (result.items.isEmpty) return _buildEmpty(query, cs);
          return _buildGrid(result.items);
        },
      ),
    );
  }

  Widget _buildIdle(ColorScheme cs) {
    if (_history.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 64,
                color: cs.onSurface.withValues(alpha: 0.12)),
            const SizedBox(height: 16),
            Text('search_idle_message'.tr(),
                style:
                    TextStyle(color: cs.onSurface.withValues(alpha: 0.38))),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding:
              const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Row(
            children: [
              Text('search_history'.tr(),
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface.withValues(alpha: 0.45),
                      letterSpacing: 0.8)),
              const Spacer(),
              TextButton(
                onPressed: () {
                  SearchHistoryService.instance.clear().then((_) {
                    if (mounted) setState(() => _history = []);
                  });
                },
                style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                child: Text('search_history_clear'.tr(),
                    style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurface.withValues(alpha: 0.45))),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.zero,
            itemCount: _history.length,
            itemBuilder: (context, i) {
              final q = _history[i];
              return ListTile(
                dense: true,
                leading: Icon(Icons.history,
                    size: 18,
                    color: cs.onSurface.withValues(alpha: 0.38)),
                title: Text(q, style: const TextStyle(fontSize: 14)),
                trailing: IconButton(
                  icon: Icon(Icons.close,
                      size: 16,
                      color: cs.onSurface.withValues(alpha: 0.3)),
                  onPressed: () => _removeHistory(q),
                ),
                onTap: () => _applyHistory(q),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmpty(String query, ColorScheme cs) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 48,
              color: cs.onSurface.withValues(alpha: 0.24)),
          const SizedBox(height: 12),
          Text('search_empty_results'.tr(namedArgs: {'query': query}),
              style:
                  TextStyle(color: cs.onSurface.withValues(alpha: 0.54))),
        ],
      ),
    );
  }

  Widget _buildError(Object error) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off_rounded,
              color: cs.onSurface.withValues(alpha: 0.38), size: 40),
          const SizedBox(height: 12),
          Text(error.toString(),
              textAlign: TextAlign.center,
              style:
                  TextStyle(color: cs.onSurface.withValues(alpha: 0.54))),
          const SizedBox(height: 16),
          FilledButton.icon(
            icon: const Icon(Icons.refresh),
            label: Text('action_retry'.tr()),
            onPressed: () => ref.invalidate(searchResultsProvider),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(List items) {
    final user = ref.watch(authProvider).whenOrNull<UserModel?>(
          data: (a) => a.user,
        );

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisExtent: 240,
        crossAxisSpacing: 12,
        mainAxisSpacing: 16,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final anime = items[index];
        final tag = 'search_$index';
        return AnimeCard(
          anime: anime,
          heroTag: tag,
          onTap: () => context.push('/detail/${anime.id}',
              extra: {'heroTag': tag, 'coverUrl': anime.coverImage}),
          width: double.infinity,
          onWatchlistTap: () => openWatchlistSheet(
            context, ref,
            anime: anime,
            user: user,
          ),
        );
      },
    );
  }
}
