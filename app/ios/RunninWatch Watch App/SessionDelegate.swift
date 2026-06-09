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
        // Apple só dispara `didReceiveApplicationContext` em pushes NOVOS após
        // activation. O snapshot mais recente já entregue fica em
        // `receivedApplicationContext` (1 último valor, dedup). Sem aplicar
        // aqui, o Watch abre cego ao estado conhecido (ex: TypeSelector mostra
        // só CORRIDA LIVRE no primeiro abrir, sem SESSÃO DO DIA, mesmo que o
        // iPhone já tenha empurrado o today_session no boot).
        let cached = session.receivedApplicationContext
        if !cached.isEmpty {
            os_log("activation.apply_cached keys=%{public}@", log: wsLog, type: .info,
                   cached.keys.joined(separator: ","))
            Task { @MainActor in
                WatchRunState.shared.update(from: cached)
            }
        }
    }

    // Métodos required em iOS — implementados pra resolver erro de conformance
    // mesmo em build watchOS (Xcode 17 SDK aplica check cross-platform).
    // Em watchOS NUNCA são chamados; em iOS recriam o session.
    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }
    #endif

    /// State snapshot vindo do iPhone via `updateApplicationContext` (Watch
    /// recebe último valor com dedup automático). Atualiza o singleton
    /// `WatchRunState` que toda a UI Watch observa.
    func session(_ session: WCSession,
                 didReceiveApplicationContext applicationContext: [String: Any]) {
        let typeStr = (applicationContext["type"] as? String) ?? "?"
        let statusStr = (applicationContext["status"] as? String) ?? "-"
        os_log("recv.context type=%{public}@ status=%{public}@ keys=%{public}@",
               log: wsLog, type: .info, typeStr, statusStr,
               applicationContext.keys.joined(separator: ","))
        Task { @MainActor in
            WatchRunState.shared.update(from: applicationContext)
        }
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
            if #available(iOS 26.0, watchOS 10.0, *) {
                WorkoutController.shared.start()
            }
            replyHandler(["ok": true])
        case "stopWorkout":
            if #available(iOS 26.0, watchOS 10.0, *) {
                WorkoutController.shared.stop()
            }
            replyHandler(["ok": true])
        case "ping":
            replyHandler(["pong": true])
        default:
            replyHandler(["ok": false, "error": "unknown_action"])
        }
    }

    /// Push de BPM Watch→iPhone via WCSession. iOS suspende
    /// HKAnchoredObjectQuery no phone em background, então delegar a entrega
    /// pro HealthKit sync deixava o app cego ao BPM com tela bloqueada.
    ///
    /// Estratégia: `updateApplicationContext` (em vez de sendMessage). Por quê?
    /// `sendMessage` exige `session.isReachable=true`, que falha em background,
    /// quando o app Watch tá em uma complication, e SEMPRE no simulador.
    /// `updateApplicationContext` entrega com dedup automático (último valor
    /// vence) — perfeito pra BPM live a 1Hz: phone só precisa do sample
    /// atual, não do histórico. Throttle 1Hz na chamada pra match.
    private var lastPushAt: TimeInterval = 0
    private static let bpmPushIntervalS: TimeInterval = 1.0
    func pushBpmToPhone(_ bpm: Int) {
        guard bpm > 0 else { return }
        let now = Date().timeIntervalSince1970
        if now - lastPushAt < Self.bpmPushIntervalS { return }
        lastPushAt = now
        let session = WCSession.default
        guard session.activationState == .activated else { return }
        let payload: [String: Any] = [
            "type": "bpm_update",
            "bpm": bpm,
            "ts": Int(now * 1000),
        ]
        do {
            try session.updateApplicationContext(payload)
        } catch {
            os_log("bpm.push.ctx_failed err=%{public}@", log: wsLog, type: .error,
                   error.localizedDescription)
            // Last-resort: enfileira como userInfo (entrega garantida mas
            // FIFO, então em rajada de N atualizações pode acumular).
            session.transferUserInfo(payload)
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
            if #available(iOS 26.0, watchOS 10.0, *) {
                WorkoutController.shared.start()
            }
        case "stopWorkout":
            if #available(iOS 26.0, watchOS 10.0, *) {
                WorkoutController.shared.stop()
            }
        default:
            break
        }
    }
}
