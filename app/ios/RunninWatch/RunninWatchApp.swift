import SwiftUI
import WatchConnectivity

/// Entry point do app watchOS companion.
///
/// Responsabilidade mínima: ativar WCSession (pra escutar mensagens do iPhone)
/// e renderizar a ContentView que reflete o estado da `WorkoutController`.
///
/// Por que existir: Apple Watch só escreve heart rate no HK store em
/// alta frequência (~1Hz) quando há HKWorkoutSession ativa no próprio Watch.
/// Sem este app, o iPhone Runnin lê samples velhos (2-5min) durante a corrida.
/// Quando user clica "Iniciar" no iPhone, ele manda `startWorkout` via
/// WCSession — o `SessionDelegate` recebe e chama `WorkoutController.start()`.
@main
struct RunninWatchApp: App {
    @WKApplicationDelegateAdaptor(WatchAppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(WorkoutController.shared)
        }
    }
}

/// AppDelegate é onde a `WCSession` é ativada no boot do Watch app — antes
/// disso, mensagens enviadas pelo iPhone ficam encolhidas até o Watch app
/// "acordar". Mantendo a ativação no delegate (e não na SwiftUI App init)
/// garantimos que o lifecycle WatchConnectivity esteja gerenciado pelo runtime.
class WatchAppDelegate: NSObject, WKApplicationDelegate {
    func applicationDidFinishLaunching() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = SessionDelegate.shared
        session.activate()
    }
}
