import SwiftUI

/// Roteador raiz do Watch app. Decide qual tela mostrar baseado em:
///   - state.status (idle | active | paused), vindo do iPhone
///   - state.localStep (selectingType | briefing), navegação local
///     durante idle pra replicar Passo 1/5 → 5/5 do prep_page iPhone
@available(iOS 26.0, watchOS 10.0, *)
struct ContentView: View {
    @EnvironmentObject var state: WatchRunState

    var body: some View {
        Group {
            switch state.status {
            case .idle:
                switch state.localStep {
                case .selectingType:
                    PreRunScreen()
                case .briefing(let selected):
                    BriefingScreen(selected: selected)
                }
            case .active, .paused:
                ActiveRunScreen()
            }
        }
    }
}

@available(iOS 26.0, watchOS 10.0, *)
#Preview {
    ContentView()
        .environmentObject(WatchRunState.shared)
}
