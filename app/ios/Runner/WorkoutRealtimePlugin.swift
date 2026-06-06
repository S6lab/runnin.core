import Flutter
import HealthKit
import OSLog
import UIKit
import WatchConnectivity

/// Logger subsystem dedicado pra rastrear HR streaming no Console.app durante
/// debug em device. Filtrar via `subsystem:ai.runnin.workout category:hr`.
private let hrLog = OSLog(subsystem: "ai.runnin.workout", category: "hr")
/// Logger pra eventos de WatchConnectivity (start/stop messages, pairing).
private let wcLog = OSLog(subsystem: "ai.runnin.workout", category: "watch-bridge")

/// Plugin nativo iOS pra BPM realtime durante a Run ativa.
///
/// Usa HKAnchoredObjectQuery (iOS 9+) — disponível em qualquer device com
/// deployment target 14+, sem precisar de Apple Watch dedicado mas se
/// beneficia totalmente dele: o Watch escreve heart rate samples no
/// HealthKit store compartilhado a ~1-2Hz e a updateHandler dispara
/// pra cada novo sample.
///
/// Decisão de design vs HKWorkoutSession + HKLiveWorkoutBuilder:
///   - HKLiveWorkoutBuilder no iPhone (sem watchOS companion) só ficou
///     disponível em iOS 26 (Apple Watch sempre teve, iPhone não).
///   - HKWorkoutSession no iPhone exige iOS 17+.
///   - HKAnchoredObjectQuery funciona em iOS 9+, entrega o mesmo BPM
///     live com o Watch como source — só não cria o "workout" no
///     Activity Ring. Pra esse PR, prioridade é compat amplo. Activity
///     Ring fica pra um seguimento (quando bumpar deployment target).
///
/// Lifecycle:
///   - start(): solicita autorização HEART_RATE; cria HKAnchoredObjectQuery
///     com predicado start=now, anchor inicial nil, e updateHandler que
///     emite o sample mais recente. Idempotente — chama no-op se já active.
///   - pause(): healthStore.stop(query) preservando o anchor da última
///     resposta. Resume cria nova query com esse anchor → não perde gap.
///   - stop(): healthStore.stop(query), descarta anchor. Idempotente.
///
/// Timer de 8s ao start: se nenhum sample chegou → warning `no_hr_source`
/// (Watch desligado, sem permission, ou esquece o relógio).
@objc class WorkoutRealtimePlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private static let methodChannelName = "runnin/workout_realtime"
  private static let eventChannelName = "runnin/workout_realtime/events"

  private let healthStore = HKHealthStore()
  private var query: HKAnchoredObjectQuery?
  private var lastAnchor: HKQueryAnchor?
  private var eventSink: FlutterEventSink?
  private var noSourceTimer: Timer?
  private var receivedAtLeastOne = false
  // Throttling do os_log: 1 a cada 5 samples pra não inundar Console.app
  // durante runs longos (Apple Watch emite ~1Hz).
  private var sampleLogCounter = 0

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = WorkoutRealtimePlugin()
    let method = FlutterMethodChannel(name: methodChannelName, binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(instance, channel: method)
    let event = FlutterEventChannel(name: eventChannelName, binaryMessenger: registrar.messenger())
    event.setStreamHandler(instance)
    instance.activateWatchSession()
  }

  // MARK: WatchConnectivity bridge — força HKWorkoutSession no Watch

  /// Ativa o WCSession quando o app sobe. Sem isso, mensagens enviadas via
  /// `sendMessage`/`transferUserInfo` ficam encolhidas até a sessão ativar
  /// e podem chegar fora de ordem. Idempotente — WatchConnectivity faz dedup.
  private func activateWatchSession() {
    guard WCSession.isSupported() else {
      os_log("activate skip=not_supported", log: wcLog, type: .info)
      return
    }
    let session = WCSession.default
    session.delegate = self
    session.activate()
  }

  /// Manda mensagem pro Watch companion (RunninWatch). Quando o Watch está
  /// reachable (app rodando em foreground OU complication ativa), usa
  /// `sendMessage` — entrega imediata. Senão cai pra `transferUserInfo` que
  /// fila a mensagem até o Watch acordar. Pra `startWorkout` o ideal é
  /// `sendMessage` (queremos efeito imediato); pra `stopWorkout` ambos
  /// funcionam (queremos garantia de entrega mesmo se o Watch tá dormindo).
  private func notifyWatch(action: String) {
    guard WCSession.isSupported() else { return }
    let session = WCSession.default
    guard session.activationState == .activated else {
      os_log("notify skip=not_activated action=%{public}@", log: wcLog, type: .info, action)
      return
    }
    guard session.isPaired, session.isWatchAppInstalled else {
      os_log("notify skip=no_watch_app paired=%d installed=%d action=%{public}@",
             log: wcLog, type: .info,
             session.isPaired ? 1 : 0,
             session.isWatchAppInstalled ? 1 : 0,
             action)
      emitWatchStatus()
      return
    }
    let payload: [String: Any] = ["action": action]
    if session.isReachable {
      session.sendMessage(payload, replyHandler: { reply in
        os_log("notify.sent action=%{public}@ reply=%{public}@", log: wcLog, type: .info,
               action, String(describing: reply))
      }, errorHandler: { err in
        os_log("notify.error fallback=userInfo action=%{public}@ err=%{public}@",
               log: wcLog, type: .error, action, err.localizedDescription)
        session.transferUserInfo(payload)
      })
    } else {
      session.transferUserInfo(payload)
      os_log("notify.queued action=%{public}@ (Watch unreachable)", log: wcLog, type: .info, action)
    }
  }

  /// Emite pro Flutter o estado atual do pareamento + instalação do Watch app.
  /// Consumido pelo `WorkoutRealtimeService` em Dart pra renderizar:
  ///   - banner "Conecte um Apple Watch" (paired=false)
  ///   - banner "Instale Runnin no seu Watch" (paired=true, installed=false)
  ///   - badge "via Watch" no chip BPM (todos true durante a corrida)
  private func emitWatchStatus() {
    let session = WCSession.default
    let paired = WCSession.isSupported() && session.activationState == .activated && session.isPaired
    let installed = paired && session.isWatchAppInstalled
    let reachable = installed && session.isReachable
    emit([
      "type": "watch_status",
      "paired": paired,
      "appInstalled": installed,
      "reachable": reachable,
    ])
  }

  // MARK: FlutterStreamHandler

  public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    self.eventSink = events
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    self.eventSink = nil
    return nil
  }

  // MARK: MethodCallHandler

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "checkAvailability":
      checkAvailability(result: result)
    case "start":
      start(result: result)
    case "pause":
      pauseQuery(result: result)
    case "resume":
      resumeQuery(result: result)
    case "stop":
      stop(result: result)
    case "restart":
      restartQuery(result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: Commands

  private func checkAvailability(result: @escaping FlutterResult) {
    guard HKHealthStore.isHealthDataAvailable() else {
      result(["available": false, "reason": "healthkit_unavailable"])
      return
    }
    guard let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
      result(["available": false, "reason": "heart_rate_type_missing"])
      return
    }
    let status = healthStore.authorizationStatus(for: hrType)
    if status == .notDetermined {
      result(["available": true, "reason": "permission_required"])
      return
    }
    result(["available": true])
  }

  private func start(result: @escaping FlutterResult) {
    // Já active? No-op (idempotência).
    if query != nil {
      result(nil)
      return
    }
    guard let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
      emit(["type": "error", "code": "heart_rate_type_missing"])
      result(nil)
      return
    }
    os_log("auth_request_start", log: hrLog, type: .info)
    healthStore.requestAuthorization(toShare: [], read: [hrType]) { [weak self] granted, error in
      guard let self = self else { return }
      if !granted || error != nil {
        os_log("auth_denied granted=%d err=%{public}@", log: hrLog, type: .error,
               granted ? 1 : 0, error?.localizedDescription ?? "nil")
        self.emit([
          "type": "error",
          "code": "permission_denied",
          "message": error?.localizedDescription ?? "denied",
        ])
        DispatchQueue.main.async { result(nil) }
        return
      }
      os_log("auth_granted", log: hrLog, type: .info)
      DispatchQueue.main.async {
        self.startQueryInternal(hrType: hrType, result: result)
        // Pede pro Watch companion iniciar HKWorkoutSession nativa — esse é
        // o efeito que coloca o Watch em modo high-frequency HR (~1Hz).
        // Sem o companion / sem essa mensagem, ficamos lendo samples
        // esporádicos do HK store (~5min).
        self.notifyWatch(action: "startWorkout")
        self.emitWatchStatus()
      }
    }
  }

  private func startQueryInternal(hrType: HKQuantityType, result: @escaping FlutterResult) {
    receivedAtLeastOne = false
    sampleLogCounter = 0
    os_log("query_started anchor=%{public}@", log: hrLog, type: .info,
           lastAnchor == nil ? "fresh" : "resumed")

    // Predicado: amostras dos últimos 5 minutos. Antes era `withStart: Date()`
    // — só samples FUTUROS contavam. O problema: o Apple Watch só escreve HR
    // ~1Hz quando ele próprio está em workout. Em "uso normal" o Watch escreve
    // samples esporádicos (1 a cada 1-5 min). Com `withStart: Date()`, se a
    // run começa entre dois desses samples, fica minutos sem nenhum BPM — UI
    // mostra "—" e usuário acha que tá quebrado.
    //
    // Janela de 5min cobre o intervalo típico do Watch sem ser workout, dando
    // ao usuário um valor BPM logo no início. Updates continuam chegando via
    // updateHandler conforme novos samples são escritos no HK.
    let predicate = HKQuery.predicateForSamples(
      withStart: Date(timeIntervalSinceNow: -300),
      end: nil,
      options: .strictStartDate
    )
    let initialAnchor = lastAnchor // reaproveita anchor do pause anterior se houver

    let newQuery = HKAnchoredObjectQuery(
      type: hrType,
      predicate: predicate,
      anchor: initialAnchor,
      limit: HKObjectQueryNoLimit
    ) { [weak self] _, samples, _, newAnchor, _ in
      self?.handleSamples(samples, anchor: newAnchor)
    }
    newQuery.updateHandler = { [weak self] _, samples, _, newAnchor, _ in
      self?.handleSamples(samples, anchor: newAnchor)
    }
    healthStore.execute(newQuery)
    query = newQuery
    emit(["type": "state", "value": "active"])

    // 8s pra detectar ausência de fonte de heart rate.
    noSourceTimer?.invalidate()
    noSourceTimer = Timer.scheduledTimer(withTimeInterval: 8.0, repeats: false) { [weak self] _ in
      guard let self = self else { return }
      if !self.receivedAtLeastOne {
        self.emit([
          "type": "warning",
          "code": "no_hr_source",
          "message": "No heart rate sample within 8s. Pair an Apple Watch or BLE strap.",
        ])
      }
    }

    result(nil)
  }

  private func pauseQuery(result: @escaping FlutterResult) {
    if let q = query {
      healthStore.stop(q)
      query = nil
    }
    noSourceTimer?.invalidate()
    noSourceTimer = nil
    emit(["type": "state", "value": "paused"])
    result(nil)
  }

  private func resumeQuery(result: @escaping FlutterResult) {
    // Resume retoma do anchor preservado (sem perder gap entre pause/resume).
    if query != nil {
      result(nil)
      return
    }
    guard let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
      result(nil)
      return
    }
    startQueryInternal(hrType: hrType, result: result)
  }

  private func stop(result: @escaping FlutterResult) {
    noSourceTimer?.invalidate()
    noSourceTimer = nil
    if let q = query {
      healthStore.stop(q)
      query = nil
    }
    lastAnchor = nil
    // Encerra HKWorkoutSession no Watch (libera Activity Ring + sai do
    // modo high-freq HR). Mesmo se Watch estiver dormindo, transferUserInfo
    // entrega quando ele acordar — evita session ficar "pendurada" e
    // drenando bateria silenciosamente.
    notifyWatch(action: "stopWorkout")
    emit(["type": "state", "value": "ended"])
    result(nil)
  }

  /// Recria a HKAnchoredObjectQuery preservando o anchor — caminho de
  /// resgate quando a query "morre em silêncio" (Watch perde sinal, app
  /// suspende). Diferente de stop+start: lastAnchor não é zerado, então
  /// não duplicamos samples antigos. Idempotente quando query==nil
  /// (chama startQueryInternal direto).
  private func restartQuery(result: @escaping FlutterResult) {
    os_log("query_restart anchor=%{public}@", log: hrLog, type: .info,
           lastAnchor == nil ? "fresh" : "preserved")
    if let q = query {
      healthStore.stop(q)
      query = nil
    }
    noSourceTimer?.invalidate()
    noSourceTimer = nil
    guard let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
      result(nil)
      return
    }
    startQueryInternal(hrType: hrType, result: result)
  }

  // MARK: Helpers

  private func handleSamples(_ samples: [HKSample]?, anchor: HKQueryAnchor?) {
    if let anchor = anchor {
      lastAnchor = anchor
    }
    guard let quantities = samples as? [HKQuantitySample], !quantities.isEmpty else {
      return
    }
    // Pega o sample mais recente do batch.
    let latest = quantities.max(by: { $0.endDate < $1.endDate })
    guard let sample = latest else { return }
    let unit = HKUnit.count().unitDivided(by: .minute())
    let bpmValue = Int(sample.quantity.doubleValue(for: unit).rounded())
    sampleLogCounter += 1
    if sampleLogCounter % 5 == 1 {
      os_log("hr_sample bpm=%d count=%d", log: hrLog, type: .info, bpmValue, quantities.count)
    }
    receivedAtLeastOne = true
    emit([
      "type": "bpm",
      "value": bpmValue,
      "ts": Int(sample.endDate.timeIntervalSince1970 * 1000),
    ])
  }

  private func emit(_ payload: [String: Any]) {
    DispatchQueue.main.async {
      self.eventSink?(payload)
    }
  }
}

// MARK: - WCSessionDelegate
//
// Métodos obrigatórios pra plataforma iOS. O lado watchOS (RunninWatch)
// implementa o seu próprio delegate; aqui só precisamos reagir a
// mudanças de pareamento / instalação pra propagar pro Flutter.
extension WorkoutRealtimePlugin: WCSessionDelegate {
  public func session(_ session: WCSession,
                      activationDidCompleteWith activationState: WCSessionActivationState,
                      error: Error?) {
    os_log("wc.activation state=%d err=%{public}@", log: wcLog, type: .info,
           activationState.rawValue, error?.localizedDescription ?? "nil")
    emitWatchStatus()
  }

  public func sessionDidBecomeInactive(_ session: WCSession) {
    os_log("wc.inactive", log: wcLog, type: .info)
  }

  public func sessionDidDeactivate(_ session: WCSession) {
    // iOS pode trocar Watch pareado mid-sessão. Reativa pra pegar o novo.
    os_log("wc.deactivate reactivating", log: wcLog, type: .info)
    WCSession.default.activate()
  }

  public func sessionWatchStateDidChange(_ session: WCSession) {
    os_log("wc.watch_state_changed paired=%d installed=%d reachable=%d",
           log: wcLog, type: .info,
           session.isPaired ? 1 : 0,
           session.isWatchAppInstalled ? 1 : 0,
           session.isReachable ? 1 : 0)
    emitWatchStatus()
  }

  public func sessionReachabilityDidChange(_ session: WCSession) {
    os_log("wc.reachability=%d", log: wcLog, type: .info, session.isReachable ? 1 : 0)
    emitWatchStatus()
  }
}
