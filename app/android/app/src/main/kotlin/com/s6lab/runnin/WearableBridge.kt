package com.s6lab.runnin

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.google.android.gms.tasks.Tasks
import com.google.android.gms.wearable.DataMap
import com.google.android.gms.wearable.Node
import com.google.android.gms.wearable.PutDataMapRequest
import com.google.android.gms.wearable.Wearable
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import org.json.JSONObject

/**
 * Lado phone Android do canal Wearable Data Layer com o app Wear OS
 * (Galaxy Watch). Paralelo do `WorkoutRealtimePlugin.swift` iOS (WCSession).
 *
 * Phone -> Watch:
 *  - `sendStartWorkout()` / `sendStopWorkout()`: MessageClient sendMessage
 *    pro Watch pra ligar/desligar a HKWorkoutSession equivalente
 *    (ExerciseClient). Paralelo do `notifyWatch(action: "startWorkout")`
 *    iOS L359.
 *  - `pushRunState(map)`: DataClient putDataMapRequest com o snapshot do
 *    RunState. Paralelo do `updateApplicationContext` iOS.
 *
 * Watch -> Phone:
 *  - `PhoneWearableListenerService` recebe MessageReceived / DataChanged e
 *    chama `routeFromWatch()` aqui, que emite no eventSink do plugin via
 *    o callback `eventEmitter`.
 *
 * Singleton porque o ListenerService roda fora do Flutter engine e precisa
 * achar o emitter do plugin de qualquer lugar do processo.
 */
object WearableBridge {

    private const val TAG = "WearableBridge"

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val main = Handler(Looper.getMainLooper())
    private var appContext: Context? = null

    /**
     * Callback que o `WorkoutRealtimePlugin` seta no onAttachedToEngine.
     * Recebe events no MESMO formato que o eventSink do Flutter espera
     * (ver `workout_realtime_service.dart` L494 _onEvent switch). Setado
     * como null no onDetached.
     */
    @Volatile var eventEmitter: ((Map<String, Any?>) -> Unit)? = null

    fun attach(ctx: Context) {
        if (appContext != null) return
        appContext = ctx.applicationContext
    }

    private val messageClient by lazy { Wearable.getMessageClient(appContext!!) }
    private val dataClient by lazy { Wearable.getDataClient(appContext!!) }
    private val nodeClient by lazy { Wearable.getNodeClient(appContext!!) }
    private val capabilityClient by lazy { Wearable.getCapabilityClient(appContext!!) }

    // MARK: - Phone -> Watch

    fun sendStartWorkout() = sendActionToWatch(WearPaths.START_WORKOUT)
    fun sendStopWorkout() = sendActionToWatch(WearPaths.STOP_WORKOUT)
    fun sendPing() = sendActionToWatch(WearPaths.PING)

    private fun sendActionToWatch(path: String) {
        val ctx = appContext ?: return
        scope.launch {
            try {
                val nodes: List<Node> = Tasks.await(nodeClient.connectedNodes)
                if (nodes.isEmpty()) {
                    Log.i(TAG, "send_action.no_nodes path=$path")
                    return@launch
                }
                var anyOk = false
                for (node in nodes) {
                    try {
                        Tasks.await(messageClient.sendMessage(node.id, path, ByteArray(0)))
                        anyOk = true
                    } catch (t: Throwable) {
                        Log.w(TAG, "send_action.fail node=${node.displayName} path=$path", t)
                    }
                }
                if (!anyOk) {
                    // Fallback: posta DataItem na queue do peer (entrega quando
                    // Watch acordar). Paralelo do `transferUserInfo` iOS L162.
                    val req = PutDataMapRequest.create("$path/queued")
                    req.dataMap.putLong("ts", System.currentTimeMillis())
                    req.setUrgent()
                    Tasks.await(dataClient.putDataItem(req.asPutDataRequest()))
                }
            } catch (t: Throwable) {
                Log.w(TAG, "send_action.exception path=$path", t)
            }
        }
    }

    /**
     * Empurra snapshot do RunState pro Watch via DataClient putDataMapRequest.
     * Idempotente — chamado pelo RunBloc a cada tick 1Hz durante active/paused.
     *
     * Tipos primitivos viram entradas direto no DataMap. Map<String,Any>
     * aninhado (ex: splits, _attachedTodaySession) é serializado como JSON
     * string — Wear Data Layer não aceita Map nested.
     *
     * Paralelo do `pushRunState` iOS (WorkoutRealtimePlugin.swift L186).
     */
    fun pushRunState(payload: Map<String, Any?>) {
        val ctx = appContext ?: return
        scope.launch {
            try {
                val typeStr = payload["type"] as? String ?: "run_state"
                val path = when (typeStr) {
                    "today_session" -> WearPaths.TODAY_SESSION
                    else -> WearPaths.RUN_STATE
                }
                val req = PutDataMapRequest.create(path)
                buildDataMap(req.dataMap, payload)
                // Anti-dedup: timestamp único força DataClient a sempre considerar
                // mudança (paralelo do que iOS faz com cada applicationContext).
                req.dataMap.putLong("__ts", System.currentTimeMillis())
                req.setUrgent()
                Tasks.await(dataClient.putDataItem(req.asPutDataRequest()))
            } catch (t: Throwable) {
                Log.w(TAG, "pushRunState.fail", t)
            }
        }
    }

    private fun buildDataMap(map: DataMap, payload: Map<String, Any?>) {
        for ((k, v) in payload) {
            when (v) {
                null -> { /* skip */ }
                is Int -> map.putInt(k, v)
                is Long -> map.putLong(k, v)
                is Float -> map.putFloat(k, v)
                is Double -> map.putDouble(k, v)
                is Boolean -> map.putBoolean(k, v)
                is String -> map.putString(k, v)
                is Map<*, *> -> {
                    @Suppress("UNCHECKED_CAST")
                    val nested = v as? Map<String, Any?>
                    if (nested != null) {
                        // Serializa como JSON string. Keys especiais (splits,
                        // session, _attachedTodaySession) viram <key>Json.
                        val json = JSONObject(nested.filterValues { it != null }).toString()
                        map.putString("${k}Json", json)
                    }
                }
                is List<*> -> {
                    // Lista de Map (ex: splits) — serializa como JSON array string
                    val arr = org.json.JSONArray()
                    for (item in v) {
                        if (item is Map<*, *>) {
                            @Suppress("UNCHECKED_CAST")
                            arr.put(JSONObject((item as Map<String, Any?>).filterValues { it != null }))
                        } else if (item != null) {
                            arr.put(item)
                        }
                    }
                    map.putString("${k}Json", arr.toString())
                }
                else -> map.putString(k, v.toString())
            }
        }
    }

    // MARK: - Watch -> Phone

    /**
     * Chamado pelo `PhoneWearableListenerService` quando o Watch manda
     * MessageClient. Roteia pra emitter no formato que o Flutter espera
     * (workout_realtime_service.dart _onEvent L494).
     */
    fun routeMessageFromWatch(path: String, data: ByteArray) {
        val emitter = eventEmitter ?: return
        val payload = parsePayload(data)
        val action = when (path) {
            WearPaths.START_RUN -> "startRun"
            WearPaths.PAUSE_RUN -> "pauseRun"
            WearPaths.RESUME_RUN -> "resumeRun"
            WearPaths.COMPLETE_RUN -> "completeRun"
            WearPaths.ACKNOWLEDGE_COMPLETE -> "acknowledgeComplete"
            else -> return
        }
        main.post {
            emitter(mapOf(
                "type" to "watch_command",
                "action" to action,
                "payload" to payload,
            ))
        }
    }

    /**
     * Chamado quando o Watch publica telemetria via DataClient (BPM, steps,
     * spo2, diag). Roteia pro eventSink no formato canônico.
     */
    fun routeDataFromWatch(path: String, dataMap: DataMap) {
        val emitter = eventEmitter ?: return
        main.post {
            when (path) {
                WearPaths.BPM_UPDATE -> {
                    val bpm = if (dataMap.containsKey("bpm")) dataMap.getInt("bpm") else 0
                    if (bpm > 0) {
                        emitter(mapOf(
                            "type" to "bpm",
                            "value" to bpm,
                            "ts" to (if (dataMap.containsKey("ts")) dataMap.getLong("ts") else 0L),
                            "source" to "watch",
                        ))
                    }
                }
                WearPaths.SPO2_UPDATE -> {
                    val pct = if (dataMap.containsKey("spo2")) dataMap.getInt("spo2") else 0
                    if (pct in 50..100) {
                        emitter(mapOf(
                            "type" to "spo2",
                            "value" to pct,
                            "ts" to (if (dataMap.containsKey("ts")) dataMap.getLong("ts") else 0L),
                        ))
                    }
                }
                WearPaths.STEPS_UPDATE -> {
                    val steps = if (dataMap.containsKey("steps")) dataMap.getInt("steps") else -1
                    if (steps >= 0) {
                        emitter(mapOf(
                            "type" to "steps",
                            "value" to steps,
                            "ts" to (if (dataMap.containsKey("ts")) dataMap.getLong("ts") else 0L),
                        ))
                    }
                }
                WearPaths.WATCH_DIAG -> {
                    // Diagnostic — não emite eventos críticos, só log
                    Log.i(TAG, "watch_diag path=$path keys=${dataMap.keySet()}")
                }
            }
        }
    }

    private fun parsePayload(data: ByteArray): Map<String, Any?> {
        if (data.isEmpty()) return emptyMap()
        return try {
            val obj = JSONObject(data.toString(Charsets.UTF_8))
            val out = mutableMapOf<String, Any?>()
            for (key in obj.keys()) {
                out[key] = obj.get(key)
            }
            out
        } catch (_: Throwable) {
            emptyMap()
        }
    }

    /**
     * Verifica se o app Wear OS está instalado e o Watch está reachable.
     * Resultado emitido no eventSink como `watch_status` — paralelo do iOS
     * L181.
     */
    fun emitWatchStatus() {
        val ctx = appContext ?: return
        val emitter = eventEmitter ?: return
        scope.launch {
            val paired = try {
                Tasks.await(nodeClient.connectedNodes).isNotEmpty()
            } catch (_: Throwable) { false }
            val appInstalled = try {
                Tasks.await(capabilityClient.getCapability("runnin_wear_app",
                    com.google.android.gms.wearable.CapabilityClient.FILTER_REACHABLE))
                    .nodes.isNotEmpty()
            } catch (_: Throwable) { paired }
            val reachable = paired
            main.post {
                emitter(mapOf(
                    "type" to "watch_status",
                    "paired" to paired,
                    "appInstalled" to appInstalled,
                    "reachable" to reachable,
                ))
            }
        }
    }
}
