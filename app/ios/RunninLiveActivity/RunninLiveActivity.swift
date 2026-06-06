// Widget Extension da Live Activity de corrida. Renderiza:
//   - Lock screen: card grande (~80pt) com pace · km · tempo em mono bold
//   - Dynamic Island compact: km à esquerda, tempo à direita
//   - Dynamic Island expanded: tudo + sessionType + pace
//   - Minimal (Dynamic Island recolhido): ícone de runner
//
// Tamanhos pensados pra dobrar a altura da notif anterior (que era ~30pt).
// Visual cyber (mono + cyan) bate com a identidade RUNNIN.AI do app.

import ActivityKit
import SwiftUI
import WidgetKit

@main
struct RunninLiveActivityBundle: WidgetBundle {
  var body: some Widget {
    RunninLiveActivity()
  }
}

struct RunninLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: RunActivityAttributes.self) { context in
      // Lock Screen
      RunLockScreenView(
        state: context.state,
        attributes: context.attributes
      )
      .padding(.horizontal, 18)
      .padding(.vertical, 16)
      .background(
        LinearGradient(
          colors: [Color.black, Color(red: 0.05, green: 0.05, blue: 0.10)],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
      )
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          VStack(alignment: .leading, spacing: 2) {
            Text("KM")
              .font(.system(size: 9, weight: .medium, design: .monospaced))
              .foregroundStyle(.white.opacity(0.5))
            Text(formatKm(context.state.distanceKm))
              .font(.system(size: 22, weight: .bold, design: .monospaced))
              .foregroundStyle(.white)
          }
        }
        DynamicIslandExpandedRegion(.trailing) {
          VStack(alignment: .trailing, spacing: 2) {
            Text("TEMPO")
              .font(.system(size: 9, weight: .medium, design: .monospaced))
              .foregroundStyle(.white.opacity(0.5))
            Text(formatTime(context.state.elapsedSeconds))
              .font(.system(size: 22, weight: .bold, design: .monospaced))
              .foregroundStyle(.white)
          }
        }
        DynamicIslandExpandedRegion(.bottom) {
          HStack {
            HStack(spacing: 6) {
              Image(systemName: "figure.run")
                .font(.system(size: 11))
              Text("RUNNIN.AI · \(context.attributes.sessionType.uppercased())")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .tracking(0.8)
            }
            .foregroundStyle(Color.cyan)
            Spacer()
            Text("PACE \(formatPace(context.state.paceMinKmRaw))/km")
              .font(.system(size: 11, weight: .semibold, design: .monospaced))
              .foregroundStyle(.white.opacity(0.85))
          }
          .padding(.top, 4)
        }
      } compactLeading: {
        Text(formatKm(context.state.distanceKm))
          .font(.system(size: 13, weight: .bold, design: .monospaced))
          .foregroundStyle(.white)
      } compactTrailing: {
        Text(formatTime(context.state.elapsedSeconds))
          .font(.system(size: 13, weight: .bold, design: .monospaced))
          .foregroundStyle(.white)
      } minimal: {
        Image(systemName: "figure.run")
          .foregroundStyle(Color.cyan)
      }
      .keylineTint(Color.cyan)
    }
  }
}

struct RunLockScreenView: View {
  let state: RunActivityAttributes.ContentState
  let attributes: RunActivityAttributes

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      // Header: marca + status
      HStack {
        Text("RUNNIN")
          .font(.system(size: 12, weight: .semibold, design: .monospaced))
          .tracking(1.6)
          .foregroundStyle(.white)
        Text(".AI")
          .font(.system(size: 10, weight: .bold, design: .monospaced))
          .padding(.horizontal, 5)
          .padding(.vertical, 2)
          .background(Color.cyan)
          .foregroundStyle(.black)
        Text("·")
          .foregroundStyle(.white.opacity(0.3))
        Text(attributes.sessionType.uppercased())
          .font(.system(size: 10, weight: .medium, design: .monospaced))
          .tracking(1.0)
          .foregroundStyle(.white.opacity(0.55))
        Spacer()
        HStack(spacing: 5) {
          Circle()
            .fill(Color.cyan)
            .frame(width: 6, height: 6)
          Text("CORRIDA ATIVA")
            .font(.system(size: 9, weight: .semibold, design: .monospaced))
            .tracking(0.6)
            .foregroundStyle(.white.opacity(0.75))
        }
      }

      // Linha dos 3 números grandes
      HStack(alignment: .firstTextBaseline, spacing: 0) {
        metric(
          label: "DISTÂNCIA",
          value: formatKm(state.distanceKm),
          unit: "km"
        )
        Spacer(minLength: 8)
        metric(
          label: "PACE",
          value: formatPace(state.paceMinKmRaw),
          unit: "/km"
        )
        Spacer(minLength: 8)
        metric(
          label: "TEMPO",
          value: formatTime(state.elapsedSeconds),
          unit: nil
        )
      }
    }
  }

  @ViewBuilder
  private func metric(label: String, value: String, unit: String?) -> some View {
    VStack(alignment: .leading, spacing: 3) {
      Text(label)
        .font(.system(size: 9, weight: .medium, design: .monospaced))
        .tracking(0.8)
        .foregroundStyle(.white.opacity(0.5))
      HStack(alignment: .firstTextBaseline, spacing: 3) {
        Text(value)
          .font(.system(size: 30, weight: .bold, design: .monospaced))
          .foregroundStyle(.white)
          .minimumScaleFactor(0.7)
          .lineLimit(1)
        if let unit = unit {
          Text(unit)
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundStyle(.white.opacity(0.5))
        }
      }
    }
  }
}

// MARK: - Formatters

func formatKm(_ km: Double) -> String {
  if !km.isFinite || km < 0 { return "0.00" }
  return String(format: "%.2f", km)
}

func formatTime(_ seconds: Int) -> String {
  let s = max(0, seconds)
  let h = s / 3600
  let m = (s % 3600) / 60
  let sec = s % 60
  if h > 0 {
    return String(format: "%d:%02d:%02d", h, m, sec)
  }
  return String(format: "%d:%02d", m, sec)
}

func formatPace(_ minKm: Double?) -> String {
  guard let p = minKm, p.isFinite, p > 0 else { return "—:—" }
  let totalSec = Int((p * 60).rounded())
  let m = totalSec / 60
  let s = totalSec % 60
  // Pace > 30min/km vira lixo de drift — exibe placeholder.
  if m >= 30 { return "—:—" }
  return String(format: "%d:%02d", m, s)
}
