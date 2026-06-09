import Combine
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
@available(iOS 26.0, watchOS 10.0, *)
class WorkoutController: NSObject, ObservableObject {
    static let shared = WorkoutController()

    @Published var isActive: Bool = false
    /// Último BPM observado pelo builder (pra UI mínima do Watch — não vai
    /// pro iPhone via WCSession; iPhone lê direto do HK store).
    @Published var lastHeartRate: Int = 0

    private let healthStore = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    /// Flag pra distinguir `.ended` de stop() explícito (iPhone STOP) vs
    /// suspensão inesperada (Watch perde foreground). Setada em stop() e
    /// limpada em start(). HKWorkoutSessionDelegate usa pra decidir
    /// auto-restart.
    private var intentionalStop: Bool = false
    /// Mock BPM no simulador: HKLiveWorkoutBuilder emite valor sintético
    /// estático/zerado e impede testar zonas/coach end-to-end. Timer roda
    /// só em #if targetEnvironment(simulator) — em device físico, lê o
    /// sensor real e este timer nem é criado.
    #if targetEnvironment(simulator)
    private var mockBpmTimer: Timer?
    private var mockBpmBase: Double = 140
    #endif
    /// Polling defensivo: a cada 3s lê o último BPM do builder.statistics()
    /// e empurra. Resolve casos onde o delegate `didCollectDataOf` para de
    /// ser chamado silenciosamente (tela apagou, watchOS pausou updates) —
    /// statistics() continua retornando o último sample coletado. Em device
    /// real travou em 94 nos testes; com polling o último valor disponível
    /// sempre flui pro phone via WCSession.
    private var bpmPollingTimer: Timer?

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
        // Limpa flag de stop intencional — auto-restart do delegate
        // .ended depende dela; se a próxima session terminar inesperada,
        // queremos reabrir.
        intentionalStop = false
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
        // Gate de availability: Apple só expôs HKLiveWorkoutDataSource em
        // iOS 26 (Xcode 17 SDK). No watchOS sempre existiu, mas o Swift
        // compiler valida cross-platform. Como o app é watchOS-only, na
        // prática esse gate sempre passa em runtime.
        guard #available(iOS 26.0, watchOS 10.0, *) else { return }
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
            startBpmPolling()
            #if targetEnvironment(simulator)
            startMockBpm()
            #endif
        } catch {
            os_log("session.create_failed err=%{public}@", log: wcLog, type: .error,
                   error.localizedDescription)
        }
    }

    #if targetEnvironment(simulator)
    /// Gera BPM com variação leve em torno de uma base que drifta lenta-
    /// mente (warmup/esforço). Pra cada tick (1Hz) joga um valor entre
    /// `base ± 4` e desloca a base em ±0.5 por tick com clamp 110-175.
    /// Suficiente pra exercitar staleness, zonas (Z2-Z4 típicas) e cues
    /// de high_bpm sem precisar de device físico.
    private func startMockBpm() {
        mockBpmTimer?.invalidate()
        mockBpmBase = Double.random(in: 130...145)
        mockBpmTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, self.isActive else { return }
            self.mockBpmBase = max(110, min(175, self.mockBpmBase + Double.random(in: -1.5...2.0)))
            let bpm = Int((self.mockBpmBase + Double.random(in: -4...4)).rounded())
            DispatchQueue.main.async { self.lastHeartRate = bpm }
            SessionDelegate.shared.pushBpmToPhone(bpm)
        }
        os_log("mock_bpm.started base=%.0f", log: wcLog, type: .info, mockBpmBase)
    }

    private func stopMockBpm() {
        mockBpmTimer?.invalidate()
        mockBpmTimer = nil
    }
    #endif

    /// Lê o último BPM do builder a cada 3s e empurra pra UI + iPhone.
    /// HKLiveWorkoutBuilder.statistics() sempre retorna o último sample
    /// disponível — mesmo quando o delegate `didCollectDataOf` para de
    /// ser invocado (Watch tela apagada, sample drift). Em device real,
    /// resolve o "BPM travou em 94" reportado.
    ///
    /// TF 70: além do builder, faz HKSampleQuery direto no HK store como
    /// FALLBACK quando o builder não atualiza. Observado em prod TF 69:
    /// Watch lendo 91 estático enquanto outro HR app mostrava 77 real.
    /// Builder.statistics().mostRecentQuantity() pode ficar travado se o
    /// HKLiveWorkoutDataSource para de receber callbacks (low-power dim,
    /// sensor lost-contact-reacquire). HKSampleQuery direto sempre lê
    /// fresh do store.
    private func startBpmPolling() {
        bpmPollingTimer?.invalidate()
        bpmPollingTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            guard let self = self, self.isActive else { return }
            guard #available(iOS 26.0, watchOS 10.0, *) else { return }
            guard let hrType = HKObjectType.quantityType(forIdentifier: .heartRate) else { return }

            // Tenta o builder primeiro (rota normal, eficiente).
            var bpm: Int = 0
            var bpmSourceFresh = false
            if let b = self.builder,
               let stats = b.statistics(for: hrType),
               let mostRecent = stats.mostRecentQuantity()?.doubleValue(
                   for: HKUnit.count().unitDivided(by: .minute())
               ) {
                let candidate = Int(mostRecent.rounded())
                // Verifica se o sample é recente: stats.endDate é o timestamp
                // do último sample colhido. Se > 10s atrás, o builder tá
                // travado e o valor é stale.
                let ageSec = abs(stats.endDate.timeIntervalSinceNow)
                if candidate > 0 && ageSec < 10 {
                    bpm = candidate
                    bpmSourceFresh = true
                }
            }

            if !bpmSourceFresh {
                // Fallback: HKSampleQuery direto do HK store. Pega o sample
                // mais recente da janela 30s — não depende do builder estar
                // atualizado. Custa mais (query I/O), mas garante fresh.
                self.queryFreshBpmFromStore(hrType: hrType) { freshBpm in
                    guard let bpm = freshBpm, bpm > 0 else { return }
                    DispatchQueue.main.async { self.lastHeartRate = bpm }
                    SessionDelegate.shared.pushBpmToPhone(bpm)
                }
                return
            }

            DispatchQueue.main.async { self.lastHeartRate = bpm }
            SessionDelegate.shared.pushBpmToPhone(bpm)
        }
        os_log("bpm_polling.started interval=3s mode=builder+store_fallback", log: wcLog, type: .info)
    }

    /// HKSampleQuery direto no HK store — fallback quando o builder não
    /// está atualizando. Limita a samples dos últimos 30s pra não pegar
    /// dado velho que ficou no store.
    private func queryFreshBpmFromStore(hrType: HKQuantityType, completion: @escaping (Int?) -> Void) {
        let now = Date()
        let predicate = HKQuery.predicateForSamples(
            withStart: now.addingTimeInterval(-30),
            end: now,
            options: .strictEndDate
        )
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(
            sampleType: hrType,
            predicate: predicate,
            limit: 1,
            sortDescriptors: [sortDescriptor]
        ) { _, samples, error in
            guard error == nil,
                  let sample = samples?.first as? HKQuantitySample else {
                completion(nil)
                return
            }
            let bpm = Int(sample.quantity.doubleValue(
                for: HKUnit.count().unitDivided(by: .minute())
            ).rounded())
            completion(bpm)
        }
        healthStore.execute(query)
    }

    private func stopBpmPolling() {
        bpmPollingTimer?.invalidate()
        bpmPollingTimer = nil
    }

    func stop() {
        guard #available(iOS 26.0, watchOS 10.0, *) else { return }
        guard let s = session else {
            os_log("stop.idempotent skip=no_session", log: wcLog, type: .info)
            return
        }
        // Marca stop como intencional pra delegate didChangeTo .ended NÃO
        // disparar auto-restart. Flag limpa em start() pra próxima sessão.
        intentionalStop = true
        stopBpmPolling()
        #if targetEnvironment(simulator)
        stopMockBpm()
        #endif
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

@available(iOS 26.0, watchOS 10.0, *)
extension WorkoutController: HKWorkoutSessionDelegate {
    func workoutSession(_ workoutSession: HKWorkoutSession,
                        didChangeTo toState: HKWorkoutSessionState,
                        from fromState: HKWorkoutSessionState,
                        date: Date) {
        os_log("session.state %{public}@ -> %{public}@", log: wcLog, type: .info,
               String(describing: fromState), String(describing: toState))

        // TF 68: auto-restart se a sessão terminar SEM stop() explícito.
        // Observado em prod: watchOS suspende HKWorkoutSession quando Watch
        // perde foreground mid-run (notificação, tela apagar). Sem restart,
        // BPM trava no último valor (visto em prod TF 67 — BPM=75 estável
        // por 2min apesar de Watch "ativo" na UI).
        //
        // Guard `intentionalStop`: stop() explícito (via iPhone STOP) seta
        // a flag — não reabrimos. Idempotente: se nova sessão já está
        // tentando subir, o `session != nil` em start() vira no-op.
        if toState == .ended && !self.intentionalStop {
            os_log("session.unexpected_end auto_restart=true", log: wcLog, type: .info)
            DispatchQueue.main.async {
                self.session = nil
                self.builder = nil
                self.isActive = false
                // Restart com pequeno delay pra dar tempo do builder/session
                // limparem state interno antes do healthStore aceitar nova.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.start()
                }
            }
        }
    }

    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        os_log("session.failed err=%{public}@", log: wcLog, type: .error,
               error.localizedDescription)
        DispatchQueue.main.async {
            self.session = nil
            self.builder = nil
            self.isActive = false
            // Falha real (auth/sensor/etc): NÃO tenta restart automático —
            // pode entrar em loop infinito. Loga e segue parado; user
            // pode reiniciar a sessão se for caso transiente.
        }
    }
}

@available(iOS 26.0, watchOS 10.0, *)
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
            let bpm = Int(mostRecent.rounded())
            DispatchQueue.main.async {
                self.lastHeartRate = bpm
            }
            // Push pro iPhone via WCSession. Sem isso, o phone depende da
            // sync HealthKit que iOS suspende em background, deixando o
            // BPM da UI congelado com tela bloqueada (causa de zonas
            // brancas e avgBpm==maxBpm no relatório).
            SessionDelegate.shared.pushBpmToPhone(bpm)
        }
    }
}
