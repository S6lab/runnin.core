import Combine
import Foundation
import SwiftUI

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
        case idle, active, paused, completed
    }

    /// Estado de navegação LOCAL do Watch quando status==idle. Replica o
    /// fluxo do prep_page do iPhone (Passo 1/5 → 5/5). Quando status sai
    /// de idle (active/paused), localStep é irrelevante (ActiveRunScreen
    /// toma conta) — reset pra .selectingType quando volta pra idle.
    enum LocalStep: Equatable {
        case selectingType
        case briefing(SelectedRunType)
    }

    @Published var status: Status = .idle
    @Published var localStep: LocalStep = .selectingType
    /// True enquanto a sendMessage("startRun") está em vôo — UI mostra
    /// "INICIANDO…" no BriefingScreen.
    @Published var starting: Bool = false
    @Published var elapsedS: Int = 0
    @Published var distanceM: Double = 0
    @Published var paceMinKm: Double = 0
    @Published var bpm: Int = 0
    @Published var caloriesKcal: Double = 0
    @Published var elevationM: Double = 0
    @Published var runType: String = ""
    /// Cor de acento da skin selecionada no iPhone (themeController.palette.
    /// primary). Default cyan = skin "Artico". Atualizada via update(from:)
    /// quando applicationContext carrega `accentColor` hex. Usado em PACE,
    /// header logo, buttons, links.
    @Published var accentColor: Color = Color(red: 0/255, green: 212/255, blue: 255/255)
    /// Cor secundária da skin (themeController.palette.secondary). Usado em
    /// DIST e BPM pra criar contraste — mesmo padrão do iPhone (PACE=primary,
    /// DIST=secondary).
    @Published var secondaryColor: Color = Color(red: 255/255, green: 107/255, blue: 53/255)
    /// Splits por km vindos do iPhone via applicationContext. Cada item é
    /// um KM completado (ou parcial no fim). Vazia até o primeiro km.
    @Published var splits: [WatchSplit] = []
    /// Fator multiplicador de fonte (vem do themeController.textScaleFactor
    /// do iPhone: 1.0=A, 1.12=A+, 1.28=A++). Default 1.0. UI do Watch
    /// multiplica todas as font sizes por esse fator via `scaledFont`.
    /// Clamped 0.8-1.5 pra não quebrar layout no viewport 46mm.
    @Published var textScale: Double = 1.0

    /// Sessão planejada do dia (vinda do iPhone quando idle). null = só
    /// "Corrida Livre" disponível no PreRunScreen.
    @Published var todaySession: TodaySession? = nil

    private init() {}

    func update(from context: [String: Any]) {
        guard let type = context["type"] as? String else { return }
        // applicationContext do iPhone é single-value dedup — quando ele
        // empurra `run_state` após `today_session`, o cache fica só com
        // run_state e a sessão do dia some no próximo activation do Watch.
        // iPhone re-injeta `_attachedTodaySession` em TODOS os pushes
        // não-today_session pra evitar essa perda. Aplicamos aqui ANTES
        // do switch, em qualquer tipo de payload.
        if let attached = context["_attachedTodaySession"] as? [String: Any] {
            todaySession = TodaySession(
                type: attached["type"] as? String ?? "",
                distanceKm: attached["distanceKm"] as? Double ?? 0,
                planSessionId: attached["planSessionId"] as? String
            )
        } else if context["_attachedTodaySession"] is NSNull {
            todaySession = nil
        }
        switch type {
        case "run_state":
            if let s = context["status"] as? String, let st = Status(rawValue: s) {
                // Quando entra em active, derruba flag de "starting" e
                // reseta o roteamento local pra próxima idle voltar pro
                // TypeSelector limpo.
                if st == .active && status != .active {
                    starting = false
                }
                if st == .idle && status != .idle {
                    localStep = .selectingType
                }
                status = st
            }
            if let v = context["elapsedS"] as? Int { elapsedS = v }
            if let v = context["distanceM"] as? Double { distanceM = v }
            if let v = context["paceMinKm"] as? Double { paceMinKm = v }
            if let v = context["bpm"] as? Int { bpm = v }
            if let v = context["caloriesKcal"] as? Double { caloriesKcal = v }
            if let v = context["elevationM"] as? Double { elevationM = v }
            if let v = context["runType"] as? String { runType = v }
            // Accent color da skin do iPhone — opcional; ignora se ausente
            // ou mal formatado. Mantém a última cor válida.
            if let hex = context["accentColor"] as? String,
               let c = Self.colorFromHex(hex) {
                accentColor = c
            }
            if let hex = context["secondaryColor"] as? String,
               let c = Self.colorFromHex(hex) {
                secondaryColor = c
            }
            if let s = context["textScale"] as? Double {
                textScale = max(0.8, min(1.5, s))
            } else if let s = context["textScale"] as? NSNumber {
                textScale = max(0.8, min(1.5, s.doubleValue))
            }
            if let raw = context["splits"] as? [[String: Any]] {
                splits = raw.map { dict in
                    WatchSplit(
                        km: dict["km"] as? Int ?? 0,
                        durationS: dict["durationS"] as? Int ?? 0,
                        pace: dict["pace"] as? String ?? "—:—",
                        bpm: dict["bpm"] as? Int ?? 0,
                        elev: (dict["elev"] as? Double)
                            ?? (dict["elev"] as? NSNumber).map { $0.doubleValue }
                            ?? 0
                    )
                }
            }
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

    /// Helper que devolve uma Font monospace escalada por `textScale`.
    /// Usado em todas as telas do Watch em vez de `.font(.system(size: N, ...))`
    /// hardcoded — assim mudar o text scale do iPhone reflete em tudo.
    func scaledFont(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        return .system(size: size * CGFloat(textScale), weight: weight, design: .monospaced)
    }

    /// Converte "#RRGGBB" (ou "RRGGBB") em SwiftUI.Color. Retorna nil pra
    /// strings inválidas. Apenas 6 dígitos hex (sem alpha) — iPhone envia
    /// somente RGB pra simplificar payload.
    static func colorFromHex(_ hex: String) -> Color? {
        var s = hex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return nil }
        let r = Double((v >> 16) & 0xFF) / 255.0
        let g = Double((v >> 8) & 0xFF) / 255.0
        let b = Double(v & 0xFF) / 255.0
        return Color(red: r, green: g, blue: b)
    }
}

/// Split de 1 km (ou parcial no fim da corrida) — vem do iPhone no payload
/// de `run_state` (campo `splits` array). UI exibe na SplitsPage (pág 3).
struct WatchSplit: Equatable, Identifiable {
    let km: Int           // 1-based (KM1, KM2, ...)
    let durationS: Int    // segundos do km
    let pace: String      // "5:42/km" formatado pelo iPhone
    let bpm: Int          // média de BPM do km (0 = sem dado)
    let elev: Double      // ganho de elevação do km em metros

    var id: Int { km }

    var formattedDuration: String {
        let m = durationS / 60
        let s = durationS % 60
        return String(format: "%d:%02d", m, s)
    }
}

struct TodaySession: Equatable {
    let type: String
    let distanceKm: Double
    let planSessionId: String?
}

/// Tipo selecionado no Passo 1/5 (TypeSelectorScreen) que segue pra
/// BriefingScreen (Passo 5/5). Distância só preenchida quando vem de
/// Sessão do Dia; null pra Free Run.
struct SelectedRunType: Equatable {
    let type: String
    let planSessionId: String?
    let distanceKm: Double?

    var isFree: Bool { planSessionId == nil }
}
