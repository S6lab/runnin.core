// Live Activity de corrida — card grande no lock screen + Dynamic Island.
// Tamanhos pensados pra dobrar a altura da notif anterior (~80pt vs ~30pt).
// Identidade visual mono + cyan bate com RUNNIN.AI do app.
//
// Estrutura:
//   - Lock screen: header (marca + status "CORRIDA ATIVA") + linha com 3
//     métricas grandes (DISTÂNCIA · PACE · TEMPO).
//   - Dynamic Island compact: KM esquerda, TEMPO direita.
//   - Dynamic Island expanded: mesmas métricas + sessionType + pace.
//   - Minimal (recolhido): ícone de runner em cyan.
//
// O modelo está em RunActivityAttributes.swift (mesmo target + Runner via
// Target Membership) e o plugin que dispatcha updates em
// ios/Runner/LiveActivityPlugin.swift.

import ActivityKit
import SwiftUI
import WidgetKit

struct RunninLiveActivityLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: RunActivityAttributes.self) { context in
      // Lock Screen
      RunLockScreenView(
        state: context.state,
        attributes: context.attributes
      )
      .padding(.horizontal, 18)
      .padding(.vertical, 16)
      .activityBackgroundTint(Color.black)
      .activitySystemActionForegroundColor(Color.white)
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
      // Header: logo + sessão + status. Logo é a marca cyan do app
      // (RunninLogo asset do Live Activity extension bundle).
      HStack(spacing: 8) {
        Image("RunninLogo")
          .resizable()
          .aspectRatio(contentMode: .fit)
          .frame(width: 28, height: 28)
          .clipShape(RoundedRectangle(cornerRadius: 6))
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

      // Linha dos 3 (ou 4 com BPM) números grandes
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
        // TF 75 Fase 8: BPM com animação de coração batendo. Só aparece
        // quando wearable conecta — sem isso polui card de free run iPhone-only.
        if let bpm = state.bpmRaw, bpm > 0 {
          Spacer(minLength: 8)
          bpmMetric(bpm: bpm)
        }
      }
    }
  }

  @ViewBuilder
  private func bpmMetric(bpm: Int) -> some View {
    VStack(alignment: .leading, spacing: 3) {
      HStack(spacing: 4) {
        Group {
          if #available(iOS 17.0, *) {
            Image(systemName: "heart.fill")
              .font(.system(size: 9))
              .foregroundStyle(Color.red)
              .symbolEffect(.pulse, options: .repeating)
          } else {
            Image(systemName: "heart.fill")
              .font(.system(size: 9))
              .foregroundStyle(Color.red)
          }
        }
        Text("BPM")
          .font(.system(size: 9, weight: .medium, design: .monospaced))
          .tracking(0.8)
          .foregroundStyle(.white.opacity(0.5))
      }
      Text("\(bpm)")
        .font(.system(size: 30, weight: .bold, design: .monospaced))
        .foregroundStyle(.white)
        .minimumScaleFactor(0.7)
        .lineLimit(1)
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
