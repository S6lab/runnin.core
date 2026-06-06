import SwiftUI
import WatchConnectivity

/// Jornada 2 — corrida ativa no Watch. Espelha o RunState do iPhone que vem
/// via WCSession applicationContext (1Hz).
///
/// Layout (estrutura split — ScrollView só pros stats, botões FIXOS no
/// rodapé pra não competir com pan vertical do ScrollView quando user faz
/// slide horizontal nos SlideToConfirmButton):
///   - Topo (scrollable): Header + status PAUSADO + primários + secundários
///   - Rodapé (fixo): SlideToConfirmButton PAUSAR/RETOMAR + PARAR
struct ActiveRunScreen: View {
    @EnvironmentObject var state: WatchRunState

    var body: some View {
        VStack(spacing: 6) {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        RunninLogo()
                        Spacer()
                        Text(state.runType.uppercased())
                            .font(.system(size: 8, weight: .medium, design: .monospaced))
                            .tracking(0.8)
                            .foregroundStyle(.white.opacity(0.5))
                    }

                    if state.status == .paused {
                        HStack(spacing: 4) {
                            Circle().fill(Color.yellow).frame(width: 6, height: 6)
                            Text("PAUSADO")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .tracking(1.0)
                                .foregroundStyle(.yellow)
                        }
                    }

                    statRow(label: "TEMPO", value: state.formattedElapsed, unit: nil)
                    statRow(label: "DIST", value: state.formattedDistance, unit: "km")
                    statRow(label: "PACE", value: state.formattedPace, unit: "/km")

                    HStack(spacing: 8) {
                        miniStat(label: "BPM", value: state.bpm > 0 ? "\(state.bpm)" : "—")
                        miniStat(label: "ELEV", value: "+\(Int(state.elevationM))m")
                        miniStat(label: "CAL", value: "\(Int(state.caloriesKcal))")
                    }
                    .padding(.top, 2)
                }
                .padding(.horizontal, 4)
                .padding(.bottom, 6)
            }
            // Botões FIXOS no rodapé — fora do ScrollView pra evitar conflito
            // de DragGesture (horizontal) vs pan vertical (rolagem).
            VStack(spacing: 6) {
                SlideToConfirmButton(
                    label: state.status == .paused ? "RETOMAR" : "PAUSAR",
                    color: .yellow,
                    action: {
                        sendCommand(state.status == .paused ? "resumeRun" : "pauseRun")
                    }
                )
                SlideToConfirmButton(
                    label: "PARAR",
                    color: .red,
                    action: { sendCommand("abandonRun") }
                )
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 4)
        }
    }

    @ViewBuilder
    private func statRow(label: String, value: String, unit: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .tracking(0.8)
                .foregroundStyle(.white.opacity(0.5))
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 26, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                if let unit = unit {
                    Text(unit)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
        }
    }

    @ViewBuilder
    private func miniStat(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.system(size: 7, weight: .medium, design: .monospaced))
                .tracking(0.8)
                .foregroundStyle(.white.opacity(0.5))
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sendCommand(_ action: String) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }
        let msg: [String: Any] = ["action": action]
        if session.isReachable {
            session.sendMessage(msg, replyHandler: nil, errorHandler: { _ in
                session.transferUserInfo(msg)
            })
        } else {
            session.transferUserInfo(msg)
        }
    }
}
