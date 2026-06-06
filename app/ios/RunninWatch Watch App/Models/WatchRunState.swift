import Combine
import Foundation

/// Mirror local do `RunState` do iPhone — atualizado via WCSession
/// `didReceiveApplicationContext`. UI do Watch (PreRunScreen, ActiveRunScreen)
/// observa via @EnvironmentObject e re-renderiza conforme campos mudam.
///
/// Singleton porque o WCSession delegate é único e a UI inteira do Watch
/// vive em volta dela. `update(from:)` é chamado em thread main (delegate
/// dispatcha pra MainQueue antes).
@MainActor
class WatchRunState: ObservableObject {
    static let shared = WatchRunState()

    enum Status: String {
        case idle, active, paused
    }

    @Published var status: Status = .idle
    @Published var elapsedS: Int = 0
    @Published var distanceM: Double = 0
    @Published var paceMinKm: Double = 0
    @Published var bpm: Int = 0
    @Published var caloriesKcal: Double = 0
    @Published var elevationM: Double = 0
    @Published var runType: String = ""

    /// Sessão planejada do dia (vinda do iPhone quando idle). null = só
    /// "Corrida Livre" disponível no PreRunScreen.
    @Published var todaySession: TodaySession? = nil

    private init() {}

    func update(from context: [String: Any]) {
        guard let type = context["type"] as? String else { return }
        switch type {
        case "run_state":
            if let s = context["status"] as? String, let st = Status(rawValue: s) {
                status = st
            }
            if let v = context["elapsedS"] as? Int { elapsedS = v }
            if let v = context["distanceM"] as? Double { distanceM = v }
            if let v = context["paceMinKm"] as? Double { paceMinKm = v }
            if let v = context["bpm"] as? Int { bpm = v }
            if let v = context["caloriesKcal"] as? Double { caloriesKcal = v }
            if let v = context["elevationM"] as? Double { elevationM = v }
            if let v = context["runType"] as? String { runType = v }
        case "today_session":
            if let dict = context["session"] as? [String: Any] {
                todaySession = TodaySession(
                    type: dict["type"] as? String ?? "",
                    distanceKm: dict["distanceKm"] as? Double ?? 0,
                    planSessionId: dict["planSessionId"] as? String
                )
            } else {
                todaySession = nil
            }
        default:
            break
        }
    }

    // MARK: Formatters

    var formattedElapsed: String {
        let s = max(0, elapsedS)
        let h = s / 3600
        let m = (s % 3600) / 60
        let sec = s % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, sec)
            : String(format: "%02d:%02d", m, sec)
    }

    var formattedDistance: String {
        String(format: "%.2f", distanceM / 1000)
    }

    var formattedPace: String {
        guard paceMinKm > 0, paceMinKm.isFinite, paceMinKm < 30 else { return "—:—" }
        let totalSec = Int((paceMinKm * 60).rounded())
        let m = totalSec / 60
        let s = totalSec % 60
        return String(format: "%d:%02d", m, s)
    }
}

struct TodaySession: Equatable {
    let type: String
    let distanceKm: Double
    let planSessionId: String?
}
