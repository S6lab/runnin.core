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
///
/// Decisão: ativar WCSession no `init()` do struct App em vez de via
/// `WKApplicationDelegateAdaptor`. WatchKit module deu "Unable to resolve
/// module dependency" no Xcode 17 SDK (deployment target watchOS 10) — sem
/// WKApplicationDelegate disponível. WCSession activation no init é
/// idempotente e roda 1x no boot, mesma garantia funcional.
@available(iOS 26.0, watchOS 10.0, *)
@main
struct RunninWatchApp: App {
    init() {
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = SessionDelegate.shared
            session.activate()
        }
        // Inicia o watchdog que detecta quando o iPhone parou de empurrar
        // contexto (app morto/swipe-up) durante uma run ativa — UI mostra
        // overlay "ENCERRAR" pra destravar a tela travada com último valor.
        Task { @MainActor in
            WatchRunState.shared.startOrphanMonitor()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(WorkoutController.shared)
                .environmentObject(WatchRunState.shared)
        }
    }
}
