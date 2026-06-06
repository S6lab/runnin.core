import SwiftUI

/// UI minimal do Watch app — só pra dar feedback visual que o workout está
/// rodando. O user não interage aqui (start/stop vem do iPhone), o objetivo
/// é apenas confirmar visualmente que o Watch está coletando BPM.
struct ContentView: View {
    @EnvironmentObject var controller: WorkoutController

    var body: some View {
        VStack(spacing: 8) {
            Text("RUNNIN")
                .font(.system(size: 14, weight: .heavy, design: .monospaced))
                .foregroundColor(.secondary)
                .tracking(2.0)

            if controller.isActive {
                Text("ATIVO")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(.green)
                Spacer()
                Text(controller.lastHeartRate > 0 ? "\(controller.lastHeartRate)" : "—")
                    .font(.system(size: 56, weight: .bold, design: .monospaced))
                    .foregroundColor(.primary)
                Text("BPM")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)
                    .tracking(1.5)
                Spacer()
            } else {
                Spacer()
                Text("AGUARDANDO\nINÍCIO NO IPHONE")
                    .multilineTextAlignment(.center)
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    ContentView()
        .environmentObject(WorkoutController.shared)
}
