import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:nextarc/core/router/app_router.dart';
import 'package:nextarc/features/activity/domain/activity_providers.dart';
import 'package:nextarc/features/activity/domain/month_activity.dart';
import 'package:nextarc/features/auth/domain/auth_providers.dart';
import 'package:nextarc/features/onboarding/domain/onboarding_prefs.dart';
import 'package:nextarc/features/watchlist/domain/guest_watchlist_providers.dart';
import 'package:nextarc/features/stats/domain/stats_model.dart';
import 'package:nextarc/features/stats/domain/stats_provider.dart';
import 'package:nextarc/features/stats/domain/title_promotion.dart';
import 'package:nextarc/features/stats/presentation/title_promotion_card.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  static const _storage = FlutterSecureStorage();

  /// Le récap du mois précédent est proposé pendant les premiers jours du mois.
  static const _recapPromptLastDay = 7;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Premier lancement : l'onboarding passe avant tout autre message
      if (await _maybeShowOnboarding()) return;
      await _maybeShowRecapPrompt();
    });
  }

  /// Ouvre l'onboarding pour un nouveau venu. Un utilisateur existant (compte
  /// connecté ou liste locale remplie, ex. mise à jour de l'app) ne le voit
  /// jamais : il est marqué comme vu en silence.
  Future<bool> _maybeShowOnboarding() async {
    if (ref.read(onboardingDoneProvider)) return false;
    try {
      final auth = await ref.read(authProvider.future);
      final local = await ref.read(guestWatchlistProvider.future);
      final show = shouldShowOnboarding(
        done: false,
        isAuthenticated: auth.isAuthenticated,
        hasLocalEntries: local.isNotEmpty,
      );
      if (!show) {
        ref.read(onboardingDoneProvider.notifier).state = true;
        await OnboardingPrefs.saveDone();
        return false;
      }
      if (!mounted) return false;
      context.push(AppRoutes.onboarding);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Début de mois : propose une seule fois le récap complet du mois précédent,
  /// s'il y a eu de l'activité.
  Future<void> _maybeShowRecapPrompt() async {
    final now = DateTime.now();
    if (now.day > _recapPromptLastDay) return;

    final month = previousMonthKey(now);
    final shownKey = 'recap_prompt_$month';
    try {
      if (await _storage.read(key: shownKey) != null) return;
      final recap = await ref.read(monthlyRecapProvider(month).future);
      if (recap.isEmpty || !mounted) return;
      await _storage.write(key: shownKey, value: 'shown');
      if (!mounted) return;

      final monthLabel =
          MaterialLocalizations.of(context).formatMonthYear(recap.date);
      final open = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('recap_prompt_title'.tr(namedArgs: {'month': monthLabel})),
          content: Text('recap_prompt_body'.tr(namedArgs: {
            'episodes': '${recap.episodesWatched}',
            'time': recap.watchTimeFormatted,
            'completed': '${recap.completed}',
          })),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('recap_prompt_later'.tr()),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('recap_prompt_show'.tr()),
            ),
          ],
        ),
      );
      if (open == true && mounted) {
        context.push(AppRoutes.shareStats, extra: 'previousMonth');
      }
    } catch (_) {
      // Le message est un bonus : jamais bloquant
    }
  }

  /// Compte auquel appartient le dernier titre connu : un changement de compte
  /// (connexion, déconnexion) n'est pas un passage de palier.
  String? _titleOwner;

  /// Le moment du palier : quand un seuil tombe après une mise à jour de la
  /// liste (y compris depuis la fiche, le shell reste monté en dessous).
  void _listenTitlePromotion() {
    ref.listen<AsyncValue<StatsModel>>(statsProvider, (previous, next) {
      final after = next.valueOrNull?.title;
      if (after == null) return;

      final user = ref.read(authProvider).value?.user;
      final owner = user == null
          ? 'guest'
          : user.firebaseUid ?? 'anilist_${user.id}';
      final sameOwner = owner == _titleOwner;
      _titleOwner = owner;

      final before = previous?.valueOrNull?.title;
      if (!sameOwner || before == null) return;

      final kind = titlePromotion(before: before, after: after);
      if (kind == null || !mounted) return;
      showTitlePromotion(context, title: after, kind: kind);
    });
  }

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    if (location.startsWith(AppRoutes.recommendations)) return 1;
    if (location.startsWith(AppRoutes.watchlist)) return 2;
    if (location.startsWith(AppRoutes.profile)) return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    _listenTitlePromotion();
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex(context),
        onTap: (index) {
          switch (index) {
            case 0: context.go(AppRoutes.discover);
            case 1: context.go(AppRoutes.recommendations);
            case 2: context.go(AppRoutes.watchlist);
            case 3: context.go(AppRoutes.profile);
          }
        },
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.explore_outlined),
            activeIcon: const Icon(Icons.explore),
            label: 'nav_discover'.tr(),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.recommend_outlined),
            activeIcon: const Icon(Icons.recommend),
            label: 'nav_for_you'.tr(),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.list_alt_outlined),
            activeIcon: const Icon(Icons.list_alt),
            label: 'nav_my_list'.tr(),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.person_outline),
            activeIcon: const Icon(Icons.person),
            label: 'nav_profile'.tr(),
          ),
        ],
      ),
    );
  }
}
