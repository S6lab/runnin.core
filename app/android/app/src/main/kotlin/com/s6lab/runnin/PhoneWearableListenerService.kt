package com.s6lab.runnin

import android.util.Log
import com.google.android.gms.wearable.DataEvent
import com.google.android.gms.wearable.DataEventBuffer
import com.google.android.gms.wearable.DataMapItem
import com.google.android.gms.wearable.MessageEvent
import com.google.android.gms.wearable.WearableListenerService

/**
 * Recebe MessageClient/DataClient pushes do app Wear OS (Galaxy Watch).
 * Roteia pra `WearableBridge` que emite no eventSink do plugin Flutter.
 *
 * Paralelo do `extension WorkoutRealtimePlugin: WCSessionDelegate` no iOS
 * (WorkoutRealtimePlugin.swift L541+).
 */
class PhoneWearableListenerService : WearableListenerService() {

    override fun onCreate() {
        super.onCreate()
        WearableBridge.attach(applicationContext)
    }

    override fun onMessageReceived(event: MessageEvent) {
        Log.i(TAG, "onMessageReceived path=${event.path} bytes=${event.data.size}")
        WearableBridge.routeMessageFromWatch(event.path, event.data)
    }

    override fun onDataChanged(events: DataEventBuffer) {
        for (event in events) {
            if (event.type != DataEvent.TYPE_CHANGED) continue
            val item = event.dataItem
            val path = item.uri.path ?: continue
            if (!path.startsWith("/runnin/")) continue
            try {
                val dataMap = DataMapItem.fromDataItem(item).dataMap
                WearableBridge.routeDataFromWatch(path, dataMap)
            } catch (t: Throwable) {
                Log.w(TAG, "onDataChanged.parse_failed path=$path", t)
            }
        }
    }

    companion object {
        private const val TAG = "PhoneWearListener"
    }
}
