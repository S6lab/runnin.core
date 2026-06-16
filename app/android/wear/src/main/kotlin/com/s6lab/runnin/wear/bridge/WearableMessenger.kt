package com.s6lab.runnin.wear.bridge

import android.content.Context
import android.util.Log
import com.google.android.gms.tasks.Tasks
import com.google.android.gms.wearable.CapabilityClient
import com.google.android.gms.wearable.PutDataMapRequest
import com.google.android.gms.wearable.Wearable
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import java.util.UUID

/**
 * Envia comandos e telemetria do Watch pro Phone via Wearable Data Layer.
 * Singleton — equivalente Android do `SessionDelegate.shared.push*` do iOS
 * (Apple Watch SessionDelegate.swift L96-L194).
 *
 * Estratégia de canais:
 *  - `messageClient.sendMessage(path, payload)`: actions de baixa latência
 *    (pause/resume/complete). Falha se peer não reachable; faz fallback
 *    pra DataClient com PutDataMapRequest (entrega-quando-acordar, FIFO).
 *  - `dataClient.putDataItem(PutDataMapRequest)`: telemetria contínua de
 *    1Hz (BPM, steps) — sync replicado com dedup automático (último valor
 *    por path). Paralelo do `updateApplicationContext` iOS.
 *
 * Throttle equivalente ao iOS:
 *  - BPM: 1Hz (push a cada 1.0s)
 *  - Steps: 5s
 *  - SpO2: 15s + dedup mesmo valor
 */
object WearableMessenger {

    private const val TAG = "WearableMessenger"

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private var appContext: Context? = null

    private val messageClient by lazy { Wearable.getMessageClient(appContext!!) }
    private val dataClient by lazy { Wearable.getDataClient(appContext!!) }
    private val capabilityClient by lazy { Wearable.getCapabilityClient(appContext!!) }

    fun attach(ctx: Context) {
        if (appContext != null) return
        appContext = ctx.applicationContext
    }

    // MARK: - Watch -> Phone messages (actions)

    /**
     * Manda action message pro phone via MessageClient. Tenta todos os nodes
     * conectados (na prática só o phone pareado). Fallback: PutDataMapRequest
     * em path /runnin/cmd/<requestId> — phone PhoneListenerService trata
     * ambos os caminhos.
     *
     * Paralelo do `sendCommand` do ActiveRunScreen.swift L332 e do
     * `handleStart` do BriefingScreen.swift L122.
     */
    fun sendCommand(action: String, extras: Map<String, Any?> = emptyMap()) {
        val ctx = appContext ?: return
        scope.launch {
            val path = when (action) {
                "startRun" -> WearPaths.START_RUN
                "pauseRun" -> WearPaths.PAUSE_RUN
                "resumeRun" -> WearPaths.RESUME_RUN
                "completeRun" -> WearPaths.COMPLETE_RUN
                "acknowledgeComplete" -> WearPaths.ACKNOWLEDGE_COMPLETE
                else -> return@launch
            }
            val requestId = UUID.randomUUID().toString()
            val payload = buildPayloadBytes(extras + mapOf(
                PayloadKeys.REQUEST_ID to requestId,
                PayloadKeys.TS to System.currentTimeMillis(),
            ))
            sendMessageToAllNodes(path, payload, fallbackPath = path + "/queued")
        }
    }

    // MARK: - Watch -> Phone telemetry

    @Volatile private var lastBpmPushAt: Long = 0
    private const val BPM_PUSH_INTERVAL_MS: Long = 1000

    /**
     * Push BPM Watch->Phone via DataClient (DataItem dedup automático).
     * 1Hz throttle. Paralelo do `pushBpmToPhone` iOS (SessionDelegate.swift L108).
     */
    fun pushBpmToPhone(bpm: Int) {
        if (bpm <= 0) return
        val now = System.currentTimeMillis()
        if (now - lastBpmPushAt < BPM_PUSH_INTERVAL_MS) return
        lastBpmPushAt = now
        putDataItem(WearPaths.BPM_UPDATE) { map ->
            map.putString(PayloadKeys.TYPE, "bpm_update")
            map.putInt(PayloadKeys.BPM, bpm)
            map.putLong(PayloadKeys.TS, now)
        }
    }

    @Volatile private var lastSpo2: Int = 0
    @Volatile private var lastSpo2PushAt: Long = 0
    private const val SPO2_PUSH_INTERVAL_MS: Long = 15_000

    /** Paralelo do `pushSpo2ToPhone` iOS (L136). */
    fun pushSpo2ToPhone(pct: Int) {
        val now = System.currentTimeMillis()
        if (pct == lastSpo2 && now - lastSpo2PushAt < SPO2_PUSH_INTERVAL_MS) return
        lastSpo2 = pct
        lastSpo2PushAt = now
        putDataItem(WearPaths.SPO2_UPDATE) { map ->
            map.putString(PayloadKeys.TYPE, "spo2_update")
            map.putInt(PayloadKeys.SPO2, pct)
            map.putLong(PayloadKeys.TS, now)
        }
    }

    @Volatile private var lastStepsPushAt: Long = 0
    private const val STEPS_PUSH_INTERVAL_MS: Long = 5_000

    /** Paralelo do `pushStepsToPhone` iOS (L161). */
    fun pushStepsToPhone(steps: Int) {
        if (steps < 0) return
        val now = System.currentTimeMillis()
        if (now - lastStepsPushAt < STEPS_PUSH_INTERVAL_MS) return
        lastStepsPushAt = now
        putDataItem(WearPaths.STEPS_UPDATE) { map ->
            map.putString(PayloadKeys.TYPE, "steps_update")
            map.putInt(PayloadKeys.STEPS, steps)
            map.putLong(PayloadKeys.TS, now)
        }
    }

    /** Paralelo do `pushDiagToPhone` iOS (L184). */
    fun pushDiag(kind: String, extras: Map<String, Any?> = emptyMap()) {
        putDataItem(WearPaths.WATCH_DIAG) { map ->
            map.putString(PayloadKeys.TYPE, "watch_diag")
            map.putString(PayloadKeys.KIND, kind)
            map.putLong(PayloadKeys.TS, System.currentTimeMillis())
            extras.forEach { (k, v) ->
                when (v) {
                    is Int -> map.putInt(k, v)
                    is Long -> map.putLong(k, v)
                    is Double -> map.putDouble(k, v)
                    is Float -> map.putFloat(k, v)
                    is Boolean -> map.putBoolean(k, v)
                    is String -> map.putString(k, v)
                    null -> { /* skip */ }
                    else -> map.putString(k, v.toString())
                }
            }
        }
    }

    // MARK: - Private helpers

    private fun sendMessageToAllNodes(
        path: String,
        payload: ByteArray,
        fallbackPath: String,
    ) {
        val ctx = appContext ?: return
        scope.launch {
            try {
                val nodes = Tasks.await(Wearable.getNodeClient(ctx).connectedNodes)
                if (nodes.isEmpty()) {
                    // Sem nodes reachable: cai pra DataClient (entrega-quando-
                    // acordar, FIFO).
                    putDataItemRaw(fallbackPath, payload)
                    return@launch
                }
                var anyOk = false
                for (node in nodes) {
                    try {
                        Tasks.await(messageClient.sendMessage(node.id, path, payload))
                        anyOk = true
                    } catch (t: Throwable) {
                        Log.w(TAG, "sendMessage.fail node=${node.displayName} path=$path", t)
                    }
                }
                if (!anyOk) {
                    putDataItemRaw(fallbackPath, payload)
                }
            } catch (t: Throwable) {
                Log.w(TAG, "sendMessage.exception path=$path", t)
                putDataItemRaw(fallbackPath, payload)
            }
        }
    }

    private fun putDataItem(path: String, build: (com.google.android.gms.wearable.DataMap) -> Unit) {
        val ctx = appContext ?: return
        scope.launch {
            try {
                val req = PutDataMapRequest.create(path)
                build(req.dataMap)
                req.setUrgent()
                val asPut = req.asPutDataRequest()
                Tasks.await(dataClient.putDataItem(asPut))
            } catch (t: Throwable) {
                Log.w(TAG, "putDataItem.fail path=$path", t)
            }
        }
    }

    private fun putDataItemRaw(path: String, payload: ByteArray) {
        val ctx = appContext ?: return
        scope.launch {
            try {
                val req = PutDataMapRequest.create(path)
                req.dataMap.putByteArray("payload", payload)
                req.dataMap.putLong(PayloadKeys.TS, System.currentTimeMillis())
                req.setUrgent()
                Tasks.await(dataClient.putDataItem(req.asPutDataRequest()))
            } catch (t: Throwable) {
                Log.w(TAG, "putDataItemRaw.fail path=$path", t)
            }
        }
    }

    /**
     * Serializa Map de extras pra ByteArray (UTF-8 JSON). Phone side parseia
     * mesmo formato. Mantém payload pequeno (~100 bytes) — Wear Data Layer
     * limite é 100KB por message.
     */
    private fun buildPayloadBytes(extras: Map<String, Any?>): ByteArray {
        val obj = org.json.JSONObject()
        for ((k, v) in extras) {
            if (v == null) continue
            obj.put(k, v)
        }
        return obj.toString().toByteArray(Charsets.UTF_8)
    }
}
