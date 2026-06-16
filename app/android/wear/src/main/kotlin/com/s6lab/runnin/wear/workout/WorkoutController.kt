package com.s6lab.runnin.wear.workout

import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.core.content.ContextCompat
import androidx.health.services.client.ExerciseClient
import androidx.health.services.client.ExerciseUpdateCallback
import androidx.health.services.client.HealthServices
import androidx.health.services.client.data.Availability
import androidx.health.services.client.data.DataType
import androidx.health.services.client.data.DataTypeAvailability
import androidx.health.services.client.data.ExerciseConfig
import androidx.health.services.client.data.ExerciseLapSummary
import androidx.health.services.client.data.ExerciseType
import androidx.health.services.client.data.ExerciseUpdate
import androidx.health.services.client.data.IntervalDataPoint
import androidx.health.services.client.data.SampleDataPoint
import androidx.health.services.client.data.WarmUpConfig
import com.s6lab.runnin.wear.bridge.WearableMessenger
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.guava.await
import kotlinx.coroutines.launch

/**
 * Gerencia o ciclo de vida da ExerciseSession no Wear OS / Galaxy Watch.
 *
 * Paralelo do `WorkoutController` do Apple Watch (WorkoutController.swift).
 * Aqui ExerciseClient (Health Services API) faz o papel do HKWorkoutSession
 * + HKLiveWorkoutBuilder do iOS — ambos forçam o relógio a sair de modo
 * idle (~5 min/sample) pro modo workout (~1 Hz BPM).
 *
 * Critical path: `start()` chama `exerciseClient.startExerciseAsync` com
 * dataTypes incluindo HEART_RATE_BPM, STEPS_TOTAL, etc. Sem isso o sensor
 * fica em baixa freq.
 *
 * Idempotência: chamadas redundantes a `start()` quando já há session ativa
 * viram no-op silencioso.
 */
class WorkoutController private constructor() {

    var isActive by mutableStateOf(false)
        private set
    /** Último BPM observado (UI mínima do Watch). */
    var lastHeartRate by mutableIntStateOf(0)
        private set
    /** SpO2 % (Wear OS 5+ com oxímetro de pulso, ex: Galaxy Watch 5+/6+). */
    var lastSpo2 by mutableIntStateOf(0)
        private set

    private var appContext: Context? = null
    private var exerciseClient: ExerciseClient? = null

    /**
     * Distingue end() de stop() explícito vs suspensão inesperada (relógio
     * perde foreground). Setada em stop() e limpada em start(). Usada pelo
     * callback ENDED pra decidir auto-restart.
     */
    @Volatile private var intentionalStop = false

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val main = Handler(Looper.getMainLooper())
    private var stalePollJob: Job? = null

    /**
     * Contador de polls consecutivos sem BPM fresh. Quando passa do threshold
     * (~15s == 5 polls de 3s), reabrimos a sessão pra re-engajar o sensor.
     * Paralelo do TF 71 Fase 0 do iOS (L66).
     */
    @Volatile private var consecutiveStalePolls = 0
    private val stalePollsThreshold = 5

    /**
     * Só ativa auto-restart APÓS receber pelo menos 1 sample fresh. Sem isso,
     * warmup inicial (~10-15s sem sample) dispara restart imediato → loop
     * infinito. Paralelo do iOS L72.
     */
    @Volatile private var hasReceivedFreshSample = false
    @Volatile private var lastSampleAtMs: Long = 0L

    fun attach(ctx: Context) {
        if (appContext != null) return
        appContext = ctx.applicationContext
        exerciseClient = HealthServices.getClient(ctx).exerciseClient
    }

    private val updateCallback = object : ExerciseUpdateCallback {
        override fun onRegistered() {
            Log.i(TAG, "exercise_callback.registered")
        }

        override fun onRegistrationFailed(throwable: Throwable) {
            Log.w(TAG, "exercise_callback.register_failed", throwable)
        }

        override fun onAvailabilityChanged(
            dataType: DataType<*, *>,
            availability: Availability,
        ) {
            if (availability is DataTypeAvailability &&
                availability != DataTypeAvailability.AVAILABLE) {
                Log.i(TAG, "availability.changed type=${dataType.name} status=${availability.name}")
            }
        }

        override fun onExerciseUpdateReceived(update: ExerciseUpdate) {
            val state = update.exerciseStateInfo.state
            Log.d(TAG, "exercise_update state=${state.name}")
            // Coleta heart rate dos samples atualizados nesse update.
            val latestSamples = update.latestMetrics.getData(DataType.HEART_RATE_BPM)
            if (latestSamples.isNotEmpty()) {
                val latest = latestSamples.maxByOrNull { it.timeDurationFromBoot } as? SampleDataPoint<Double>
                latest?.let {
                    val bpm = it.value.toInt()
                    if (bpm > 0) {
                        consecutiveStalePolls = 0
                        hasReceivedFreshSample = true
                        lastSampleAtMs = System.currentTimeMillis()
                        main.post { lastHeartRate = bpm }
                        WearableMessenger.pushBpmToPhone(bpm)
                    }
                }
            }
            // Steps total (cumulativo da session). Paralelo do
            // `pushStepsToPhone` iOS (L316).
            val stepsData = update.latestMetrics.getData(DataType.STEPS_TOTAL)
            stepsData?.let {
                val steps = it.total.toInt()
                if (steps >= 0) {
                    WearableMessenger.pushStepsToPhone(steps)
                }
            }
            // SpO2 — se exposto (Wear OS 5+ com sensor).
            val spo2Samples = runCatching {
                @Suppress("UNCHECKED_CAST")
                update.latestMetrics.getData(DataType.HEART_RATE_BPM /* placeholder */)
            }.getOrNull()
            // Note: Health Services não expõe SpO2 contínuo via ExerciseClient
            // por padrão (sample raro). Galaxy Watch 5+/6+ tem o sensor mas
            // exige passive monitoring. Versão atual: skip — adicionado em
            // iteração futura quando confirmado em device.

            if (state.isEnded && !intentionalStop) {
                Log.i(TAG, "exercise.unexpected_end auto_restart=true")
                main.post {
                    isActive = false
                    main.postDelayed({ start() }, 500L)
                }
            } else if (state.isEnded && intentionalStop) {
                main.post {
                    isActive = false
                    lastHeartRate = 0
                }
            }
        }

        override fun onLapSummaryReceived(lapSummary: ExerciseLapSummary) {
            // Wear OS auto-lap (se habilitado). No-op aqui — splits são
            // calculados pelo phone via GPS distance.
        }
    }

    /**
     * Inicia ExerciseSession running. Em qualquer falha (permission negada,
     * device sem capability), loga e segue silencioso — o phone faz fallback
     * pra MeasureClient ou Health Connect normal.
     */
    fun start() {
        val client = exerciseClient ?: return
        if (isActive) {
            Log.i(TAG, "start.idempotent skip=already_running")
            return
        }
        intentionalStop = false
        hasReceivedFreshSample = false
        consecutiveStalePolls = 0
        lastSampleAtMs = System.currentTimeMillis()

        scope.launch {
            try {
                client.setUpdateCallback(updateCallback)
                // Lista enxuta — Galaxy Watch e Pixel Watch suportam todos
                // esses tipos pra ExerciseType.RUNNING. Se algum não tiver,
                // startExerciseAsync falha silenciosa e o callback emite
                // onAvailabilityChanged=UNAVAILABLE pro tipo específico.
                val wanted = setOf(
                    DataType.HEART_RATE_BPM,
                    DataType.STEPS_TOTAL,
                    DataType.CALORIES_TOTAL,
                    DataType.DISTANCE_TOTAL,
                )

                val config = ExerciseConfig.builder(ExerciseType.RUNNING)
                    .setDataTypes(wanted)
                    .setIsAutoPauseAndResumeEnabled(false)
                    .setIsGpsEnabled(false) // GPS fica no phone
                    .build()
                client.startExerciseAsync(config).await()

                main.post {
                    isActive = true
                    startWorkoutForegroundService()
                    startStalePoller()
                }
                Log.i(TAG, "workout.started type=running")
            } catch (t: Throwable) {
                Log.e(TAG, "start.failed", t)
                main.post { isActive = false }
            }
        }
    }

    /**
     * Polling defensivo (paralelo do iOS L210): se não chega sample fresh
     * em N polls consecutivos, restart da session pra re-engajar o sensor.
     */
    private fun startStalePoller() {
        stalePollJob?.cancel()
        stalePollJob = scope.launch {
            while (isActive) {
                delay(3_000L)
                if (!isActive) break
                val ageMs = System.currentTimeMillis() - lastSampleAtMs
                if (ageMs > 10_000L) {
                    consecutiveStalePolls += 1
                    if (hasReceivedFreshSample &&
                        consecutiveStalePolls >= stalePollsThreshold) {
                        restartSessionDueToStale()
                        break // restart vai re-iniciar o poller
                    }
                } else {
                    consecutiveStalePolls = 0
                }
            }
        }
    }

    private fun restartSessionDueToStale() {
        val client = exerciseClient ?: return
        Log.i(TAG, "stale_restart attempts=$consecutiveStalePolls")
        WearableMessenger.pushDiag(
            kind = "bpm_stale_restart",
            extras = mapOf("staleCount" to consecutiveStalePolls),
        )
        consecutiveStalePolls = 0
        hasReceivedFreshSample = false
        intentionalStop = false
        scope.launch {
            try {
                client.endExerciseAsync().await()
            } catch (_: Throwable) { /* best-effort */ }
            main.post {
                isActive = false
                main.postDelayed({ start() }, 500L)
            }
        }
    }

    fun pause() {
        val client = exerciseClient ?: return
        if (!isActive) return
        scope.launch {
            try { client.pauseExerciseAsync().await() }
            catch (t: Throwable) { Log.w(TAG, "pause.failed", t) }
        }
    }

    fun resume() {
        val client = exerciseClient ?: return
        if (!isActive) return
        scope.launch {
            try { client.resumeExerciseAsync().await() }
            catch (t: Throwable) { Log.w(TAG, "resume.failed", t) }
        }
    }

    fun stop() {
        val client = exerciseClient ?: return
        if (!isActive) {
            Log.i(TAG, "stop.idempotent skip=no_session")
            return
        }
        intentionalStop = true
        stalePollJob?.cancel()
        stalePollJob = null
        scope.launch {
            try {
                client.endExerciseAsync().await()
                Log.i(TAG, "workout.ended")
            } catch (t: Throwable) {
                Log.w(TAG, "stop.end_failed", t)
            }
            try {
                client.clearUpdateCallbackAsync(updateCallback).await()
            } catch (_: Throwable) { /* best-effort */ }
            main.post {
                isActive = false
                lastHeartRate = 0
                stopWorkoutForegroundService()
            }
        }
    }

    private fun startWorkoutForegroundService() {
        val ctx = appContext ?: return
        try {
            val intent = Intent(ctx, WorkoutForegroundService::class.java)
            ContextCompat.startForegroundService(ctx, intent)
        } catch (t: Throwable) {
            Log.w(TAG, "fg_service.start_failed", t)
        }
    }

    private fun stopWorkoutForegroundService() {
        val ctx = appContext ?: return
        try {
            val intent = Intent(ctx, WorkoutForegroundService::class.java)
            ctx.stopService(intent)
        } catch (_: Throwable) { /* best-effort */ }
    }

    companion object {
        private const val TAG = "WorkoutController"

        @JvmStatic
        val shared: WorkoutController by lazy { WorkoutController() }
    }
}
