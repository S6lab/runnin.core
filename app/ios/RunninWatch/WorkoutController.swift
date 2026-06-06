import Foundation
import HealthKit
import OSLog
import SwiftUI

private let wcLog = OSLog(subsystem: "ai.runnin.workout", category: "workout-controller")

/// Gerencia o ciclo de vida da HKWorkoutSession no Apple Watch.
///
/// Critical path: `start()` cria a session + `HKLiveWorkoutBuilder` com
/// data source — sem o data source, o Watch NÃO escreve heart rate em alta
/// frequência no HK store. Esse é o efeito que estamos buscando: forçar
/// o Watch a sair do modo idle (~5 min/sample) pro modo workout (~1 Hz).
///
/// Idempotência: chamadas redundantes a `start()` quando já há session ativa
/// viram no-op silencioso (mesma garantia que o equivalente iPhone-side).
class WorkoutController: NSObject, ObservableObject {
    static let shared = WorkoutController()

    @Published var isActive: Bool = false
    /// Último BPM observado pelo builder (pra UI mínima do Watch — não vai
    /// pro iPhone via WCSession; iPhone lê direto do HK store).
    @Published var lastHeartRate: Int = 0

    private let healthStore = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?

    private override init() {
        super.init()
    }

    /// Solicita autorização HealthKit pra leitura/escrita necessárias e
    /// inicia uma `HKWorkoutSession` configurada como running outdoor.
    /// Em qualquer falha (permissão negada, plataforma sem HK), loga e
    /// segue silencioso — o iPhone faz fallback pra HKAnchoredObjectQuery
    /// normal e o app não quebra.
    func start() {
        guard session == nil else {
            os_log("start.idempotent skip=already_running", log: wcLog, type: .info)
            return
        }
        guard HKHealthStore.isHealthDataAvailable() else {
            os_log("start.no_healthkit", log: wcLog, type: .error)
            return
        }

        let typesToShare: Set<HKSampleType> = [HKObjectType.workoutType()]
        let typesToRead: Set<HKObjectType> = {
            var s = Set<HKObjectType>()
            if let hr = HKObjectType.quantityType(forIdentifier: .heartRate) { s.insert(hr) }
            if let cal = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) { s.insert(cal) }
            if let dist = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning) { s.insert(dist) }
            return s
        }()

        healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { [weak self] granted, error in
            guard let self = self else { return }
            if !granted {
                os_log("auth.denied err=%{public}@", log: wcLog, type: .error,
                       error?.localizedDescription ?? "no_error_info")
                return
            }
            DispatchQueue.main.async {
                self.startSessionInternal()
            }
        }
    }

    private func startSessionInternal() {
        let config = HKWorkoutConfiguration()
        config.activityType = .running
        config.locationType = .outdoor

        do {
            let s = try HKWorkoutSession(healthStore: healthStore, configuration: config)
            let b = s.associatedWorkoutBuilder()
            b.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: config)
            s.delegate = self
            b.delegate = self
            session = s
            builder = b

            s.startActivity(with: Date())
            b.beginCollection(withStart: Date()) { [weak self] success, error in
                if !success {
                    os_log("builder.begin_failed err=%{public}@", log: wcLog, type: .error,
                           error?.localizedDescription ?? "nil")
                    self?.stop()
                    return
                }
                os_log("workout.started type=running", log: wcLog, type: .info)
            }

            DispatchQueue.main.async {
                self.isActive = true
            }
        } catch {
            os_log("session.create_failed err=%{public}@", log: wcLog, type: .error,
                   error.localizedDescription)
        }
    }

    func stop() {
        guard let s = session else {
            os_log("stop.idempotent skip=no_session", log: wcLog, type: .info)
            return
        }
        s.end()
        builder?.endCollection(withEnd: Date()) { [weak self] _, _ in
            self?.builder?.finishWorkout { _, _ in
                DispatchQueue.main.async {
                    self?.session = nil
                    self?.builder = nil
                    self?.isActive = false
                    self?.lastHeartRate = 0
                    os_log("workout.ended", log: wcLog, type: .info)
                }
            }
        }
    }
}

extension WorkoutController: HKWorkoutSessionDelegate {
    func workoutSession(_ workoutSession: HKWorkoutSession,
                        didChangeTo toState: HKWorkoutSessionState,
                        from fromState: HKWorkoutSessionState,
                        date: Date) {
        os_log("session.state %{public}@ -> %{public}@", log: wcLog, type: .info,
               String(describing: fromState), String(describing: toState))
    }

    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        os_log("session.failed err=%{public}@", log: wcLog, type: .error,
               error.localizedDescription)
        DispatchQueue.main.async {
            self.session = nil
            self.builder = nil
            self.isActive = false
        }
    }
}

extension WorkoutController: HKLiveWorkoutBuilderDelegate {
    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        // No-op — sem eventos próprios pra registrar.
    }

    /// Cada vez que samples novos chegam pra builder, atualiza a UI minimal do
    /// Watch (só BPM atual). O iPhone Runnin lê todos os samples direto do HK
    /// store via HKAnchoredObjectQuery — não dependemos do builder pra
    /// "transmitir" dados; ele existe pra forçar o Watch a SALVAR samples
    /// em high-freq mode.
    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder,
                        didCollectDataOf collectedTypes: Set<HKSampleType>) {
        guard let hrType = HKObjectType.quantityType(forIdentifier: .heartRate),
              collectedTypes.contains(hrType),
              let stats = workoutBuilder.statistics(for: hrType) else { return }
        let unit = HKUnit.count().unitDivided(by: .minute())
        if let mostRecent = stats.mostRecentQuantity()?.doubleValue(for: unit) {
            DispatchQueue.main.async {
                self.lastHeartRate = Int(mostRecent.rounded())
            }
        }
    }
}
