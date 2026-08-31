import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:nextarc/core/providers/theme_provider.dart';
import 'package:nextarc/core/router/app_router.dart';
import 'package:nextarc/core/theme/app_theme.dart';
import 'package:nextarc/core/services/notification_service.dart';
import 'package:nextarc/core/services/notification_prefs_repository.dart';
import 'package:nextarc/core/services/episode_checker_task.dart';
import 'package:nextarc/core/utils/hive_cache.dart';
import 'package:workmanager/workmanager.dart';

/// Point d'entrée de la tâche de fond workmanager (isolate séparé).
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    if (taskName == EpisodeCheckerTask.taskName) {
      return EpisodeCheckerTask.runInBackground();
    }
    return true;
  });
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await EasyLocalization.ensureInitialized();

  await Hive.initFlutter();
  await HiveCache.init();
  await NotificationPrefsRepository.instance.init();
  await NotificationService.instance.init();

  // Planifie la vérification périodique des épisodes (toutes les 6 h).
  // iOS : BGTaskScheduler — la fréquence exacte est à la discrétion d'iOS.
  // TODO iOS : ajouter BGTaskSchedulerPermittedIdentifiers dans Info.plist
  //       et UIBackgroundModes: [fetch, processing] pour activer le background.
  await Workmanager().initialize(callbackDispatcher);
  await Workmanager().registerPeriodicTask(
    EpisodeCheckerTask.taskName,
    EpisodeCheckerTask.taskName,
    frequency: const Duration(hours: 6),
    constraints: Constraints(networkType: NetworkType.connected),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
  );

  runApp(
    EasyLocalization(
      supportedLocales: const [
        Locale('fr'),
        Locale('en'),
        Locale('es'),
      ],
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      child: const ProviderScope(
        child: NextArcApp(),
      ),
    ),
  );
}

class NextArcApp extends ConsumerWidget {
  const NextArcApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);

    return MaterialApp.router(
      title: 'NextArc',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: appRouter,
    );
  }
}
