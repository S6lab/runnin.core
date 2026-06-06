import SwiftUI

/// Roteador raiz do Watch app. Decide qual tela mostrar baseado no status
/// do RunState que vem do iPhone via WCSession.
@available(iOS 26.0, watchOS 10.0, *)
struct ContentView: View {
    @EnvironmentObject var state: WatchRunState

    var body: some View {
        switch state.status {
        case .idle:
            PreRunScreen()
        case .active, .paused:
            ActiveRunScreen()
        }
    }
}

@available(iOS 26.0, watchOS 10.0, *)
#Preview {
    ContentView()
        .environmentObject(WatchRunState.shared)
}
