import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:nextarc/core/providers/theme_provider.dart';
import 'package:nextarc/core/router/app_router.dart';
import 'package:nextarc/core/theme/app_theme.dart';
import 'package:nextarc/core/services/notification_service.dart';
import 'package:nextarc/core/services/notification_prefs_repository.dart';
import 'package:nextarc/core/services/episode_checker_task.dart';
import 'package:nextarc/core/utils/hive_cache.dart';
import 'package:nextarc/features/onboarding/domain/onboarding_prefs.dart';
import 'package:nextarc/core/services/app_check_service.dart';
import 'package:nextarc/features/search/domain/search_history_service.dart';
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

/// Licences OFL des polices Google (Audiowide, Chakra Petch), affichées dans
/// « Licences » de l'écran À propos.
void _registerFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    for (final (font, file) in const [
      ('Audiowide', 'audiowide_OFL.txt'),
      ('Chakra Petch', 'chakra_petch_OFL.txt'),
    ]) {
      final license = await rootBundle.loadString('assets/licenses/$file');
      yield LicenseEntryWithLineBreaks(['google_fonts', font], license);
    }
  });
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _registerFontLicenses();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  await Firebase.initializeApp();
  await AppCheckService.activate();
  await EasyLocalization.ensureInitialized();

  await Hive.initFlutter();
  await HiveCache.init();
  await NotificationPrefsRepository.instance.init();
  await SearchHistoryService.instance.init();
  await NotificationService.instance.init();
  final onboarding = await OnboardingPrefs.load();

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
      child: ProviderScope(
        overrides: [
          onboardingDoneProvider.overrideWith((_) => onboarding.done),
          contentChoiceProvider.overrideWith((_) => onboarding.choice),
        ],
        child: const NextArcApp(),
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
      // Barre de navigation système transparente (edge-to-edge) : on voit le
      // contenu derrière. Android n'ajoute plus son voile gris, et les boutons
      // + un fin liseré restent lisibles selon le thème.
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness:
                isDark ? Brightness.light : Brightness.dark,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarContrastEnforced: false,
            systemNavigationBarDividerColor:
                (isDark ? Colors.white : Colors.black).withValues(alpha: 0.12),
            systemNavigationBarIconBrightness:
                isDark ? Brightness.light : Brightness.dark,
          ),
          child: child!,
        );
      },
    );
  }
}
