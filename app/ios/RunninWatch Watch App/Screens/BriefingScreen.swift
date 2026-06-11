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
    /// Timeout fallback: se status=active não chegar do iPhone em 10s,
    /// libera o botão pra tentar de novo. Cobre cenários raros onde
    /// applicationContext não entrega (Watch sleeping mid-transition,
    /// iPhone background com WC restrito, etc.). No happy path leva 1-2s.
    @State private var timeoutWorkItem: DispatchWorkItem?
    @State private var startFailed: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    RunninLogo()
                    Spacer()
                }
                .padding(.top, 4)

                Text(selected.type.uppercased())
                    .font(state.scaledFont(size: 14, weight: .heavy))
                    .tracking(1.0)
                    .foregroundStyle(.white)

                if let km = selected.distanceKm {
                    Text("ALVO · \(formattedKm(km))")
                        .font(state.scaledFont(size: 9, weight: .medium))
                        .tracking(1.2)
                        .foregroundStyle(state.accentColor)
                } else {
                    Text("SEM ALVO DE DISTÂNCIA")
                        .font(state.scaledFont(size: 9, weight: .medium))
                        .tracking(1.2)
                        .foregroundStyle(.white.opacity(0.5))
                }

                Text(briefingText)
                    .font(state.scaledFont(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.75))
                    .padding(.top, 4)

                if startFailed {
                    // O comando ficou salvo no iPhone (pending start nativo):
                    // abrir o app já dispara a corrida — não precisa re-enviar.
                    Text("iPhone sem resposta. Seu pedido ficou salvo: abra o Runnin no iPhone que a corrida inicia sozinha.")
                        .font(state.scaledFont(size: 9, weight: .medium))
                        .foregroundStyle(.yellow)
                        .padding(.top, 2)
                }

                Spacer(minLength: 6)

                Button(action: handleStart) {
                    HStack(spacing: 6) {
                        if state.starting {
                            ProgressView()
                                .controlSize(.mini)
                                .tint(.black)
                        }
                        Text(buttonLabel)
                            .font(state.scaledFont(size: 13, weight: .heavy))
                            .tracking(1.2)
                            .foregroundStyle(.black)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(state.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .disabled(state.starting)

                Button(action: { state.localStep = .selectingType }) {
                    Text("VOLTAR")
                        .font(state.scaledFont(size: 10, weight: .medium))
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
        // Quando status sai de idle (active/paused chegaram), cancela timeout
        // — o caminho feliz disparou. Quando volta pra idle por outro motivo,
        // reseta `startFailed` pro user poder tentar de novo limpo.
        .onChange(of: state.status) { _, new in
            if new != .idle {
                timeoutWorkItem?.cancel()
                timeoutWorkItem = nil
                startFailed = false
            }
        }
    }

    private var buttonLabel: String {
        if state.starting { return "INICIANDO…" }
        if startFailed { return "TENTAR NOVAMENTE" }
        return "INICIAR"
    }

    private var briefingText: String {
        if selected.isFree {
            return "Corrida livre. Sem alarmes de pace — só telemetria de km e tempo."
        }
        return "Bloco de \(selected.type). Foco no pace alvo. Coach vai te acompanhar."
    }

    private func handleStart() {
        guard !state.starting else { return }
        startFailed = false
        state.starting = true
        // Arma timeout: se status=active não chegar do iPhone em 10s, libera
        // o botão e mostra hint. Cancelado em onChange(of: state.status).
        timeoutWorkItem?.cancel()
        let work = DispatchWorkItem {
            Task { @MainActor in
                if state.status == .idle && state.starting {
                    state.starting = false
                    startFailed = true
                }
            }
        }
        timeoutWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 10, execute: work)

        guard WCSession.isSupported() else {
            state.starting = false; startFailed = true; return
        }
        let session = WCSession.default
        guard session.activationState == .activated else {
            state.starting = false; startFailed = true; return
        }
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
                // contexto chegar (WatchRunState reseta no update) — ou
                // até o timeout disparar.
            }, errorHandler: { _ in
                session.transferUserInfo(msg)
                // sendMessage falhou — userInfo é fire-and-forget e demora;
                // mantemos starting=true até timeout ou status active.
            })
        } else {
            session.transferUserInfo(msg)
        }
    }

    private func formattedKm(_ km: Double) -> String {
        if km == km.rounded() { return "\(Int(km))km" }
        return String(format: "%.1fkm", km)
    }
}
