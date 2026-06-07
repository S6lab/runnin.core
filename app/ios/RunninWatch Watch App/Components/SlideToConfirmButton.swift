import SwiftUI
import WatchKit
import OSLog

private let slideLog = OSLog(subsystem: "ai.runnin.workout", category: "slide-button")

/// Botão "deslizar pra confirmar" pra ações destrutivas (PAUSAR / PARAR)
/// na tela de corrida ativa do Watch. Tap simples é fácil de acionar
/// acidentalmente no pulso — slide protege contra falsos positivos.
///
/// Comportamento:
///   - User pressiona thumb (chevron) na esquerda e arrasta pra direita
///   - >= 70% do track: dispara `action()` + reset
///   - < 70%: snapback animation
///   - Haptic .click ao cruzar threshold; .success quando dispara
///
/// Visual: track cinza fundo, fill na cor do action (yellow=pausar, red=parar),
/// chevron + label que muda conforme drag avança ("DESLIZAR" → "SOLTAR").
struct SlideToConfirmButton: View {
    let label: String
    let color: Color
    let action: () -> Void

    @State private var dragX: CGFloat = 0
    @State private var crossedThreshold: Bool = false
    @GestureState private var dragging: Bool = false

    private let trackHeight: CGFloat = 36
    private let thumbWidth: CGFloat = 32

    var body: some View {
        GeometryReader { geo in
            let maxX = max(0, geo.size.width - thumbWidth)
            let progress = maxX > 0 ? min(1, max(0, dragX / maxX)) : 0
            // Threshold reduzido de 70% pra 60% — user reportou que os botões
            // não disparavam. 60% ainda protege contra tap acidental mas
            // tolera dedos menos certeiros.
            let triggered = progress >= 0.6

            ZStack(alignment: .leading) {
                // Track
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.08))
                // Filled indicator
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(0.45))
                    .frame(width: max(thumbWidth, dragX + thumbWidth))
                // Centered label
                Text(triggered ? "SOLTE" : label)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                // Thumb — contentShape garante hit-test em TODA a área 32×36
                // (sem isso, a margem transparente entre o RoundedRectangle
                // interno (28×28) e o frame externo (32×36) ficava sem rota
                // pro gesture, e o drag falhava em iniciar quando o user
                // pegava a borda do thumb).
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(color)
                        .frame(width: thumbWidth - 4, height: trackHeight - 8)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.black)
                }
                .frame(width: thumbWidth, height: trackHeight)
                .offset(x: dragX)
                .animation(dragging ? nil : .spring(response: 0.3), value: dragX)
                .contentShape(Rectangle())
                // `.highPriorityGesture` — vence o swipe horizontal do TabView
                // paginado pai. Sem isso, o drag do thumb conflita com o page
                // swipe e o action() nunca dispara (Apple SwiftUI bug
                // conhecido em watchOS quando 2 gestos horizontais concorrem
                // no mesmo eixo).
                .highPriorityGesture(
                    DragGesture(minimumDistance: 0)
                        .updating($dragging) { _, state, _ in state = true }
                        .onChanged { v in
                            let next = min(maxX, max(0, v.translation.width))
                            if dragX == 0 && next > 0 {
                                os_log("drag.start label=%{public}@ maxX=%.0f",
                                       log: slideLog, type: .info, label, maxX)
                            }
                            dragX = next
                            if triggered && !crossedThreshold {
                                crossedThreshold = true
                                os_log("drag.threshold label=%{public}@ progress=%.2f",
                                       log: slideLog, type: .info, label, progress)
                                WKInterfaceDevice.current().play(.click)
                            } else if !triggered && crossedThreshold {
                                crossedThreshold = false
                            }
                        }
                        .onEnded { _ in
                            os_log("drag.end label=%{public}@ triggered=%d progress=%.2f",
                                   log: slideLog, type: .info,
                                   label, triggered ? 1 : 0, progress)
                            if triggered {
                                WKInterfaceDevice.current().play(.success)
                                action()
                            }
                            dragX = 0
                            crossedThreshold = false
                        }
                )
            }
        }
        .frame(height: trackHeight)
    }
}
