package com.s6lab.runnin

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.health.services.client.HealthServices
import androidx.health.services.client.HealthServicesClient
import androidx.health.services.client.MeasureCallback
import androidx.health.services.client.MeasureClient
import androidx.health.services.client.data.Availability
import androidx.health.services.client.data.DataPointContainer
import androidx.health.services.client.data.DataType
import androidx.health.services.client.data.DataTypeAvailability
import androidx.health.services.client.data.DeltaDataType
import androidx.health.services.client.data.SampleDataPoint
import com.google.common.util.concurrent.FutureCallback
import com.google.common.util.concurrent.Futures
import com.google.common.util.concurrent.MoreExecutors
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/**
 * Plugin nativo Android pra BPM realtime durante a Run ativa.
 *
 * Usa androidx.health.services.client.MeasureClient — quando há Wear OS
 * device pareado com capability HEART_RATE_BPM, samples chegam ao
 * MeasureCallback a ~1Hz. Sem Wear: callback nunca dispara (mas é silencioso,
 * pelo onAvailabilityChanged emit "warning" pra telemetria).
 *
 * Health Services API requer Android 11 (API 30). Runtime guard em
 * checkAvailability — minSdk do app é 26, fallback gracioso.
 *
 * Pause/Resume: API não tem pause nativo do MeasureCallback. Estratégia:
 * unregister no pause, register de novo no resume. O workout em si (sample
 * permanente no Health Connect) é responsabilidade do plugin `health` no
 * RunBloc._onComplete, não deste plugin.
 */
class WorkoutRealtimePlugin : FlutterPlugin, MethodCallHandler, EventChannel.StreamHandler {
  private var methodChannel: MethodChannel? = null
  private var eventChannel: EventChannel? = null
  private var eventSink: EventChannel.EventSink? = null

  private var measureClient: MeasureClient? = null
  private var registered = false
  private val handler = Handler(Looper.getMainLooper())
  private var appContext: Context? = null

  private val callback = object : MeasureCallback {
    // Em 1.1.0-rc02 a assinatura mudou de DataType<*, *> pra DeltaDataType<*, *>.
    override fun onAvailabilityChanged(dataType: DeltaDataType<*, *>, availability: Availability) {
      if (availability is DataTypeAvailability && availability != DataTypeAvailability.AVAILABLE) {
        emit(mapOf("type" to "warning", "code" to availability.name))
      }
    }

    override fun onDataReceived(data: DataPointContainer) {
      val samples = data.getData(DataType.HEART_RATE_BPM)
      if (samples.isEmpty()) return
      val latest = samples.maxByOrNull { it.timeDurationFromBoot } as? SampleDataPoint<Double>
        ?: return
      emit(mapOf(
        "type" to "bpm",
        "value" to latest.value.toInt(),
        "ts" to System.currentTimeMillis(),
      ))
    }
  }

  override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    methodChannel = MethodChannel(binding.binaryMessenger, "runnin/workout_realtime")
    methodChannel?.setMethodCallHandler(this)
    eventChannel = EventChannel(binding.binaryMessenger, "runnin/workout_realtime/events")
    eventChannel?.setStreamHandler(this)
    appContext = binding.applicationContext
    measureClient = HealthServices.getClient(binding.applicationContext).measureClient

    // Wearable Data Layer bridge — recebe MessageClient/DataClient pushes do
    // app Wear OS (Galaxy Watch). Listener service no Manifest acorda
    // automaticamente quando o Watch publica. Emite no MESMO eventSink (com
    // formato `bpm`/`watch_command`/`watch_status` que Flutter já parseia).
    WearableBridge.attach(binding.applicationContext)
    WearableBridge.eventEmitter = { payload ->
      handler.post { eventSink?.success(payload) }
    }
    WearableBridge.emitWatchStatus()
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    unregisterIfNeeded()
    methodChannel?.setMethodCallHandler(null)
    methodChannel = null
    eventChannel?.setStreamHandler(null)
    eventChannel = null
    measureClient = null
    WearableBridge.eventEmitter = null
  }

  override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
    eventSink = events
  }

  override fun onCancel(arguments: Any?) {
    eventSink = null
  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    when (call.method) {
      "checkAvailability" -> checkAvailability(result)
      "start" -> {
        startMeasure(result)
        // Manda o Watch ligar a ExerciseSession (paralelo do iOS
        // notifyWatch("startWorkout") em WorkoutRealtimePlugin.swift L359).
        WearableBridge.sendStartWorkout()
      }
      "pause" -> pauseMeasure(result)
      "resume" -> resumeMeasure(result)
      "stop" -> {
        stopMeasure(result)
        WearableBridge.sendStopWorkout()
      }
      "pushRunState" -> {
        @Suppress("UNCHECKED_CAST")
        val args = call.arguments as? Map<String, Any?> ?: emptyMap()
        WearableBridge.pushRunState(args)
        result.success(null)
      }
      "refreshWatchStatus" -> {
        WearableBridge.emitWatchStatus()
        result.success(null)
      }
      "getLastCachedBpm", "consumePendingWatchStart", "clearPendingWatchStart" -> {
        // Não há cache nativo no Android phone — sem suspend de Dart engine
        // como no iOS background. Retorna null pra Flutter usar fallback.
        result.success(null)
      }
      "openHealthConnectSettings" -> {
        // Deeplink pra tela de permissões do Health Connect do nosso app.
        // Tenta primeiro o intent novo (Android 14+ HC builtin), depois o
        // legacy (HC instalado via Play Store), e por fim Play Store no app
        // do HC pra user instalar/atualizar. Retorna true se conseguiu abrir
        // algum dos intents.
        result.success(openHealthConnectSettings())
      }
      else -> result.notImplemented()
    }
  }

  private fun checkAvailability(result: Result) {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
      result.success(mapOf("available" to false, "reason" to "android_below_11"))
      return
    }
    val client = measureClient
    if (client == null) {
      result.success(mapOf("available" to false, "reason" to "no_client"))
      return
    }
    val future = client.getCapabilitiesAsync()
    Futures.addCallback(future, object : FutureCallback<androidx.health.services.client.data.MeasureCapabilities> {
      override fun onSuccess(value: androidx.health.services.client.data.MeasureCapabilities?) {
        val supported = value?.supportedDataTypesMeasure?.contains(DataType.HEART_RATE_BPM) == true
        handler.post {
          if (supported) result.success(mapOf("available" to true))
          else result.success(mapOf("available" to false, "reason" to "no_capability"))
        }
      }
      override fun onFailure(t: Throwable) {
        handler.post {
          result.success(mapOf("available" to false, "reason" to (t.message ?: "capabilities_failed")))
        }
      }
    }, MoreExecutors.directExecutor())
  }

  private fun startMeasure(result: Result) {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
      emit(mapOf("type" to "error", "code" to "android_below_11"))
      result.success(null)
      return
    }
    val client = measureClient
    if (client == null) {
      emit(mapOf("type" to "error", "code" to "no_client"))
      result.success(null)
      return
    }
    if (registered) {
      result.success(null)
      return
    }
    try {
      client.registerMeasureCallback(DataType.HEART_RATE_BPM, callback)
      registered = true
      emit(mapOf("type" to "state", "value" to "active"))
    } catch (e: SecurityException) {
      emit(mapOf("type" to "error", "code" to "permission_denied", "message" to (e.message ?: "")))
    } catch (e: Exception) {
      emit(mapOf("type" to "error", "code" to "register_failed", "message" to (e.message ?: "")))
    }
    result.success(null)
  }

  private fun pauseMeasure(result: Result) {
    unregisterIfNeeded()
    emit(mapOf("type" to "state", "value" to "paused"))
    result.success(null)
  }

  private fun resumeMeasure(result: Result) {
    // Mesma lógica do start, mas sem state inicial → reabre fluxo.
    val client = measureClient
    if (client == null || registered) {
      result.success(null)
      return
    }
    try {
      client.registerMeasureCallback(DataType.HEART_RATE_BPM, callback)
      registered = true
      emit(mapOf("type" to "state", "value" to "active"))
    } catch (e: Exception) {
      emit(mapOf("type" to "error", "code" to "resume_failed", "message" to (e.message ?: "")))
    }
    result.success(null)
  }

  private fun stopMeasure(result: Result) {
    unregisterIfNeeded()
    emit(mapOf("type" to "state", "value" to "ended"))
    result.success(null)
  }

  private fun unregisterIfNeeded() {
    if (!registered) return
    val client = measureClient ?: return
    try {
      client.unregisterMeasureCallbackAsync(DataType.HEART_RATE_BPM, callback)
    } catch (_: Exception) {
      // best-effort
    }
    registered = false
  }

  /**
   * Abre a tela de gerenciamento de permissões do Health Connect com o app
   * Runnin pré-selecionado. Tenta 3 caminhos em sequência:
   *   1. `androidx.health.ACTION_HEALTH_CONNECT_SETTINGS` — Health Connect
   *      instalado como app standalone (Wear OS 3+, phones com HC store).
   *   2. `android.health.connect.action.HEALTH_HOME_SETTINGS` — HC builtin
   *      no Android 14+ (system-integrated).
   *   3. Play Store no listing do HC — fallback se HC nem está instalado.
   *
   * Retorna `true` no primeiro que conseguir lançar a Activity, `false` se
   * todos falharem. Caller (Flutter) usa o bool pra decidir se deve mostrar
   * snack "Erro ao abrir Health Connect".
   */
  private fun openHealthConnectSettings(): Boolean {
    val ctx = appContext ?: return false
    val intents = listOf(
      Intent("androidx.health.ACTION_HEALTH_CONNECT_SETTINGS"),
      Intent("android.health.connect.action.HEALTH_HOME_SETTINGS"),
      Intent(Intent.ACTION_VIEW,
        Uri.parse("market://details?id=com.google.android.apps.healthdata")),
    )
    for (i in intents) {
      i.flags = Intent.FLAG_ACTIVITY_NEW_TASK
      try {
        ctx.startActivity(i)
        return true
      } catch (_: ActivityNotFoundException) {
        // tenta próximo
      } catch (_: Exception) {
        // tenta próximo
      }
    }
    return false
  }

  private fun emit(payload: Map<String, Any?>) {
    handler.post {
      eventSink?.success(payload)
    }
  }
}
