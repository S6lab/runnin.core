package com.s6lab.runnin

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
    measureClient = HealthServices.getClient(binding.applicationContext).measureClient
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    unregisterIfNeeded()
    methodChannel?.setMethodCallHandler(null)
    methodChannel = null
    eventChannel?.setStreamHandler(null)
    eventChannel = null
    measureClient = null
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
      "start" -> startMeasure(result)
      "pause" -> pauseMeasure(result)
      "resume" -> resumeMeasure(result)
      "stop" -> stopMeasure(result)
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

  private fun emit(payload: Map<String, Any?>) {
    handler.post {
      eventSink?.success(payload)
    }
  }
}
