import SwiftUI

/// Jornada 1, Passo 1/5 — TIPO de corrida. Espelha o Step 0 do prep_page do
/// iPhone (TypeStep). User pode abrir Runnin direto no Watch e escolher:
///   - "SESSÃO DO DIA" (se houver plano com sessão pra hoje, vinda do iPhone)
///   - "CORRIDA LIVRE" (sempre disponível)
///
/// Tap NÃO inicia a corrida — apenas avança pra BriefingScreen (Passo 5/5).
/// Esse desacoplamento garante que user lê o briefing antes de confirmar.
struct PreRunScreen: View {
    @EnvironmentObject var state: WatchRunState

    var body: some View {
        ScrollView {
            VStack(alignment: .center, spacing: 10) {
                HStack {
                    RunninLogo()
                    Spacer()
                    Text("1/5")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .tracking(0.8)
                        .foregroundStyle(.white.opacity(0.45))
                }
                .padding(.top, 4)

                Text("ESCOLHA O TIPO")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .tracking(1.5)
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.top, 4)

                if let session = state.todaySession {
                    runButton(
                        title: "SESSÃO DO DIA",
                        subtitle: "\(session.type) · \(formattedKm(session.distanceKm))",
                        accent: true
                    ) {
                        state.localStep = .briefing(SelectedRunType(
                            type: session.type,
                            planSessionId: session.planSessionId,
                            distanceKm: session.distanceKm
                        ))
                    }
                }

                runButton(
                    title: "CORRIDA LIVRE",
                    subtitle: "Sem plano · sem alvo",
                    accent: false
                ) {
                    state.localStep = .briefing(SelectedRunType(
                        type: "Free Run",
                        planSessionId: nil,
                        distanceKm: nil
                    ))
                }
            }
            .padding(.horizontal, 4)
        }
    }

    @ViewBuilder
    private func runButton(
        title: String, subtitle: String, accent: Bool,
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
            .background(accent ? Color.cyan : Color.white.opacity(0.08))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(accent ? Color.clear : Color.cyan.opacity(0.3), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }

    private func formattedKm(_ km: Double) -> String {
        if km == km.rounded() { return "\(Int(km))km" }
        return String(format: "%.1fkm", km)
    }
}
