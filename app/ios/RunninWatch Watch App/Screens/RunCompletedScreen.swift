import SwiftUI
import WatchConnectivity

/// Mostrada após corrida concluída (status: .completed).
/// Espelha a ReportPage do iPhone — totais + splits — adaptado pro Watch.
///
/// Layout:
///   - Header "CORRIDA CONCLUÍDA" em accentColor
///   - Stats principais: DIST (secondary, big), TEMPO (white, big), PACE MED
///     (primary, big)
///   - Secondary: BPM médio, calorias, elevação
///   - Lista de splits (scrollable)
///   - Botão "OK" no rodapé — manda `acknowledgeComplete` pro iPhone que
///     transiciona pra idle (TypeSelectorScreen)
struct RunCompletedScreen: View {
    @EnvironmentObject var state: WatchRunState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    RunninLogo()
                    Spacer()
                }
                .padding(.top, 2)

                Text("CORRIDA CONCLUÍDA")
                    .font(state.scaledFont(size: 9, weight: .heavy))
                    .tracking(1.5)
                    .foregroundStyle(state.accentColor)
                    .padding(.top, 2)

                // Stats principais — mesma hierarquia cromática da ActiveRunScreen
                statBlock(label: "DIST", value: state.formattedDistance,
                          unit: "km", size: 26, color: state.secondaryColor)
                statBlock(label: "TEMPO", value: state.formattedElapsed,
                          unit: nil, size: 22, color: .white)
                statBlock(label: "PACE MED", value: state.formattedPace,
                          unit: "/km", size: 22, color: state.accentColor)

                // Stats secundários compactos numa row 3-col
                HStack(spacing: 6) {
                    miniStat(label: "BPM",
                             value: state.bpm > 0 ? "\(state.bpm)" : "—",
                             color: state.secondaryColor)
                    miniStat(label: "CAL",
                             value: "\(Int(state.caloriesKcal))",
                             color: .white)
                    miniStat(label: "ELEV",
                             value: "+\(Int(state.elevationM))m",
                             color: .white.opacity(0.8))
                }

                // Splits (se houver)
                if !state.splits.isEmpty {
                    Text("SPLITS")
                        .font(state.scaledFont(size: 8, weight: .medium))
                        .tracking(1.5)
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(.top, 4)
                    ForEach(state.splits) { split in
                        splitRow(split)
                    }
                }

                // Botão OK
                Button(action: acknowledge) {
                    Text("OK")
                        .font(state.scaledFont(size: 13, weight: .heavy))
                        .tracking(1.2)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(state.accentColor)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
            }
            .padding(.horizontal, 6)
            .padding(.bottom, 6)
        }
    }

    @ViewBuilder
    private func statBlock(label: String, value: String, unit: String?,
                           size: CGFloat, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label)
                .font(state.scaledFont(size: 7, weight: .medium))
                .tracking(0.8)
                .foregroundStyle(.white.opacity(0.5))
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(state.scaledFont(size: size, weight: .bold))
                    .foregroundStyle(color)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                if let unit = unit {
                    Text(unit)
                        .font(state.scaledFont(size: 9, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
        }
    }

    @ViewBuilder
    private func miniStat(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label)
                .font(state.scaledFont(size: 6, weight: .medium))
                .tracking(0.8)
                .foregroundStyle(.white.opacity(0.45))
            Text(value)
                .font(state.scaledFont(size: 12, weight: .bold))
                .foregroundStyle(color)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func splitRow(_ split: WatchSplit) -> some View {
        HStack(spacing: 5) {
            Text("KM\(split.km)")
                .font(state.scaledFont(size: 10, weight: .heavy))
                .foregroundStyle(state.accentColor)
                .frame(width: 28, alignment: .leading)
            VStack(alignment: .leading, spacing: 0) {
                Text(split.pace)
                    .font(state.scaledFont(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                Text(split.formattedDuration)
                    .font(state.scaledFont(size: 7, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
            }
            Spacer(minLength: 0)
            if split.bpm > 0 {
                Text("\(split.bpm)")
                    .font(state.scaledFont(size: 10, weight: .bold))
                    .foregroundStyle(state.secondaryColor)
            }
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 4)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 3))
    }

    /// User tocou OK — manda `acknowledgeComplete` pro iPhone, que vai
    /// transicionar de volta pra idle (push status=idle). Watch reseta o
    /// localStep pra .selectingType ao receber.
    private func acknowledge() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }
        let msg: [String: Any] = ["action": "acknowledgeComplete"]
        if session.isReachable {
            session.sendMessage(msg, replyHandler: nil, errorHandler: { _ in
                session.transferUserInfo(msg)
            })
        } else {
            session.transferUserInfo(msg)
        }
        // Otimista: força localStep idle imediatamente — UI volta pro
        // TypeSelector mesmo se o push de volta do iPhone demorar.
        state.status = .idle
        state.localStep = .selectingType
        state.splits = []
    }
}
