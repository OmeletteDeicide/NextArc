import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nextarc/core/router/app_router.dart';

/// Shell principal : contient la BottomNavigationBar persistante.
class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.child});

  final Widget child;

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    if (location.startsWith(AppRoutes.recommendations)) return 1;
    if (location.startsWith(AppRoutes.watchlist)) return 2;
    if (location.startsWith(AppRoutes.profile)) return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
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
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.explore_outlined),
            activeIcon: Icon(Icons.explore),
            label: 'Découvrir',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.recommend_outlined),
            activeIcon: Icon(Icons.recommend),
            label: 'Pour toi',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list_alt_outlined),
            activeIcon: Icon(Icons.list_alt),
            label: 'Ma liste',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}
