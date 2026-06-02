import Flutter
import HealthKit
import UIKit

/// Plugin nativo iOS pra BPM realtime durante a Run ativa.
///
/// Usa HKWorkoutSession + HKLiveWorkoutBuilder (iOS 17+ permite phone-only,
/// sem Watch companion app) — quando há Apple Watch pareado, samples chegam
/// a ~1Hz via delegate `workoutBuilder:didCollectDataOf:`. Sem Watch, a
/// session sobe mas nenhum sample chega: timer interno emite warning
/// `no_hr_source` após 8s.
///
/// Critical: `session.end()` + `builder.endCollection { builder.finishWorkout }`
/// no stop(), senão o workout fica "aberto" no HealthKit e aparece fantasma
/// na Activity Ring.
@objc class WorkoutRealtimePlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private static let methodChannelName = "runnin/workout_realtime"
  private static let eventChannelName = "runnin/workout_realtime/events"

  private let healthStore = HKHealthStore()
  private var session: HKWorkoutSession?
  private var builder: HKLiveWorkoutBuilder?
  private var builderDelegate: BuilderDelegate?
  private var sessionDelegate: SessionDelegate?
  private var eventSink: FlutterEventSink?
  private var noSourceTimer: Timer?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = WorkoutRealtimePlugin()
    let method = FlutterMethodChannel(name: methodChannelName, binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(instance, channel: method)
    let event = FlutterEventChannel(name: eventChannelName, binaryMessenger: registrar.messenger())
    event.setStreamHandler(instance)
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
      pauseSession(result: result)
    case "resume":
      resumeSession(result: result)
    case "stop":
      stop(result: result)
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
    let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
    let status = healthStore.authorizationStatus(for: hrType)
    if status == .notDetermined {
      result(["available": true, "reason": "permission_required"])
      return
    }
    result(["available": true])
  }

  private func start(result: @escaping FlutterResult) {
    // Ainda em curso? No-op (idempotência).
    if session != nil {
      result(nil)
      return
    }

    let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
    healthStore.requestAuthorization(toShare: [], read: [hrType]) { [weak self] granted, error in
      guard let self = self else { return }
      if !granted || error != nil {
        self.emit(["type": "error", "code": "permission_denied", "message": error?.localizedDescription ?? "denied"])
        DispatchQueue.main.async { result(nil) }
        return
      }
      DispatchQueue.main.async {
        self.startSessionInternal(result: result)
      }
    }
  }

  private func startSessionInternal(result: @escaping FlutterResult) {
    let config = HKWorkoutConfiguration()
    config.activityType = .running
    config.locationType = .outdoor

    do {
      let newSession = try HKWorkoutSession(healthStore: healthStore, configuration: config)
      let newBuilder = newSession.associatedWorkoutBuilder()
      newBuilder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: config)

      let builderDel = BuilderDelegate { [weak self] bpm in
        self?.onBpmSample(bpm)
      }
      let sessionDel = SessionDelegate { [weak self] stateText in
        self?.emit(["type": "state", "value": stateText])
      } onError: { [weak self] message in
        self?.emit(["type": "error", "code": "session_failed", "message": message])
      }

      newSession.delegate = sessionDel
      newBuilder.delegate = builderDel

      self.session = newSession
      self.builder = newBuilder
      self.sessionDelegate = sessionDel
      self.builderDelegate = builderDel

      let start = Date()
      newSession.startActivity(with: start)
      newBuilder.beginCollection(withStart: start) { [weak self] success, err in
        if !success {
          self?.emit(["type": "error", "code": "begin_collection_failed", "message": err?.localizedDescription ?? "unknown"])
        }
      }

      // Timer pra detectar ausência de heart rate source após 8s.
      noSourceTimer?.invalidate()
      noSourceTimer = Timer.scheduledTimer(withTimeInterval: 8.0, repeats: false) { [weak self] _ in
        guard let self = self else { return }
        if self.builderDelegate?.receivedAtLeastOne == false {
          self.emit(["type": "warning", "code": "no_hr_source", "message": "No heart rate source detected within 8s. Pair an Apple Watch or BLE strap."])
        }
      }

      result(nil)
    } catch {
      emit(["type": "error", "code": "session_create_failed", "message": error.localizedDescription])
      result(nil)
    }
  }

  private func pauseSession(result: @escaping FlutterResult) {
    session?.pause()
    result(nil)
  }

  private func resumeSession(result: @escaping FlutterResult) {
    session?.resume()
    result(nil)
  }

  private func stop(result: @escaping FlutterResult) {
    noSourceTimer?.invalidate()
    noSourceTimer = nil
    guard let session = session, let builder = builder else {
      result(nil)
      return
    }
    session.end()
    builder.endCollection(withEnd: Date()) { [weak self] _, _ in
      builder.finishWorkout { _, _ in
        DispatchQueue.main.async {
          self?.cleanup()
          result(nil)
        }
      }
    }
  }

  private func cleanup() {
    session = nil
    builder = nil
    builderDelegate = nil
    sessionDelegate = nil
  }

  // MARK: Helpers

  private func onBpmSample(_ bpm: Double) {
    let value = Int(bpm.rounded())
    emit([
      "type": "bpm",
      "value": value,
      "ts": Int(Date().timeIntervalSince1970 * 1000),
    ])
  }

  private func emit(_ payload: [String: Any]) {
    DispatchQueue.main.async {
      self.eventSink?(payload)
    }
  }
}

// MARK: - Delegates

private final class BuilderDelegate: NSObject, HKLiveWorkoutBuilderDelegate {
  private let onBpm: (Double) -> Void
  fileprivate private(set) var receivedAtLeastOne = false

  init(onBpm: @escaping (Double) -> Void) {
    self.onBpm = onBpm
  }

  func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
    guard let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate),
          collectedTypes.contains(hrType),
          let stats = workoutBuilder.statistics(for: hrType) else {
      return
    }
    let unit = HKUnit.count().unitDivided(by: .minute())
    if let mostRecent = stats.mostRecentQuantity()?.doubleValue(for: unit) {
      receivedAtLeastOne = true
      onBpm(mostRecent)
    }
  }

  func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
    // No-op — não usamos events nesse PR (markers, pauses do builder).
  }
}

private final class SessionDelegate: NSObject, HKWorkoutSessionDelegate {
  private let onStateChange: (String) -> Void
  private let onError: (String) -> Void

  init(onStateChange: @escaping (String) -> Void, onError: @escaping (String) -> Void) {
    self.onStateChange = onStateChange
    self.onError = onError
  }

  func workoutSession(_ workoutSession: HKWorkoutSession,
                      didChangeTo toState: HKWorkoutSessionState,
                      from fromState: HKWorkoutSessionState,
                      date: Date) {
    switch toState {
    case .running:
      onStateChange("active")
    case .paused:
      onStateChange("paused")
    case .ended:
      onStateChange("ended")
    default:
      break
    }
  }

  func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
    onError(error.localizedDescription)
  }
}
