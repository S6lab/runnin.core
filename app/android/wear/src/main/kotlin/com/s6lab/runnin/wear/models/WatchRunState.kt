package com.s6lab.runnin.wear.models

import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableDoubleStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.graphics.Color
import com.s6lab.runnin.wear.bridge.PayloadKeys
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlin.math.max
import kotlin.math.min

/**
 * Mirror local do `RunState` do phone — atualizado via Wearable Data Layer
 * (DataClient) pelo `PhoneListenerService`. UI Compose observa via
 * `WatchRunState.shared` e re-renderiza conforme campos mudam.
 *
 * Singleton porque o ListenerService é único e a UI inteira vive em volta
 * dela. `updateFromMap()` é chamado em main thread.
 *
 * Paridade com `WatchRunState` do Apple Watch (Models/WatchRunState.swift).
 */
class WatchRunState private constructor() {

    // Estado observável (Compose-friendly)
    var status by mutableStateOf(WatchStatus.idle)
        private set
    var localStep by mutableStateOf<LocalStep>(LocalStep.SelectingType)
    /** True enquanto a sendMessage("startRun") está em vôo. */
    var starting by mutableStateOf(false)
    var elapsedS by mutableIntStateOf(0)
        private set
    var distanceM by mutableDoubleStateOf(0.0)
        private set
    var paceMinKm by mutableDoubleStateOf(0.0)
        private set
    var bpm by mutableIntStateOf(0)
        private set
    var caloriesKcal by mutableDoubleStateOf(0.0)
        private set
    var elevationM by mutableDoubleStateOf(0.0)
        private set
    var runType by mutableStateOf("")
        private set
    /** Skin primary cor (default cyan = "Artico"). */
    var accentColor by mutableStateOf(DefaultPalette.accent)
        private set
    /** Skin secondary cor (DIST + BPM). */
    var secondaryColor by mutableStateOf(DefaultPalette.secondary)
        private set
    var textScale by mutableDoubleStateOf(1.0)
        private set
    var splits by mutableStateOf<List<WatchSplit>>(emptyList())
        private set
    var todaySession by mutableStateOf<TodaySession?>(null)
    /** True quando passou >25s sem context do phone DURANTE run ativa. */
    var isOrphaned by mutableStateOf(false)

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private var orphanJob: Job? = null
    private var lastContextAtMs: Long = 0L
    private val orphanThresholdMs: Long = 25_000L

    private var appContext: Context? = null
    private val prefs: SharedPreferences?
        get() = appContext?.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    /**
     * Anexa contexto + restaura sessão do dia persistida. Idempotente — chama
     * uma vez no boot. Paridade com Apple Watch L116 (init carrega
     * `loadPersistedTodaySession`).
     */
    fun attach(ctx: Context) {
        if (appContext != null) return
        appContext = ctx.applicationContext
        loadPersistedTodaySession()
    }

    /**
     * Inicia o monitor de orfão. Idempotente. Quando status volta pra idle,
     * reseta isOrphaned. Paralelo do `startOrphanMonitor` do Apple Watch L128.
     */
    fun startOrphanMonitor() {
        orphanJob?.cancel()
        orphanJob = scope.launch {
            while (true) {
                delay(5_000L)
                if (status != WatchStatus.active && status != WatchStatus.paused) {
                    if (isOrphaned) isOrphaned = false
                    continue
                }
                val gap = System.currentTimeMillis() - lastContextAtMs
                val nowOrphaned = gap > orphanThresholdMs
                if (nowOrphaned != isOrphaned) {
                    isOrphaned = nowOrphaned
                }
            }
        }
    }

    /**
     * Limpa o estado da corrida e volta pro TypeSelector. Chamado pelo botão
     * "Encerrar e voltar" do overlay de orfão e pelo FINALIZAR normal.
     * Para a ExerciseSession local pra não vazar bateria.
     *
     * Paralelo do `resetToIdle` do Apple Watch L152.
     */
    fun resetToIdle(onStopWorkout: () -> Unit) {
        onStopWorkout()
        status = WatchStatus.idle
        starting = false
        elapsedS = 0
        distanceM = 0.0
        paceMinKm = 0.0
        bpm = 0
        caloriesKcal = 0.0
        elevationM = 0.0
        splits = emptyList()
        isOrphaned = false
        localStep = LocalStep.SelectingType
    }

    /**
     * Aplica payload do DataClient (run_state ou today_session) na state.
     * Paralelo do `update(from:)` do Apple Watch L169.
     *
     * Callbacks pra ações dependentes de WorkoutController não são chamados
     * aqui — a UI gerencia (vê onChange em ContentView equivalente).
     */
    fun updateFromMap(context: Map<String, Any?>) {
        // Qualquer payload re-arma o watchdog. Mesmo mensagens não-state
        // (skin update, today_session) provam que o canal tá vivo.
        lastContextAtMs = System.currentTimeMillis()
        if (isOrphaned) isOrphaned = false

        val typeStr = context[PayloadKeys.TYPE] as? String ?: return

        // _attachedTodaySession (re-injeção): aplicada em qualquer tipo de
        // payload. Phone serializa como JSON string em TODAY_SESSION_JSON
        // (Wear Data Layer não aceita Map<String,Any> nested).
        (context[PayloadKeys.TODAY_SESSION_JSON] as? String)?.let { json ->
            todaySession = TodaySession.fromJson(json)
            persistTodaySession(todaySession)
        }

        when (typeStr) {
            "run_state" -> {
                val newStatusStr = context[PayloadKeys.STATUS] as? String
                val newStatus = newStatusStr?.let {
                    runCatching { WatchStatus.valueOf(it) }.getOrNull()
                }
                if (newStatus != null) {
                    if (newStatus == WatchStatus.active && status != WatchStatus.active) {
                        starting = false
                    }
                    if (newStatus == WatchStatus.idle && status != WatchStatus.idle) {
                        localStep = LocalStep.SelectingType
                    }
                    status = newStatus
                }
                (context[PayloadKeys.ELAPSED_S] as? Number)?.let { elapsedS = it.toInt() }
                (context[PayloadKeys.DISTANCE_M] as? Number)?.let { distanceM = it.toDouble() }
                (context[PayloadKeys.PACE_MIN_KM] as? Number)?.let { paceMinKm = it.toDouble() }
                (context[PayloadKeys.BPM] as? Number)?.let { bpm = it.toInt() }
                (context[PayloadKeys.CALORIES_KCAL] as? Number)?.let { caloriesKcal = it.toDouble() }
                (context[PayloadKeys.ELEVATION_M] as? Number)?.let { elevationM = it.toDouble() }
                (context[PayloadKeys.RUN_TYPE] as? String)?.let { runType = it }
                (context[PayloadKeys.ACCENT_COLOR] as? String)?.let { hex ->
                    colorFromHex(hex)?.let { accentColor = it }
                }
                (context[PayloadKeys.SECONDARY_COLOR] as? String)?.let { hex ->
                    colorFromHex(hex)?.let { secondaryColor = it }
                }
                (context[PayloadKeys.TEXT_SCALE] as? Number)?.let { n ->
                    textScale = max(0.8, min(1.5, n.toDouble()))
                }
                (context[PayloadKeys.SPLITS_JSON] as? String)?.let { json ->
                    splits = WatchSplit.fromJson(json)
                }
            }
            "today_session" -> {
                val sessionJson = context[PayloadKeys.TODAY_SESSION_JSON] as? String
                if (!sessionJson.isNullOrBlank() && sessionJson != "null") {
                    todaySession = TodaySession.fromJson(sessionJson)
                    persistTodaySession(todaySession)
                } else if (context[PayloadKeys.REST_DAY] == true) {
                    // SÓ limpa quando phone confirma rest day. Paridade com
                    // fix TF 61 do iOS Watch (L264).
                    todaySession = null
                    persistTodaySession(null)
                }
                // Se vier session: null SEM rest_day flag → IGNORA.
            }
        }
    }

    // MARK: Formatters

    val formattedElapsed: String
        get() {
            val s = max(0, elapsedS)
            val h = s / 3600
            val m = (s % 3600) / 60
            val sec = s % 60
            return if (h > 0) "%d:%02d:%02d".format(h, m, sec)
                else "%02d:%02d".format(m, sec)
        }

    val formattedDistance: String
        get() = "%.2f".format(distanceM / 1000.0)

    val formattedPace: String
        get() {
            if (paceMinKm <= 0.0 || !paceMinKm.isFinite() || paceMinKm >= 30.0) return "—:—"
            val totalSec = (paceMinKm * 60).toInt()
            val m = totalSec / 60
            val s = totalSec % 60
            return "%d:%02d".format(m, s)
        }

    // MARK: Persistence (SharedPreferences equivalente ao UserDefaults iOS)

    private fun persistTodaySession(s: TodaySession?) {
        val p = prefs ?: return
        p.edit().apply {
            if (s == null) {
                remove(KEY_TODAY_SESSION)
                remove(KEY_TODAY_SESSION_AT)
            } else {
                putString(KEY_TODAY_SESSION, s.toJsonString())
                putLong(KEY_TODAY_SESSION_AT, System.currentTimeMillis())
            }
            apply()
        }
    }

    private fun loadPersistedTodaySession() {
        val p = prefs ?: return
        val ts = p.getLong(KEY_TODAY_SESSION_AT, 0L)
        if (ts > 0 && System.currentTimeMillis() - ts > TODAY_SESSION_TTL_MS) {
            p.edit()
                .remove(KEY_TODAY_SESSION)
                .remove(KEY_TODAY_SESSION_AT)
                .apply()
            return
        }
        val json = p.getString(KEY_TODAY_SESSION, null) ?: return
        TodaySession.fromJson(json)?.let { todaySession = it }
    }

    companion object {
        @JvmStatic
        val shared: WatchRunState by lazy { WatchRunState() }

        private const val TAG = "WatchRunState"
        private const val PREFS_NAME = "runnin_wear_state"
        private const val KEY_TODAY_SESSION = "today_session_v1"
        private const val KEY_TODAY_SESSION_AT = "today_session_v1_at"
        private const val TODAY_SESSION_TTL_MS = 24L * 60L * 60L * 1000L
    }
}
