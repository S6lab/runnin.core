import Foundation
import OSLog
import WatchConnectivity

private let wsLog = OSLog(subsystem: "ai.runnin.workout", category: "watch-session")

/// Recebe mensagens do iPhone via WatchConnectivity e roteia pra
/// `WorkoutController`. Singleton porque WCSession só aceita um delegate.
///
/// Protocolo de mensagens (acordado com `WorkoutRealtimePlugin.swift` no
/// lado iPhone):
///
/// ```
/// { "action": "startWorkout" }    // chama WorkoutController.start()
/// { "action": "stopWorkout"  }    // chama WorkoutController.stop()
/// { "action": "ping"         }    // health check; responde { "pong": true }
/// ```
class SessionDelegate: NSObject, WCSessionDelegate {
    static let shared = SessionDelegate()

    private override init() {
        super.init()
    }

    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        os_log("activation state=%d err=%{public}@", log: wsLog, type: .info,
               activationState.rawValue, error?.localizedDescription ?? "nil")
    }

    /// `sendMessage` no iPhone com replyHandler chega aqui. Mantemos a logica
    /// idempotente — chamar `start()` duas vezes seguido é seguro.
    func session(_ session: WCSession,
                 didReceiveMessage message: [String: Any],
                 replyHandler: @escaping ([String: Any]) -> Void) {
        let action = (message["action"] as? String) ?? ""
        os_log("recv action=%{public}@", log: wsLog, type: .info, action)
        switch action {
        case "startWorkout":
            WorkoutController.shared.start()
            replyHandler(["ok": true])
        case "stopWorkout":
            WorkoutController.shared.stop()
            replyHandler(["ok": true])
        case "ping":
            replyHandler(["pong": true])
        default:
            replyHandler(["ok": false, "error": "unknown_action"])
        }
    }

    /// Fallback: iPhone usa `transferUserInfo` quando Watch não está reachable.
    /// Entrega quando Watch acorda — ótimo pra stopWorkout em fim de corrida
    /// (se Watch estava no pulso e foi desligado mid-corrida).
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        let action = (userInfo["action"] as? String) ?? ""
        os_log("recv.userInfo action=%{public}@", log: wsLog, type: .info, action)
        switch action {
        case "startWorkout":
            WorkoutController.shared.start()
        case "stopWorkout":
            WorkoutController.shared.stop()
        default:
            break
        }
    }
}
