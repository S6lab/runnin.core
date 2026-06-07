import SwiftUI

/// Logo header reusada em todas as telas do Watch.
/// Renderiza "RUNNIN.AI" em mono bold — não temos asset SVG no Watch bundle
/// (custo de bundle/coordenação não vale), texto faz o serviço.
///
/// O fundo do ".AI" pega `accentColor` da skin atual do iPhone (vem via
/// WCSession). Default cyan = skin Artico.
struct RunninLogo: View {
    @EnvironmentObject var state: WatchRunState

    var body: some View {
        HStack(spacing: 0) {
            Text("RUNNIN")
                .font(state.scaledFont(size: 11, weight: .heavy))
                .tracking(1.4)
                .foregroundStyle(.white)
            // RoundedRectangle no .background em vez de cor direta — em
            // watchOS 11 o `.background(Color)` com .padding em Text estava
            // expandindo verticalmente pra encher altura do parent VStack
            // do TabView page (visível no screenshot do user: bloco de cor
            // crescendo ~5x). Shape com fill respeita o bounding box do
            // padded text. fixedSize na HStack garante que o conjunto não
            // absorve altura do parent.
            Text(".AI")
                .font(state.scaledFont(size: 9, weight: .bold))
                .padding(.horizontal, 3)
                .padding(.vertical, 1)
                .foregroundStyle(.black)
                .background(
                    RoundedRectangle(cornerRadius: 2)
                        .fill(state.accentColor)
                )
        }
        .fixedSize()
    }
}
