import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    // Plugin custom (não vai pelo pubspec) — registra manualmente aqui.
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "WorkoutRealtimePlugin") {
      WorkoutRealtimePlugin.register(with: registrar)
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "InstagramStoriesPlugin") {
      InstagramStoriesPlugin.register(with: registrar)
    }
  }
}
