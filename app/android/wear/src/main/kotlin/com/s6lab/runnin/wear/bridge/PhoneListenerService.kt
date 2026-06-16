package com.s6lab.runnin.wear.bridge

import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.core.content.ContextCompat
import com.google.android.gms.wearable.DataEvent
import com.google.android.gms.wearable.DataEventBuffer
import com.google.android.gms.wearable.DataMapItem
import com.google.android.gms.wearable.MessageEvent
import com.google.android.gms.wearable.WearableListenerService
import com.s6lab.runnin.wear.models.WatchRunState
import com.s6lab.runnin.wear.workout.WorkoutController
import com.s6lab.runnin.wear.workout.WorkoutForegroundService

/**
 * Recebe MessageClient / DataClient pushes do phone (start/stop workout +
 * state context). Roteia pra `WorkoutController` e `WatchRunState`.
 *
 * Paralelo do `SessionDelegate` do iOS (Apple Watch SessionDelegate.swift):
 *  - onMessageReceived  →  session(_:didReceiveMessage:replyHandler:) (L73)
 *  - onDataChanged      →  session(_:didReceiveApplicationContext:) (L60)
 *
 * Roda em background mesmo com app Watch não-foreground — Wearable Data
 * Layer acorda este service automaticamente.
 */
class PhoneListenerService : WearableListenerService() {

    private val main = Handler(Looper.getMainLooper())

    override fun onCreate() {
        super.onCreate()
        // Anexa state + messenger ao contexto da app.
        WatchRunState.shared.attach(applicationContext)
        WearableMessenger.attach(applicationContext)
        WorkoutController.shared.attach(applicationContext)
    }

    override fun onMessageReceived(event: MessageEvent) {
        Log.i(TAG, "onMessageReceived path=${event.path} bytes=${event.data.size}")
        when (event.path) {
            WearPaths.START_WORKOUT -> main.post {
                if (!WorkoutController.shared.isActive) {
                    WorkoutController.shared.start()
                }
            }
            WearPaths.STOP_WORKOUT -> main.post {
                WorkoutController.shared.stop()
            }
            WearPaths.PING -> {
                // Phone health check — sem reply explícito em MessageClient
                // (não há replyHandler como WCSession), telemetry-only.
                WearableMessenger.pushDiag(kind = "pong")
            }
            else -> { /* unknown */ }
        }
    }

    override fun onDataChanged(events: DataEventBuffer) {
        for (event in events) {
            if (event.type != DataEvent.TYPE_CHANGED) continue
            val item = event.dataItem
            val path = item.uri.path ?: continue
            if (!path.startsWith("/runnin/")) continue
            try {
                val dataMap = DataMapItem.fromDataItem(item).dataMap
                val map = mutableMapOf<String, Any?>()
                for (key in dataMap.keySet()) {
                    map[key] = when {
                        dataMap.containsKey(key) -> {
                            // DataMap não expõe um getter unificado; tentar todos.
                            dataMap.getString(key)
                                ?: runCatching { dataMap.getInt(key) }.getOrNull()
                                ?: runCatching { dataMap.getLong(key) }.getOrNull()
                                ?: runCatching { dataMap.getDouble(key) }.getOrNull()
                                ?: runCatching { dataMap.getBoolean(key) }.getOrNull()
                        }
                        else -> null
                    }
                }
                Log.i(TAG, "onDataChanged path=$path keys=${map.keys.joinToString()}")
                main.post {
                    WatchRunState.shared.updateFromMap(map)
                    // Belt-and-suspenders TF 69 equivalente: quando phone
                    // empurra status=active via DataClient (caminho
                    // independente de message), garantimos que ExerciseSession
                    // está rodando.
                    if (map[PayloadKeys.STATUS] == "active" &&
                        !WorkoutController.shared.isActive) {
                        WorkoutController.shared.start()
                    }
                }
            } catch (t: Throwable) {
                Log.w(TAG, "onDataChanged.parse_failed path=$path", t)
            }
        }
    }

    companion object {
        private const val TAG = "PhoneListenerService"
    }
}
