// MethodChannel `runnin/live_activity` — bridge entre Dart e ActivityKit
// (iOS 16.2+). Estados:
//   - start(distanceM, elapsedS, paceMinKm, sessionType) → cria activity
//   - update(distanceM, elapsedS, paceMinKm) → atualiza state
//   - end() → encerra
//   - isSupported() → false em iOS < 16.2 (caller cai pra notif local)
//
// Side-by-side com flutter_local_notifications: Dart decide qual usar
// pelo retorno de isSupported. Não tentamos disputar a UI — quando Live
// Activity tá rodando, a notif local nem chega a ser exibida.

import ActivityKit
import Flutter
import Foundation
import OSLog
import UIKit

/// Logger pra debugar Live Activity em Console.app — filtra com
/// `subsystem:ai.runnin.live_activity`. User reportou que a notif
/// "regrediu" pra tamanho pequeno — log ajuda a confirmar se Live Activity
/// está sendo iniciada (caminho ok) ou caindo no fallback (flutter_local_
/// notifications) silenciosamente.
private let laLog = OSLog(subsystem: "ai.runnin.live_activity", category: "lifecycle")

@objc class LiveActivityPlugin: NSObject, FlutterPlugin {
  private static let channelName = "runnin/live_activity"
  // Mantido como Any pra evitar generic em static var (Swift não aceita).
  // Cast pra Activity<RunActivityAttributes> nos handlers iOS 16.2+.
  private static var currentActivity: Any?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: channelName, binaryMessenger: registrar.messenger())
    let instance = LiveActivityPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "isSupported":
      // Antes retornava `areActivitiesEnabled` que pode ser false em estado
      // "não determinado" (user nunca prompted). Isso fazia o Dart pular o
      // start e cair direto pra notif local pequena — usuário no TF não
      // chegava a ver o prompt do iOS. Agora retornamos true se iOS >= 16.2
      // e o start tenta de fato, permitindo iOS exibir o prompt nativo.
      if #available(iOS 16.2, *) {
        result(true)
      } else {
        result(false)
      }
    case "getDiagnostics":
      // Consultado pela UI pra mostrar banner "Active ao Vivo desabilitada
      // em Ajustes" quando applicable. Sem efeitos colaterais — read-only.
      if #available(iOS 16.2, *) {
        let activity = LiveActivityPlugin.currentActivity as? Activity<RunActivityAttributes>
        result([
          "areActivitiesEnabled": ActivityAuthorizationInfo().areActivitiesEnabled,
          "currentActivityID": activity?.id ?? "",
          "iosVersion": UIDevice.current.systemVersion,
        ])
      } else {
        result([
          "areActivitiesEnabled": false,
          "currentActivityID": "",
          "iosVersion": UIDevice.current.systemVersion,
        ])
      }
    case "start":
      if #available(iOS 16.2, *) {
        handleStart(call: call, result: result)
      } else {
        result(false)
      }
    case "primePermission":
      // Cria uma Activity dummy e encerra na mesma — força o iOS exibir o
      // prompt "Permitir Atividades ao Vivo?" no lock screen. Usado pelo
      // Dart no boot (1x por instalação) pra disparar o prompt de
      // permissão sem precisar esperar a primeira corrida. Idempotente —
      // chamadas subsequentes só retornam o estado atual.
      if #available(iOS 16.2, *) {
        handlePrimePermission(result: result)
      } else {
        result(["ok": false, "reason": "ios_too_old"])
      }
    case "update":
      if #available(iOS 16.2, *) {
        handleUpdate(call: call, result: result)
      } else {
        result(false)
      }
    case "end":
      if #available(iOS 16.2, *) {
        handleEnd(call: call, result: result)
      } else {
        result(true)
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  /// Dispara o prompt nativo do iOS "Permitir Atividades ao Vivo?" criando
  /// uma Activity dummy de 1.5s e encerrando. Necessário porque iOS NÃO
  /// expõe uma API `requestAuthorization` pra Live Activities (diferente
  /// de Health/Notifications/Location). O prompt só dispara via call real
  /// de `Activity.request`. Chamamos no boot uma vez por instalação.
  @available(iOS 16.2, *)
  private func handlePrimePermission(result: @escaping FlutterResult) {
    let enabled = ActivityAuthorizationInfo().areActivitiesEnabled
    os_log("prime.attempt enabled=%d", log: laLog, type: .info, enabled ? 1 : 0)
    let attributes = RunActivityAttributes(sessionType: "Preparando")
    let content = RunActivityAttributes.ContentState(
      distanceKm: 0,
      elapsedSeconds: 0,
      paceMinKmRaw: nil
    )
    do {
      let activity = try Activity<RunActivityAttributes>.request(
        attributes: attributes,
        content: ActivityContent(state: content, staleDate: nil)
      )
      os_log("prime.activity_created id=%{public}@", log: laLog, type: .info, activity.id)
      // Encerra após 1.5s — tempo suficiente do iOS rolar o prompt na lock
      // screen. Mais curto pode cancelar antes do prompt aparecer.
      Task {
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        await activity.end(activity.content, dismissalPolicy: .immediate)
        os_log("prime.activity_ended", log: laLog, type: .info)
      }
      result(["ok": true, "primed": true])
    } catch {
      // Lança quando user já tinha negado explicitamente, ou iOS bloqueou.
      os_log("prime.failed err=%{public}@", log: laLog, type: .error,
             error.localizedDescription)
      result(["ok": false, "reason": "request_threw",
              "error": error.localizedDescription])
    }
  }

  @available(iOS 16.2, *)
  private func handleStart(call: FlutterMethodCall, result: @escaping FlutterResult) {
    let enabled = ActivityAuthorizationInfo().areActivitiesEnabled
    os_log("start.attempt enabled=%d", log: laLog, type: .info, enabled ? 1 : 0)
    // Removido o `guard areActivitiesEnabled else { return }` original —
    // em casos do iOS device real (TF), areActivitiesEnabled pode reportar
    // false mesmo quando o user nunca foi prompted (estado "not_determined").
    // Deixar Activity.request tentar: iOS exibe o prompt nativo na lock
    // screen e propaga a decisão. Se realmente proibido, o request lança e
    // caímos no catch com reason=request_threw.
    guard let args = call.arguments as? [String: Any] else {
      result(FlutterError(code: "bad_args", message: "args missing", details: nil))
      return
    }
    let distanceM = doubleOf(args["distanceM"]) ?? 0
    let elapsedS = intOf(args["elapsedS"]) ?? 0
    let paceMinKm = doubleOf(args["paceMinKm"])
    let bpm = intOf(args["bpm"])
    let sessionType = (args["sessionType"] as? String) ?? "Corrida"

    // Se já existe activity rodando, encerra a velha antes de criar nova
    // (evita acúmulo se o Dart chamar start 2x sem end no meio — pode
    // acontecer em casos de crash do isolate).
    if let old = LiveActivityPlugin.currentActivity as? Activity<RunActivityAttributes> {
      Task {
        await old.end(old.content, dismissalPolicy: .immediate)
      }
    }

    let attributes = RunActivityAttributes(sessionType: sessionType)
    let content = RunActivityAttributes.ContentState(
      distanceKm: distanceM / 1000.0,
      elapsedSeconds: elapsedS,
      paceMinKmRaw: paceMinKm,
      bpmRaw: bpm
    )

    do {
      let activity = try Activity<RunActivityAttributes>.request(
        attributes: attributes,
        content: ActivityContent(state: content, staleDate: nil)
      )
      LiveActivityPlugin.currentActivity = activity
      os_log("start.success id=%{public}@ session=%{public}@", log: laLog, type: .info,
             activity.id, sessionType)
      result(["ok": true, "id": activity.id])
    } catch {
      // request lança quando: Live Activities desabilitadas pelo user
      // em Settings > <App> > Live Activities, ou cap atingido (apple
      // limita a quantidade simultânea).
      os_log("start.failed err=%{public}@", log: laLog, type: .error,
             error.localizedDescription)
      result(["ok": false, "reason": "request_threw", "error": error.localizedDescription])
    }
  }

  @available(iOS 16.2, *)
  private func handleUpdate(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any] else {
      result(FlutterError(code: "bad_args", message: "args missing", details: nil))
      return
    }
    let distanceM = doubleOf(args["distanceM"]) ?? 0
    let elapsedS = intOf(args["elapsedS"]) ?? 0
    let paceMinKm = doubleOf(args["paceMinKm"])
    let bpm = intOf(args["bpm"])

    // Update implícito-start: se Dart chamar update sem start (cenário
    // raro mas possível em hot restart), criamos a activity ad-hoc com
    // sessionType default. Senão, atualizamos a existente.
    if let activity = LiveActivityPlugin.currentActivity as? Activity<RunActivityAttributes> {
      let content = RunActivityAttributes.ContentState(
        distanceKm: distanceM / 1000.0,
        elapsedSeconds: elapsedS,
        paceMinKmRaw: paceMinKm,
        bpmRaw: bpm
      )
      Task {
        await activity.update(ActivityContent(state: content, staleDate: nil))
        result(true)
      }
    } else {
      // Reconstrói args como dict pra reusar handleStart.
      var newArgs = args
      if newArgs["sessionType"] == nil { newArgs["sessionType"] = "Corrida" }
      let synthetic = FlutterMethodCall(methodName: "start", arguments: newArgs)
      handleStart(call: synthetic, result: result)
    }
  }

  @available(iOS 16.2, *)
  private func handleEnd(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let activity = LiveActivityPlugin.currentActivity as? Activity<RunActivityAttributes> else {
      result(true)
      return
    }
    Task {
      await activity.end(activity.content, dismissalPolicy: .immediate)
      LiveActivityPlugin.currentActivity = nil
      result(true)
    }
  }

  // MARK: - Helpers de cast

  private func doubleOf(_ v: Any?) -> Double? {
    if let d = v as? Double { return d }
    if let i = v as? Int { return Double(i) }
    if let n = v as? NSNumber { return n.doubleValue }
    return nil
  }

  private func intOf(_ v: Any?) -> Int? {
    if let i = v as? Int { return i }
    if let d = v as? Double { return Int(d) }
    if let n = v as? NSNumber { return n.intValue }
    return nil
  }
}
