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
    /// Fix TF 59: persistida em UserDefaults com TTL 24h. Antes era só
    /// @Published in-memory — fechar+abrir Watch app perdia a sessão
    /// (didReceiveApplicationContext não re-disparava). Agora restaura
    /// instantaneamente no boot e sobrevive a app restart.
    @Published var todaySession: TodaySession? = nil {
        didSet {
            Self.persistTodaySession(todaySession)
        }
    }

    private static let _todaySessionDefaultsKey = "today_session_v1"
    private static let _todaySessionTimestampKey = "today_session_v1_at"
    private static let _todaySessionTtlSeconds: TimeInterval = 24 * 60 * 60

    static func persistTodaySession(_ s: TodaySession?) {
        let d = UserDefaults.standard
        if let s = s {
            if let data = try? JSONEncoder().encode(s) {
                d.set(data, forKey: _todaySessionDefaultsKey)
                d.set(Date().timeIntervalSince1970, forKey: _todaySessionTimestampKey)
            }
        } else {
            d.removeObject(forKey: _todaySessionDefaultsKey)
            d.removeObject(forKey: _todaySessionTimestampKey)
        }
    }

    static func loadPersistedTodaySession() -> TodaySession? {
        let d = UserDefaults.standard
        let ts = d.double(forKey: _todaySessionTimestampKey)
        if ts > 0, Date().timeIntervalSince1970 - ts > _todaySessionTtlSeconds {
            // TTL 24h estouro: cache de ontem não vale.
            d.removeObject(forKey: _todaySessionDefaultsKey)
            d.removeObject(forKey: _todaySessionTimestampKey)
            return nil
        }
        guard let data = d.data(forKey: _todaySessionDefaultsKey) else { return nil }
        return try? JSONDecoder().decode(TodaySession.self, from: data)
    }

    /// True quando passou >`orphanThresholdS` segundos sem applicationContext
    /// do iPhone DURANTE uma run ativa/pausada. Indica que o app do iPhone
    /// foi morto (swipe-up, crash, sleep agressivo) e o Watch ficou sozinho
    /// com a última leitura cacheada. ActiveRunScreen mostra overlay com
    /// botão "Encerrar e voltar" pra destravar.
    @Published var isOrphaned: Bool = false
    /// Timestamp (Date) do último applicationContext processado. Usado pelo
    /// orphan checker (Timer 5s) pra detectar perda de conexão prolongada
    /// mesmo quando o iOS não dispara `sessionReachabilityDidChange`.
    private var lastContextAt: Date?
    /// Janela de tolerância. iPhone empurra ~1Hz; 25s cobre múltiplos
    /// ciclos perdidos sem assustar em soluços de 2-3s normais.
    private let orphanThresholdS: TimeInterval = 25
    private var orphanCheckTimer: Timer?

    private init() {
        // Fix TF 59: restaura a última sessão do dia do UserDefaults antes
        // do iPhone re-empurrar via WCSession. Garante que abrir o Watch
        // app já mostra a sessão certa sem esperar push.
        if let restored = Self.loadPersistedTodaySession() {
            self.todaySession = restored
        }
    }

    /// Inicia o monitor de orfão. Idempotente — chama uma vez no boot do
    /// app Watch e o timer roda pela vida do processo. Quando status volta
    /// pra idle, reseta isOrphaned silenciosamente (UI re-renderiza).
    func startOrphanMonitor() {
        orphanCheckTimer?.invalidate()
        orphanCheckTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                // Só sinaliza orfão durante run ativa/pausada.
                guard self.status == .active || self.status == .paused else {
                    if self.isOrphaned { self.isOrphaned = false }
                    return
                }
                let last = self.lastContextAt ?? Date.distantPast
                let gap = Date().timeIntervalSince(last)
                let nowOrphaned = gap > self.orphanThresholdS
                if nowOrphaned != self.isOrphaned {
                    self.isOrphaned = nowOrphaned
                }
            }
        }
    }

    /// Limpa o estado da corrida e volta pro TypeSelector. Chamado pelo
    /// botão "Encerrar e voltar" do overlay de orfão e pelo botão FINALIZAR
    /// normal. Para a HKWorkoutSession local pra não vazar bateria/Activity
    /// Ring fragmentado.
    func resetToIdle() {
        if #available(iOS 26.0, watchOS 10.0, *) {
            WorkoutController.shared.stop()
        }
        status = .idle
        starting = false
        elapsedS = 0
        distanceM = 0
        paceMinKm = 0
        bpm = 0
        caloriesKcal = 0
        elevationM = 0
        splits = []
        isOrphaned = false
        localStep = .selectingType
    }

    func update(from context: [String: Any]) {
        // Qualquer payload do iPhone re-arma o orphan watchdog. Mesmo
        // mensagens não-state (skin update, today_session) provam que o
        // canal tá vivo.
        lastContextAt = Date()
        if isOrphaned { isOrphaned = false }
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
                planSessionId: attached["planSessionId"] as? String,
                isExecuted: attached["isExecuted"] as? Bool ?? false
            )
        } else if context["_attachedTodaySession"] is NSNull,
                  context["rest_day"] as? Bool == true {
            // Fix TF 61: igual ao case "today_session" — só limpa em
            // rest_day confirmado, nunca em transient.
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
                    // Auto-start HKWorkoutSession quando o iPhone reporta
                    // status=active. Evita depender de `sendMessage` (que no
                    // simulador / Watch sem complication ativa falha por
                    // `isReachable=false`), garantindo que o BPM live (mock
                    // no sim, sensor real no device) começa a fluir.
                    if #available(iOS 26.0, watchOS 10.0, *) {
                        WorkoutController.shared.start()
                    }
                }
                if st == .idle && status != .idle {
                    localStep = .selectingType
                    if #available(iOS 26.0, watchOS 10.0, *) {
                        WorkoutController.shared.stop()
                    }
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
                    planSessionId: dict["planSessionId"] as? String,
                    isExecuted: dict["isExecuted"] as? Bool ?? false
                )
            } else if context["rest_day"] as? Bool == true {
                // Fix TF 61: SÓ limpa quando iPhone confirma rest day
                // (plano carregado + semana sem session pro dayOfWeek).
                // Antes, qualquer transient (rede, exception, plano em
                // load) empurrava session: null e nuked UserDefaults →
                // Watch perdia sessão no próximo boot.
                todaySession = nil
            }
            // Se vier session: null SEM rest_day flag → IGNORA. Mantém
            // o que tinha no cache local (UserDefaults).
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

struct TodaySession: Equatable, Codable {
    let type: String
    let distanceKm: Double
    let planSessionId: String?
    /// Sessão do plano já executada hoje. Watch usa pra mostrar badge
    /// "CONCLUÍDA" no TypeSelector em vez do botão de iniciar, e default
    /// pra Free Run (igual o iPhone).
    let isExecuted: Bool
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
