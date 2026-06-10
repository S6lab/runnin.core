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
  /// Snapshot do `WCSession.isReachable` na última transição. Usado pelo
  /// `sessionReachabilityDidChange` pra detectar flip false→true (reconnect)
  /// e emitir `watch_reconnected` pro Dart forçar restart imediato.
  private var _lastReachable: Bool = false
  /// Snapshot pra detectar transição installed: false → true (Watch app
  /// recém-instalado). Cache de applicationContext do Watch é zerado nessa
  /// transição — Dart re-empurra today_session.
  private var _lastInstalled: Bool = false
  // Throttling do os_log: 1 a cada 5 samples pra não inundar Console.app
  // durante runs longos (Apple Watch emite ~1Hz).
  private var sampleLogCounter = 0
  /// Fix TF 59: ring buffer dos últimos request_ids processados pra dedup
  /// dos WatchCommands. transferUserInfo enfileirado offline podia entregar
  /// 2x → iPhone processava 2 pause/resume consecutivos. Watch passa
  /// `request_id` desde TF 59; pré-TF59 não tem request_id e cai no
  /// caminho old-behavior (sem dedup).
  private var _processedRequestIds: [String] = []
  private func _isDuplicateRequest(_ payload: [String: Any]) -> Bool {
    guard let rid = payload["request_id"] as? String else { return false }
    if _processedRequestIds.contains(rid) { return true }
    _processedRequestIds.append(rid)
    if _processedRequestIds.count > 20 { _processedRequestIds.removeFirst() }
    return false
  }

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

  /// Empurra pro Watch o snapshot do RunState atual (elapsedS, distanceM,
  /// paceMinKm, bpm, etc). Watch consome via `didReceiveApplicationContext`
  /// pra atualizar a UI sem precisar de iPhone aberto.
  ///
  /// Usa `updateApplicationContext`: low-latency, dedup automático (entrega
  /// só o último valor, descarta intermediários se Watch tava offline).
  /// Diferente de `sendMessage` que exige reachable.
  ///
  /// Chamado pelo Dart via MethodChannel `runnin/workout_realtime`
  /// method "pushRunState". Idempotente; é OK chamar a cada tick (1Hz).
  private func pushRunState(_ payload: [String: Any]) {
    guard WCSession.isSupported() else {
      os_log("push_state.skip reason=not_supported", log: wcLog, type: .info)
      return
    }
    let session = WCSession.default
    guard session.activationState == .activated else {
      os_log("push_state.skip reason=not_activated state=%d", log: wcLog, type: .info,
             session.activationState.rawValue)
      return
    }
    let typeStr = payload["type"] as? String ?? "?"
    let statusStr = payload["status"] as? String ?? "-"
    do {
      try session.updateApplicationContext(payload)
      os_log("push_state.ok type=%{public}@ status=%{public}@ paired=%d installed=%d reachable=%d",
             log: wcLog, type: .info, typeStr, statusStr,
             session.isPaired ? 1 : 0,
             session.isWatchAppInstalled ? 1 : 0,
             session.isReachable ? 1 : 0)
    } catch {
      // Surface erro completo + chaves do payload pra diagnose. NSInvalidArgument
      // = property-list violation (NSNull, classe custom). WCErrorCodeDeliveryFailed
      // = bridge problem.
      os_log("push_state.fail type=%{public}@ err=%{public}@ keys=%{public}@",
             log: wcLog, type: .error, typeStr,
             error.localizedDescription, payload.keys.joined(separator: ","))
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
    case "pushRunState":
      // Dart manda dict com elapsedS/distanceM/paceMinKm/bpm/calKcal/etc.
      // Watch consome via didReceiveApplicationContext.
      if let args = call.arguments as? [String: Any] {
        pushRunState(args)
      }
      result(nil)
    case "getLastCachedBpm":
      // TF 75 Fase 9: cache nativo do BPM do Watch sobrevive a Dart suspended.
      // Dart pode consultar no resume pra recuperar o último BPM válido sem
      // depender de novo sample chegar.
      let ageMs = lastBpmCachedAtMs == 0 ? Int.max :
        Int(Date().timeIntervalSince1970 * 1000) - lastBpmCachedAtMs
      result([
        "bpm": lastBpmCached,
        "ts": lastBpmCachedAtMs,
        "ageMs": ageMs,
      ])
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  /// TF 75 Fase 9: BPM mais recente recebido do Watch via WCSession,
  /// cacheado em memória nativa. Sobrevive a Dart suspended em background
  /// (Dart engine pode pausar, mas o WCSession delegate Swift continua
  /// rodando). Dart consulta via method channel `getLastCachedBpm` no resume.
  private var lastBpmCached: Int = 0
  private var lastBpmCachedAtMs: Int = 0

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
        // Fluxo TF 69: startWatchApp PRIMEIRO; só depois do callback (com
        // delay pra WCSession reachable settlar) disparamos sendMessage.
        // Em TF 68 chamávamos os 2 em paralelo — sendMessage caía pra
        // transferUserInfo (queued) porque Watch ainda nao estava reachable,
        // e HKWorkoutSession demorava 1-3min pra ativar (visto em prod).
        self.launchWatchAppForeground()
        self.emitWatchStatus()
      }
    }
  }

  /// Traz o Runnin Watch app pra foreground e dispara o
  /// HKWorkoutSession associado. Apple expõe essa API em iOS 10+ —
  /// é o caminho oficial pra launch programático do companion.
  ///
  /// Critério de fail-silent: se HK não disponível, Watch não pareado,
  /// ou companion não instalado, loga e segue chamando notifyWatch direto
  /// (caminho degradado — Watch pode acordar via WCSession async).
  private func launchWatchAppForeground() {
    guard HKHealthStore.isHealthDataAvailable() else {
      os_log("launch_watch.skip reason=no_hk", log: wcLog, type: .info)
      // Fallback degradado: tenta sendMessage direto sem delay.
      self.notifyWatch(action: "startWorkout")
      return
    }
    let config = HKWorkoutConfiguration()
    config.activityType = .running
    config.locationType = .outdoor
    healthStore.startWatchApp(with: config) { ok, err in
      if ok {
        os_log("launch_watch.ok type=foreground", log: wcLog, type: .info)
      } else {
        // err.code 100/101 = pareamento ausente; outros = falha temporária.
        os_log("launch_watch.failed err=%{public}@",
               log: wcLog, type: .error,
               err?.localizedDescription ?? "unknown")
      }
      // TF 69: dispara sendMessage DEPOIS do callback com delay 800ms.
      // Independente de ok/err, tentamos — se startWatchApp funcionou,
      // o Watch ja vai estar acordando e tem chance maior de estar
      // reachable. Belt-and-suspenders: o ContentView.onChange no Watch
      // também auto-inicia HKWorkoutSession quando recebe status=active
      // via applicationContext, mesmo sem essa mensagem chegar.
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
        self.notifyWatch(action: "startWorkout")
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

  /// Comandos vindos do Watch (sendMessage com reply). Action strings:
  ///   - "pauseRun" / "resumeRun" / "abandonRun" — controle de corrida em curso
  ///   - "startRun" {type, planSessionId?, isPremium} — Watch quer iniciar corrida
  /// Reply é minimal {"ok": true} pra Watch saber que iPhone recebeu.
  /// O comando vai pro Dart via evento `watch_command` no eventSink — quem
  /// dispatcha no RunBloc é o WorkoutRealtimeService.
  public func session(_ session: WCSession,
                      didReceiveMessage message: [String: Any],
                      replyHandler: @escaping ([String: Any]) -> Void) {
    // BPM push direto do Watch (via SessionDelegate.pushBpmToPhone). Roteia
    // pro mesmo EventChannel que o realtime HK usa — o Dart consome igual.
    // HKAnchoredObjectQuery do phone é suspensa em background; WCSession
    // continua entregando mesmo com tela bloqueada, mantendo o BPM da UI
    // vivo durante toda a corrida.
    if let kind = message["type"] as? String, kind == "bpm_update",
       let bpm = message["bpm"] as? Int {
      let ts = (message["ts"] as? Int) ?? Int(Date().timeIntervalSince1970 * 1000)
      emit(["type": "bpm", "value": bpm, "ts": ts, "source": "watch_wc"])
      receivedAtLeastOne = true
      lastBpmCached = bpm
      lastBpmCachedAtMs = ts
      replyHandler(["ok": true])
      return
    }
    // TF 75 Fase 1: passos cumulativos do Watch via WCSession. Dart usa
    // pra detectar idle (0 passos em 60s) e droppar drift GPS.
    if let kind = message["type"] as? String, kind == "steps_update",
       let steps = message["steps"] as? Int {
      let ts = (message["ts"] as? Int) ?? Int(Date().timeIntervalSince1970 * 1000)
      emit(["type": "steps", "value": steps, "ts": ts, "source": "watch_wc"])
      replyHandler(["ok": true])
      return
    }
    // TF 75 Fase 12: SpO2 (oxigenação) do Watch.
    if let kind = message["type"] as? String, kind == "spo2_update",
       let pct = message["spo2"] as? Int {
      let ts = (message["ts"] as? Int) ?? Int(Date().timeIntervalSince1970 * 1000)
      emit(["type": "spo2", "value": pct, "ts": ts, "source": "watch_wc"])
      replyHandler(["ok": true])
      return
    }
    if let action = message["action"] as? String {
      if _isDuplicateRequest(message) {
        os_log("wc.recv.dup action=%{public}@ dropped", log: wcLog, type: .info, action)
        replyHandler(["ok": true, "dedup": true])
        return
      }
      os_log("wc.recv action=%{public}@", log: wcLog, type: .info, action)
      emit([
        "type": "watch_command",
        "action": action,
        "payload": message,
      ])
      replyHandler(["ok": true])
      return
    }
    replyHandler(["ok": false, "error": "no_action"])
  }

  /// Fallback de delivery quando o Watch chamou `transferUserInfo` porque
  /// `sendMessage` falhou (iPhone unreachable: bloqueado, em background,
  /// app não-foreground, etc.). UserInfo é enfileirado e entregue quando
  /// o iPhone está pronto. Sem este handler, comandos `startRun` enviados
  /// via transferUserInfo eram silenciosamente droppados → Watch travava
  /// em INICIANDO até timeout.
  public func session(_ session: WCSession,
                      didReceiveUserInfo userInfo: [String: Any] = [:]) {
    if let kind = userInfo["type"] as? String, kind == "bpm_update",
       let bpm = userInfo["bpm"] as? Int {
      let ts = (userInfo["ts"] as? Int) ?? Int(Date().timeIntervalSince1970 * 1000)
      emit(["type": "bpm", "value": bpm, "ts": ts, "source": "watch_wc_userinfo"])
      receivedAtLeastOne = true
      lastBpmCached = bpm
      lastBpmCachedAtMs = ts
      return
    }
    if let kind = userInfo["type"] as? String, kind == "steps_update",
       let steps = userInfo["steps"] as? Int {
      let ts = (userInfo["ts"] as? Int) ?? Int(Date().timeIntervalSince1970 * 1000)
      emit(["type": "steps", "value": steps, "ts": ts, "source": "watch_wc_userinfo"])
      return
    }
    if let kind = userInfo["type"] as? String, kind == "spo2_update",
       let pct = userInfo["spo2"] as? Int {
      let ts = (userInfo["ts"] as? Int) ?? Int(Date().timeIntervalSince1970 * 1000)
      emit(["type": "spo2", "value": pct, "ts": ts, "source": "watch_wc_userinfo"])
      return
    }
    if let action = userInfo["action"] as? String {
      if _isDuplicateRequest(userInfo) {
        os_log("wc.recv.userInfo.dup action=%{public}@ dropped", log: wcLog, type: .info, action)
        return
      }
      os_log("wc.recv.userInfo action=%{public}@", log: wcLog, type: .info, action)
      emit([
        "type": "watch_command",
        "action": action,
        "payload": userInfo,
      ])
    }
  }

  /// Watch empurra BPM via `updateApplicationContext` (dedup, entrega sempre)
  /// pra não depender de `isReachable=true` que falha no sim + bg + complica-
  /// tion ativa. Mesma payload {type: "bpm_update", bpm, ts} do path de
  /// sendMessage / userInfo.
  public func session(_ session: WCSession,
                      didReceiveApplicationContext applicationContext: [String: Any]) {
    if let kind = applicationContext["type"] as? String, kind == "bpm_update",
       let bpm = applicationContext["bpm"] as? Int {
      let ts = (applicationContext["ts"] as? Int) ?? Int(Date().timeIntervalSince1970 * 1000)
      emit(["type": "bpm", "value": bpm, "ts": ts, "source": "watch_wc_ctx"])
      receivedAtLeastOne = true
      lastBpmCached = bpm
      lastBpmCachedAtMs = ts
    }
    if let kind = applicationContext["type"] as? String, kind == "steps_update",
       let steps = applicationContext["steps"] as? Int {
      let ts = (applicationContext["ts"] as? Int) ?? Int(Date().timeIntervalSince1970 * 1000)
      emit(["type": "steps", "value": steps, "ts": ts, "source": "watch_wc_ctx"])
    }
    if let kind = applicationContext["type"] as? String, kind == "spo2_update",
       let pct = applicationContext["spo2"] as? Int {
      let ts = (applicationContext["ts"] as? Int) ?? Int(Date().timeIntervalSince1970 * 1000)
      emit(["type": "spo2", "value": pct, "ts": ts, "source": "watch_wc_ctx"])
    }
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
    let nowInstalled = session.isWatchAppInstalled
    os_log("wc.watch_state_changed paired=%d installed=%d reachable=%d",
           log: wcLog, type: .info,
           session.isPaired ? 1 : 0,
           nowInstalled ? 1 : 0,
           session.isReachable ? 1 : 0)
    emitWatchStatus()
    if nowInstalled && !_lastInstalled {
      os_log("wc.watch_app_installed.transition", log: wcLog, type: .info)
      emit(["type": "watch_app_installed"])
    }
    _lastInstalled = nowInstalled
  }

  public func sessionReachabilityDidChange(_ session: WCSession) {
    let nowReachable = session.isReachable
    os_log("wc.reachability=%d", log: wcLog, type: .info, nowReachable ? 1 : 0)
    emitWatchStatus()
    // Reconnect detector: quando reachability vira true depois de ter estado
    // false, surfa um evento dedicado pro Dart forçar restart da query de
    // BPM/HRV sem esperar o timer de staleness (15s). Sem isso o user vê
    // gap visível de BPM toda vez que iPhone+Watch reconectam.
    if nowReachable && _lastReachable == false {
      emit(["type": "watch_reconnected"])
    }
    _lastReachable = nowReachable
  }
}
