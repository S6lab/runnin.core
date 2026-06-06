import SwiftUI

/// Logo header reusada em todas as telas do Watch.
/// Renderiza "RUNNIN.AI" em mono bold — não temos asset SVG no Watch bundle
/// (custo de bundle/coordenação não vale), texto faz o serviço.
struct RunninLogo: View {
    var body: some View {
        HStack(spacing: 0) {
            Text("RUNNIN")
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                .tracking(1.4)
                .foregroundStyle(.white)
            Text(".AI")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .padding(.horizontal, 3)
                .padding(.vertical, 1)
                .background(Color.cyan)
                .foregroundStyle(.black)
        }
    }
}
