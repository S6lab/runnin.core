import SwiftUI

/// Botão "deslizar pra confirmar" pra ações destrutivas (PAUSAR / PARAR)
/// na tela de corrida ativa do Watch. Tap simples é fácil de acionar
/// acidentalmente no pulso — slide protege contra falsos positivos.
///
/// Comportamento:
///   - User pressiona thumb (chevron) na esquerda e arrasta pra direita
///   - >= 70% do track: dispara `action()` + reset
///   - < 70%: snapback animation
///
/// Visual: track cinza fundo, fill na cor do action (yellow=pausar, red=parar),
/// chevron + label que muda conforme drag avança ("DESLIZAR" → "SOLTAR").
struct SlideToConfirmButton: View {
    let label: String
    let color: Color
    let action: () -> Void

    @State private var dragX: CGFloat = 0
    @GestureState private var dragging: Bool = false

    private let trackHeight: CGFloat = 36
    private let thumbWidth: CGFloat = 32

    var body: some View {
        GeometryReader { geo in
            let maxX = max(0, geo.size.width - thumbWidth)
            let progress = maxX > 0 ? min(1, max(0, dragX / maxX)) : 0
            let triggered = progress >= 0.7

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
                // Thumb
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
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .updating($dragging) { _, state, _ in state = true }
                        .onChanged { v in
                            dragX = min(maxX, max(0, v.translation.width))
                        }
                        .onEnded { _ in
                            if triggered {
                                action()
                            }
                            dragX = 0
                        }
                )
            }
        }
        .frame(height: trackHeight)
    }
}
