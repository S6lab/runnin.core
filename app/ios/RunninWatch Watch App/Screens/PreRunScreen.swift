import SwiftUI
import WatchConnectivity

/// Jornada 1 — pre-run no Watch. User pode abrir Runnin direto no Watch e
/// escolher tipo de corrida:
///   - "SESSÃO DO DIA" (se houver plano com sessão pra hoje, vinda do iPhone)
///   - "CORRIDA LIVRE" (sempre disponível)
///
/// Tap em qualquer um manda `startRun` pro iPhone via WCSession sendMessage.
/// iPhone dispara StartRun no RunBloc → status muda pra active → Watch
/// transiciona pra ActiveRunScreen automaticamente quando recebe o próximo
/// applicationContext com status:"active".
struct PreRunScreen: View {
    @EnvironmentObject var state: WatchRunState
    @State private var sending: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .center, spacing: 12) {
                RunninLogo()
                    .padding(.top, 4)

                Text("ESCOLHA")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .tracking(1.5)
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.top, 4)

                if let session = state.todaySession {
                    runButton(
                        title: "SESSÃO DO DIA",
                        subtitle: "\(session.type) · \(formattedKm(session.distanceKm))",
                        color: .cyan,
                        accent: true
                    ) {
                        sendStart(type: session.type, planSessionId: session.planSessionId)
                    }
                }

                runButton(
                    title: "CORRIDA LIVRE",
                    subtitle: "Sem plano · à vontade",
                    color: .white,
                    accent: false
                ) {
                    sendStart(type: "Free Run", planSessionId: nil)
                }

                if sending {
                    Text("INICIANDO…")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.cyan)
                        .padding(.top, 6)
                }
            }
            .padding(.horizontal, 4)
        }
    }

    @ViewBuilder
    private func runButton(
        title: String, subtitle: String, color: Color, accent: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 12, weight: .heavy, design: .monospaced))
                    .tracking(1.0)
                    .foregroundStyle(accent ? Color.black : Color.white)
                Text(subtitle)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(accent ? Color.black.opacity(0.7) : Color.white.opacity(0.5))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .background(accent ? color : Color.white.opacity(0.08))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(accent ? Color.clear : color.opacity(0.3), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .disabled(sending)
    }

    private func sendStart(type: String, planSessionId: String?) {
        guard !sending else { return }
        sending = true
        guard WCSession.isSupported() else { sending = false; return }
        let session = WCSession.default
        guard session.activationState == .activated else { sending = false; return }
        var msg: [String: Any] = [
            "action": "startRun",
            "type": type,
            "isPremium": true, // futuro: passa via context do iPhone
        ]
        if let id = planSessionId { msg["planSessionId"] = id }
        if session.isReachable {
            session.sendMessage(msg, replyHandler: { _ in
                Task { @MainActor in sending = false }
            }, errorHandler: { _ in
                Task { @MainActor in sending = false }
            })
        } else {
            session.transferUserInfo(msg)
            sending = false
        }
    }

    private func formattedKm(_ km: Double) -> String {
        if km == km.rounded() { return "\(Int(km))km" }
        return String(format: "%.1fkm", km)
    }
}
