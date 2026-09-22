import Flutter
import UIKit
import workmanager_apple

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // Notifications locales affichées aussi quand l'app est ouverte
    UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate

    // Vérification des sorties en arrière-plan (EpisodeCheckerTask.taskName,
    // déclaré dans BGTaskSchedulerPermittedIdentifiers). iOS décide du moment.
    WorkmanagerPlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
    }
    WorkmanagerPlugin.registerPeriodicTask(
      withIdentifier: "episode_check",
      frequency: NSNumber(value: 6 * 60 * 60)
    )

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
