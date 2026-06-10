import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nextarc/core/presentation/main_shell.dart';
import 'package:nextarc/features/about/presentation/about_screen.dart';
import 'package:nextarc/features/auth/presentation/profile_screen.dart';
import 'package:nextarc/features/detail/presentation/detail_screen.dart';
import 'package:nextarc/features/discover/presentation/discover_screen.dart';
import 'package:nextarc/features/search/presentation/search_screen.dart';
import 'package:nextarc/features/recommendations/presentation/recommendations_screen.dart';
import 'package:nextarc/features/settings/presentation/settings_screen.dart';
import 'package:nextarc/features/watchlist/presentation/watchlist_screen.dart';

/// Transition slide-depuis-la-droite + fade (pour détail, settings, about).
CustomTransitionPage<void> _slideFade({
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 280),
    reverseTransitionDuration: const Duration(milliseconds: 220),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.06, 0),
          end: Offset.zero,
        ).animate(curved),
        child: FadeTransition(opacity: curved, child: child),
      );
    },
  );
}

/// Transition fade pure (pour la recherche — overlay plutôt que slide).
CustomTransitionPage<void> _fade({
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 200),
    reverseTransitionDuration: const Duration(milliseconds: 160),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeInOut),
        child: child,
      );
    },
  );
}

class AppRoutes {
  static const String discover = '/';
  static const String search = '/search';
  static const String recommendations = '/recommendations';
  static const String watchlist = '/watchlist';
  static const String profile = '/profile';
  static const String detail = '/detail/:id';
  static const String about = '/about';
  static const String settings = '/settings';
}

final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.discover,
  routes: [
    ShellRoute(
      builder: (context, state, child) => MainShell(child: child),
      routes: [
        GoRoute(
          path: AppRoutes.discover,
          builder: (context, state) => const DiscoverScreen(),
        ),
        GoRoute(
          path: AppRoutes.recommendations,
          builder: (context, state) => const RecommendationsScreen(),
        ),
        GoRoute(
          path: AppRoutes.watchlist,
          builder: (context, state) => const WatchlistScreen(),
        ),
        GoRoute(
          path: AppRoutes.profile,
          builder: (context, state) => const ProfileScreen(),
        ),
      ],
    ),

    // Détail — hors shell (pas de bottom nav)
    GoRoute(
      path: '/detail/:id',
      pageBuilder: (context, state) {
        final id = int.parse(state.pathParameters['id']!);
        final extra = state.extra as Map<String, dynamic>?;
        final heroTag = extra?['heroTag'] as String?;
        final coverUrl = extra?['coverUrl'] as String?;
        return _slideFade(
          state: state,
          child: DetailScreen(animeId: id, heroTag: heroTag, coverUrl: coverUrl),
        );
      },
    ),

    // Recherche — hors shell (accessible via icône AppBar)
    GoRoute(
      path: AppRoutes.search,
      pageBuilder: (context, state) =>
          _fade(state: state, child: const SearchScreen()),
    ),

    // À propos — hors shell
    GoRoute(
      path: '/about',
      pageBuilder: (context, state) =>
          _slideFade(state: state, child: const AboutScreen()),
    ),

    // Paramètres — hors shell
    GoRoute(
      path: '/settings',
      pageBuilder: (context, state) =>
          _slideFade(state: state, child: const SettingsScreen()),
    ),
  ],
);
