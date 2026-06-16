package com.s6lab.runnin.wear.models

import androidx.compose.ui.graphics.Color
import org.json.JSONArray
import org.json.JSONObject

/**
 * Split de 1 km (ou parcial no fim da corrida) — vem do phone no payload de
 * `run_state` (campo `splitsJson` string serializado). UI exibe na splitsPage.
 *
 * Paridade com `WatchSplit` do Apple Watch (Models/WatchRunState.swift L325).
 */
data class WatchSplit(
    val km: Int,              // 1-based (KM1, KM2, ...)
    val durationS: Int,       // segundos do km
    val pace: String,         // "5:42/km" formatado pelo phone
    val bpm: Int,             // média de BPM do km (0 = sem dado)
    val elev: Double,         // ganho de elevação do km em metros
) {
    val formattedDuration: String
        get() {
            val m = durationS / 60
            val s = durationS % 60
            return "%d:%02d".format(m, s)
        }

    companion object {
        fun fromJson(json: String?): List<WatchSplit> {
            if (json.isNullOrBlank()) return emptyList()
            return try {
                val arr = JSONArray(json)
                List(arr.length()) { i ->
                    val obj = arr.getJSONObject(i)
                    WatchSplit(
                        km = obj.optInt("km", 0),
                        durationS = obj.optInt("durationS", 0),
                        pace = obj.optString("pace", "—:—"),
                        bpm = obj.optInt("bpm", 0),
                        elev = obj.optDouble("elev", 0.0),
                    )
                }
            } catch (_: Throwable) {
                emptyList()
            }
        }
    }
}

/**
 * Sessão planejada do dia (vinda do phone quando idle). null = só
 * "Corrida Livre" disponível no PreRunScreen.
 *
 * Paridade com `TodaySession` do Apple Watch (L341).
 */
data class TodaySession(
    val type: String,
    val distanceKm: Double,
    val planSessionId: String?,
    val isExecuted: Boolean,
) {
    fun toJsonString(): String =
        JSONObject().apply {
            put("type", type)
            put("distanceKm", distanceKm)
            put("planSessionId", planSessionId ?: JSONObject.NULL)
            put("isExecuted", isExecuted)
        }.toString()

    companion object {
        fun fromJson(json: String?): TodaySession? {
            if (json.isNullOrBlank()) return null
            return try {
                val obj = JSONObject(json)
                TodaySession(
                    type = obj.optString("type", ""),
                    distanceKm = obj.optDouble("distanceKm", 0.0),
                    planSessionId = if (obj.isNull("planSessionId")) null
                        else obj.optString("planSessionId").ifEmpty { null },
                    isExecuted = obj.optBoolean("isExecuted", false),
                )
            } catch (_: Throwable) {
                null
            }
        }
    }
}

/**
 * Tipo selecionado no Passo 1/5 (PreRunScreen) que segue pra BriefingScreen.
 * Distância só preenchida quando vem de Sessão do Dia; null pra Free Run.
 *
 * Paridade com `SelectedRunType` do Apple Watch (L354).
 */
data class SelectedRunType(
    val type: String,
    val planSessionId: String?,
    val distanceKm: Double?,
) {
    val isFree: Boolean get() = planSessionId == null
}

enum class WatchStatus { idle, active, paused, completed }

/**
 * Estado de navegação LOCAL do Watch quando status==idle. Replica o fluxo do
 * prep_page do phone (Passo 1/5 → 5/5). Quando status sai de idle, é
 * irrelevante (ActiveRunScreen toma conta).
 *
 * Paridade com `LocalStep` do Apple Watch (L24).
 */
sealed class LocalStep {
    object SelectingType : LocalStep()
    data class Briefing(val selected: SelectedRunType) : LocalStep()
}

/**
 * Default colors. Cyan accent (skin "Artico"), orange secondary — matches
 * `WatchRunState.swift` L45/L49.
 */
object DefaultPalette {
    val accent = Color(red = 0f / 255f, green = 212f / 255f, blue = 255f / 255f)
    val secondary = Color(red = 255f / 255f, green = 107f / 255f, blue = 53f / 255f)
}

/**
 * Helper: converte "#RRGGBB" (com ou sem #) em Color. Retorna null pra
 * strings inválidas. Apenas 6 dígitos hex (sem alpha) — phone envia somente
 * RGB pra simplificar payload.
 *
 * Paridade com `WatchRunState.colorFromHex` (L313).
 */
fun colorFromHex(hex: String?): Color? {
    if (hex.isNullOrBlank()) return null
    var s = hex.trim()
    if (s.startsWith("#")) s = s.substring(1)
    if (s.length != 6) return null
    return try {
        val v = s.toLong(16)
        val r = ((v shr 16) and 0xFF) / 255f
        val g = ((v shr 8) and 0xFF) / 255f
        val b = (v and 0xFF) / 255f
        Color(red = r, green = g, blue = b)
    } catch (_: Throwable) {
        null
    }
}
