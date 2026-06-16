package com.s6lab.runnin.wear.workout

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import com.s6lab.runnin.wear.MainActivity
import com.s6lab.runnin.wear.R

/**
 * Foreground service de tipo `health` — segura dispatch da app durante a
 * corrida com tela apagada. Paralelo do `WKExtendedRuntimeSession` do iOS
 * (WorkoutController.swift L60).
 *
 * Por que existe: ExerciseClient mantém sensor coletando, mas Wear OS pode
 * suspender CPU da app (timers + Compose recomposition) quando tela apaga.
 * FG service tipo health mantém o processo vivo enquanto a notificação
 * estiver lá. Apple Watch resolve com WKExtendedRuntimeSession; Wear resolve
 * com FG service.
 *
 * Bateria: ~10-15% extra/hora. Aceitável pra fitness app durante run.
 */
class WorkoutForegroundService : Service() {

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startForegroundCompat()
        return START_STICKY
    }

    private fun startForegroundCompat() {
        ensureNotificationChannel()
        val openIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pending = PendingIntent.getActivity(
            this, 0, openIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val notif = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(getString(R.string.workout_notification_title))
            .setContentText(getString(R.string.workout_notification_text))
            .setOngoing(true)
            .setContentIntent(pending)
            .build()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(NOTIF_ID, notif, ServiceInfo.FOREGROUND_SERVICE_TYPE_HEALTH)
        } else {
            startForeground(NOTIF_ID, notif)
        }
    }

    private fun ensureNotificationChannel() {
        val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        if (nm.getNotificationChannel(CHANNEL_ID) != null) return
        val ch = NotificationChannel(
            CHANNEL_ID,
            getString(R.string.workout_channel_name),
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = getString(R.string.workout_notification_text)
            setShowBadge(false)
        }
        nm.createNotificationChannel(ch)
    }

    companion object {
        private const val CHANNEL_ID = "runnin_workout"
        private const val NOTIF_ID = 4242
    }
}
