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
      if #available(iOS 16.2, *) {
        result(ActivityAuthorizationInfo().areActivitiesEnabled)
      } else {
        result(false)
      }
    case "start":
      if #available(iOS 16.2, *) {
        handleStart(call: call, result: result)
      } else {
        result(false)
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

  @available(iOS 16.2, *)
  private func handleStart(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard ActivityAuthorizationInfo().areActivitiesEnabled else {
      os_log("start.refused reason=activities_disabled", log: laLog, type: .error)
      result(false)
      return
    }
    guard let args = call.arguments as? [String: Any] else {
      result(FlutterError(code: "bad_args", message: "args missing", details: nil))
      return
    }
    let distanceM = doubleOf(args["distanceM"]) ?? 0
    let elapsedS = intOf(args["elapsedS"]) ?? 0
    let paceMinKm = doubleOf(args["paceMinKm"])
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
      paceMinKmRaw: paceMinKm
    )

    do {
      let activity = try Activity<RunActivityAttributes>.request(
        attributes: attributes,
        content: ActivityContent(state: content, staleDate: nil)
      )
      LiveActivityPlugin.currentActivity = activity
      os_log("start.success id=%{public}@ session=%{public}@", log: laLog, type: .info,
             activity.id, sessionType)
      result(true)
    } catch {
      // request lança quando: Live Activities desabilitadas pelo user
      // em Settings > <App> > Live Activities, ou cap atingido (apple
      // limita a quantidade simultânea).
      os_log("start.failed err=%{public}@", log: laLog, type: .error,
             error.localizedDescription)
      result(false)
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

    // Update implícito-start: se Dart chamar update sem start (cenário
    // raro mas possível em hot restart), criamos a activity ad-hoc com
    // sessionType default. Senão, atualizamos a existente.
    if let activity = LiveActivityPlugin.currentActivity as? Activity<RunActivityAttributes> {
      let content = RunActivityAttributes.ContentState(
        distanceKm: distanceM / 1000.0,
        elapsedSeconds: elapsedS,
        paceMinKmRaw: paceMinKm
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
