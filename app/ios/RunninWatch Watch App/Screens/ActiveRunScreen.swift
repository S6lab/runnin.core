import SwiftUI
import WatchConnectivity
import OSLog

private let arsLog = OSLog(subsystem: "ai.runnin.workout", category: "active-screen")

/// Jornada 2 — corrida ativa no Watch. Espelha o RunState do iPhone que vem
/// via WCSession applicationContext (1Hz).
///
/// Layout TabView paginado (swipe horizontal entre páginas, SEM indicador):
///   - Pág 1: TODOS os stats (TEMPO, DIST, PACE, BPM, ELEV, CAL) — CABE
///     INTEIRA sem scroll. Compacto pra viewport 46mm.
///   - Pág 2: SOMENTE os 2 slide-buttons (PAUSAR + PARAR) — grandes
struct ActiveRunScreen: View {
    @EnvironmentObject var state: WatchRunState
    /// BPM local da HKWorkoutSession do Watch — fallback quando o push do
    /// iPhone (state.bpm) está zerado ou stale. Em device real travou em
    /// 94 porque `state.bpm` ficou no primeiro valor empurrado e o delegate
    /// `didCollectDataOf` não disparou novos updates pro phone. Aqui a UI
    /// passa a usar o valor local do builder, que o polling 3s atualiza.
    @ObservedObject var workout: WorkoutController = WorkoutController.shared
    @State private var selectedPage = 0

    var body: some View {
        ZStack {
            TabView(selection: $selectedPage) {
                statsPage.tag(0)
                controlsPage.tag(1)
                splitsPage.tag(2)
            }
            // `.always` mantém as bolinhas (page indicator) sempre visíveis no
            // rodapé. User pediu pra ser óbvio que há mais páginas além da que
            // está na frente. `.automatic` fade depois de um tempo — preferi
            // `.always` por ser mais didático no Watch.
            .tabViewStyle(.page(indexDisplayMode: .always))

            // Overlay de orfão: tela trava na corrida quando iPhone morre.
            // Watchdog em WatchRunState marca isOrphaned=true após 25s
            // sem applicationContext. Botão volta pro TypeSelector e para
            // o WorkoutController local (libera Activity Ring).
            if state.isOrphaned {
                orphanOverlay
            }
        }
    }

    /// Resolve o BPM mostrado preferindo o local (WorkoutController) quando
    /// disponível e maior — evita "—" quando o phone trava sem empurrar.
    private var displayedBpm: Int {
        if workout.lastHeartRate > 0 { return workout.lastHeartRate }
        return state.bpm
    }

    private var orphanOverlay: some View {
        ZStack {
            Color.black.opacity(0.85).ignoresSafeArea()
            VStack(spacing: 10) {
                Text("APP DO IPHONE OFFLINE")
                    .font(state.scaledFont(size: 11, weight: .heavy))
                    .tracking(1.2)
                    .foregroundStyle(Color.orange)
                Text("Sem dados há 25s. Encerrar e voltar?")
                    .font(state.scaledFont(size: 10, weight: .medium))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.7))
                Button(action: { state.resetToIdle() }) {
                    Text("ENCERRAR")
                        .font(state.scaledFont(size: 12, weight: .heavy))
                        .tracking(1.0)
                        .foregroundStyle(Color.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.orange)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
        }
    }

    // MARK: - Pages

    private var statsPage: some View {
        // VStack normal SEM ScrollView — força tudo a caber em uma tela.
        // Spacings curtos + fonts comprimidas pro viewport 46mm (~186pt útil).
        let isPaused = state.status == .paused
        return VStack(alignment: .leading, spacing: 4) {
            header
            if isPaused {
                pausedBanner
            }
            // Stats ficam dimmed quando pausado pra reforçar "tudo congelado".
            VStack(alignment: .leading, spacing: 4) {
                bigStat(label: "TEMPO", value: state.formattedElapsed, size: 30,
                        valueColor: isPaused ? .yellow : .white)
                HStack(spacing: 8) {
                    // DIST=secondary, PACE=primary — mesma hierarquia
                    // cromática do iPhone (active_run_page).
                    mediumStat(label: "DIST", value: state.formattedDistance,
                               unit: "km", valueColor: state.secondaryColor)
                    mediumStat(label: "PACE", value: state.formattedPace,
                               unit: "/km", valueColor: state.accentColor)
                }
                HStack(spacing: 8) {
                    mediumStat(label: "BPM",
                               value: displayedBpm > 0 ? "\(displayedBpm)" : "—",
                               unit: nil, valueColor: state.secondaryColor)
                    mediumStat(label: "CAL",
                               value: "\(Int(state.caloriesKcal))",
                               unit: nil, valueColor: .white)
                }
                smallStat(label: "ELEV", value: "+\(Int(state.elevationM))m")
            }
            .opacity(isPaused ? 0.55 : 1.0)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 6)
        .padding(.top, 2)
        .padding(.bottom, 4)
    }

    /// Pág 3 — lista de splits por km. Aparece ao swipe-LEFT na pág 2.
    /// Scroll vertical se passar do viewport. Cada row mostra: KM | pace |
    /// tempo | BPM | elev. Cores DIST/PACE/BPM seguindo o mesmo padrão da
    /// statsPage (secondary, primary, secondary).
    private var splitsPage: some View {
        VStack(alignment: .leading, spacing: 4) {
            header
            Text("SPLITS")
                .font(state.scaledFont(size: 8, weight: .medium))
                .tracking(1.5)
                .foregroundStyle(.white.opacity(0.5))
            if state.splits.isEmpty {
                Spacer(minLength: 0)
                VStack(spacing: 4) {
                    Text("—")
                        .font(state.scaledFont(size: 22, weight: .bold))
                        .foregroundStyle(.white.opacity(0.3))
                    Text("Termine o 1º km")
                        .font(state.scaledFont(size: 9, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .frame(maxWidth: .infinity)
                Spacer(minLength: 0)
            } else {
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(state.splits) { split in
                            splitRow(split)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func splitRow(_ split: WatchSplit) -> some View {
        HStack(spacing: 6) {
            // Coluna 1: KM número
            Text("KM\(split.km)")
                .font(state.scaledFont(size: 11, weight: .heavy))
                .foregroundStyle(state.accentColor)
                .frame(width: 32, alignment: .leading)
            // Coluna 2: pace + tempo
            VStack(alignment: .leading, spacing: 0) {
                Text(split.pace)
                    .font(state.scaledFont(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                Text(split.formattedDuration)
                    .font(state.scaledFont(size: 8, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
            }
            Spacer(minLength: 0)
            // Coluna 3: BPM
            if split.bpm > 0 {
                VStack(alignment: .trailing, spacing: 0) {
                    Text("\(split.bpm)")
                        .font(state.scaledFont(size: 11, weight: .bold))
                        .foregroundStyle(state.secondaryColor)
                    Text("BPM")
                        .font(state.scaledFont(size: 7, weight: .medium))
                        .foregroundStyle(.white.opacity(0.45))
                }
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private var controlsPage: some View {
        VStack(spacing: 8) {
            header
            if state.status == .paused {
                pausedBanner
            }
            Spacer(minLength: 0)
            Text("CONTROLES")
                .font(state.scaledFont(size: 8, weight: .medium))
                .tracking(1.5)
                .foregroundStyle(.white.opacity(0.5))
            SlideToConfirmButton(
                label: state.status == .paused ? "RETOMAR" : "PAUSAR",
                color: .yellow,
                action: {
                    os_log("slide.fire action=%{public}@", log: arsLog, type: .info,
                           state.status == .paused ? "resumeRun" : "pauseRun")
                    sendCommand(state.status == .paused ? "resumeRun" : "pauseRun")
                }
            )
            SlideToConfirmButton(
                label: "PARAR",
                color: .red,
                action: {
                    // PARAR no Watch = COMPLETE (salva + relatório), não
                    // ABANDON (cancela sem salvar). User espera ver
                    // RunCompletedScreen no Watch e /report no iPhone —
                    // mesmo padrão do Apple Workout (botão End).
                    os_log("slide.fire action=completeRun", log: arsLog, type: .info)
                    sendCommand("completeRun")
                }
            )
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
    }

    // MARK: - Reusable bits

    private var header: some View {
        HStack {
            RunninLogo()
            Spacer()
            Text(state.runType.uppercased())
                .font(state.scaledFont(size: 8, weight: .medium))
                .tracking(0.8)
                .foregroundStyle(.white.opacity(0.5))
                .lineLimit(1)
        }
    }

    /// Banner full-width amarelo, alto contraste — pra ser óbvio que a
    /// corrida está pausada. Substituiu a antiga pill discreta (5px círculo
    /// + texto 8pt amarelo) que user reportou imperceptível.
    private var pausedBanner: some View {
        HStack(spacing: 5) {
            Image(systemName: "pause.fill")
                .font(.system(size: 10, weight: .heavy))
            Text("PAUSADO")
                .font(state.scaledFont(size: 10, weight: .heavy))
                .tracking(1.5)
            Spacer(minLength: 0)
        }
        .foregroundStyle(.black)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity)
        .background(Color.yellow)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    @ViewBuilder
    private func bigStat(label: String, value: String, size: CGFloat,
                         valueColor: Color = .white) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label)
                .font(state.scaledFont(size: 8, weight: .medium))
                .tracking(0.8)
                .foregroundStyle(.white.opacity(0.5))
            Text(value)
                .font(state.scaledFont(size: size, weight: .bold))
                .foregroundStyle(valueColor)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private func mediumStat(label: String, value: String, unit: String?,
                            valueColor: Color = .white) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label)
                .font(state.scaledFont(size: 7, weight: .medium))
                .tracking(0.8)
                .foregroundStyle(.white.opacity(0.5))
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(state.scaledFont(size: 18, weight: .bold))
                    .foregroundStyle(valueColor)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                if let unit = unit {
                    Text(unit)
                        .font(state.scaledFont(size: 8, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func smallStat(label: String, value: String) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(state.scaledFont(size: 7, weight: .medium))
                .tracking(0.8)
                .foregroundStyle(.white.opacity(0.45))
            Text(value)
                .font(state.scaledFont(size: 11, weight: .bold))
                .foregroundStyle(.white.opacity(0.85))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
    }

    private func sendCommand(_ action: String) {
        os_log("slide.sendCommand action=%{public}@", log: arsLog, type: .info, action)
        guard WCSession.isSupported() else {
            os_log("slide.sendCommand.skip not_supported", log: arsLog, type: .error)
            return
        }
        let session = WCSession.default
        guard session.activationState == .activated else {
            os_log("slide.sendCommand.skip not_activated state=%d", log: arsLog, type: .error,
                   session.activationState.rawValue)
            return
        }
        // Fix TF 59: anexa `request_id` único pra dedup do iPhone-side.
        // Antes, transferUserInfo enfileirado offline podia entregar 2x
        // (durante o fallback após sendMessage falhar) → iPhone processava
        // dois pause/resume seguidos.
        let requestId = UUID().uuidString
        let msg: [String: Any] = ["action": action, "request_id": requestId]
        if session.isReachable {
            session.sendMessage(msg, replyHandler: { reply in
                os_log("slide.sendMessage.reply ok=%{public}@", log: arsLog, type: .info,
                       String(describing: reply["ok"] ?? "nil"))
            }, errorHandler: { err in
                os_log("slide.sendMessage.fail err=%{public}@ falling_back_to_userInfo",
                       log: arsLog, type: .error, err.localizedDescription)
                session.transferUserInfo(msg)
            })
        } else {
            os_log("slide.sendCommand.userInfo reachable=0", log: arsLog, type: .info)
            session.transferUserInfo(msg)
        }
    }
}
