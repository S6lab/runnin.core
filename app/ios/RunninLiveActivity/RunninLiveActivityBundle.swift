// Bundle do widget extension. Lista APENAS a Live Activity de corrida —
// removemos os widgets default que o Xcode gerou (estático "RunninLiveActivity"
// e Control "RunninLiveActivityControl") porque não usamos.

import SwiftUI
import WidgetKit

@main
struct RunninLiveActivityBundle: WidgetBundle {
  var body: some Widget {
    RunninLiveActivityLiveActivity()
  }
}
