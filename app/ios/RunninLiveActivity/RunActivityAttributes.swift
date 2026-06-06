// Modelo da Live Activity de corrida. Estrutura DEVE estar idêntica nos
// dois targets (Runner + RunninLiveActivity) porque o plugin lê/escreve
// pelo Runner e o widget renderiza pelo extension — Swift identifica os
// tipos por `ModuleName.TypeName`, então o jeito é adicionar este arquivo
// como Target Membership de AMBOS no Xcode (não duplicar arquivo).
//
// ContentState: tudo que muda durante a run (atualizado via update()).
// Attributes: tudo que fixa quando a activity inicia (sessionType, runId).

import ActivityKit
import Foundation

public struct RunActivityAttributes: ActivityAttributes {
  public struct ContentState: Codable, Hashable {
    /// Distância acumulada em km. UI mostra com 2 casas (ex: 2.34).
    public var distanceKm: Double
    /// Tempo total decorrido em segundos.
    public var elapsedSeconds: Int
    /// Pace atual em min/km (raw double). Null quando indisponível
    /// (drift parado, sample muito velho). UI cai pra "—:—".
    public var paceMinKmRaw: Double?

    public init(distanceKm: Double, elapsedSeconds: Int, paceMinKmRaw: Double?) {
      self.distanceKm = distanceKm
      self.elapsedSeconds = elapsedSeconds
      self.paceMinKmRaw = paceMinKmRaw
    }
  }

  /// Tipo da sessão exibido como subtítulo ("Free Run", "Easy Run",
  /// "Long Run", etc.). Vem do Dart pelo MethodChannel ao iniciar.
  public var sessionType: String

  public init(sessionType: String) {
    self.sessionType = sessionType
  }
}
