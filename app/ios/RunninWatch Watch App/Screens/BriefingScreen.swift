import SwiftUI
import WatchConnectivity

/// Jornada 1, Passo 5/5 — BRIEFING + INICIAR. Espelha o Step 4 (BRIEFING) do
/// prep_page do iPhone. User vê o resumo do que vai fazer e confirma com
/// botão grande INICIAR. "VOLTAR" retorna pro TypeSelectorScreen.
///
/// O sendMessage("startRun") só dispara AQUI — antes (no tap dos cards do
/// TypeSelector) era prematuro. Watch fica em "INICIANDO…" entre o tap
/// INICIAR e o iPhone empurrar `run_state.status: "active"` no próximo
/// applicationContext (1-2s típico).
struct BriefingScreen: View {
    @EnvironmentObject var state: WatchRunState
    let selected: SelectedRunType

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    RunninLogo()
                    Spacer()
                    Text("5/5")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .tracking(0.8)
                        .foregroundStyle(.white.opacity(0.45))
                }
                .padding(.top, 4)

                Text(selected.type.uppercased())
                    .font(.system(size: 14, weight: .heavy, design: .monospaced))
                    .tracking(1.0)
                    .foregroundStyle(.white)

                if let km = selected.distanceKm {
                    Text("ALVO · \(formattedKm(km))")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(Color.cyan)
                } else {
                    Text("SEM ALVO DE DISTÂNCIA")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(.white.opacity(0.5))
                }

                Text(briefingText)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.75))
                    .padding(.top, 4)

                Spacer(minLength: 6)

                Button(action: handleStart) {
                    HStack(spacing: 6) {
                        if state.starting {
                            ProgressView()
                                .controlSize(.mini)
                                .tint(.black)
                        }
                        Text(state.starting ? "INICIANDO…" : "INICIAR")
                            .font(.system(size: 13, weight: .heavy, design: .monospaced))
                            .tracking(1.2)
                            .foregroundStyle(.black)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.cyan)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .disabled(state.starting)

                Button(action: { state.localStep = .selectingType }) {
                    Text("VOLTAR")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .tracking(1.0)
                        .foregroundStyle(.white.opacity(0.55))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
                .disabled(state.starting)
            }
            .padding(.horizontal, 4)
        }
    }

    private var briefingText: String {
        if selected.isFree {
            return "Corrida livre. Sem alarmes de pace — só telemetria de km e tempo."
        }
        return "Bloco de \(selected.type). Foco no pace alvo. Coach vai te acompanhar."
    }

    private func handleStart() {
        guard !state.starting else { return }
        state.starting = true
        guard WCSession.isSupported() else { state.starting = false; return }
        let session = WCSession.default
        guard session.activationState == .activated else { state.starting = false; return }
        var msg: [String: Any] = [
            "action": "startRun",
            "type": selected.type,
            "isPremium": true,
        ]
        if let id = selected.planSessionId { msg["planSessionId"] = id }
        if session.isReachable {
            session.sendMessage(msg, replyHandler: { _ in
                // iPhone vai mandar applicationContext com status=active
                // logo em seguida; deixamos `starting` como true até o
                // contexto chegar (WatchRunState reseta no update).
            }, errorHandler: { _ in
                session.transferUserInfo(msg)
                Task { @MainActor in state.starting = false }
            })
        } else {
            session.transferUserInfo(msg)
            Task { @MainActor in state.starting = false }
        }
    }

    private func formattedKm(_ km: Double) -> String {
        if km == km.rounded() { return "\(Int(km))km" }
        return String(format: "%.1fkm", km)
    }
}
