import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:nextarc/core/providers/theme_provider.dart';
import 'package:nextarc/core/router/app_router.dart';
import 'package:nextarc/core/theme/app_theme.dart';
import 'package:nextarc/core/services/notification_service.dart';
import 'package:nextarc/core/utils/hive_cache.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialisation Hive (stockage local)
  await Hive.initFlutter();

  // Initialisation cache requêtes AniList + préférences
  await HiveCache.init();

  // Initialisation des notifications locales
  await NotificationService.instance.init();

  runApp(
    // ProviderScope : obligatoire pour Riverpod
    const ProviderScope(
      child: NextArcApp(),
    ),
  );
}

class NextArcApp extends ConsumerWidget {
  const NextArcApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Écoute les changements de thème en temps réel
    final themeMode = ref.watch(themeProvider);

    return MaterialApp.router(
      title: 'NextArc',
      debugShowCheckedModeBanner: false,

      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode, // system par défaut → suit le téléphone

      // Navigation go_router
      routerConfig: appRouter,
    );
  }
}
