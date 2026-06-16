package com.s6lab.runnin.wear.bridge

/**
 * Constantes do protocolo Wearable Data Layer compartilhadas com o phone.
 *
 * Equivalente Android dos "actions" do WCSession iOS:
 *  - Phone -> Watch:  startWorkout / stopWorkout / state context
 *  - Watch -> Phone:  startRun / pauseRun / resumeRun / completeRun /
 *                     acknowledgeComplete / bpm_update / spo2_update /
 *                     steps_update / watch_diag
 *
 * Wearable Data Layer tem 2 canais:
 *  - MessageClient:    fire-and-forget; baixo overhead; falha se peer não
 *                      reachable. Paralelo de WCSession.sendMessage().
 *  - DataClient:       sync replicado com dedup automático (último valor por
 *                      key). Paralelo de updateApplicationContext().
 *
 * Convenção: paths começam com `/runnin/` pra evitar conflito com outras
 * apps Wearable no mesmo device.
 */
object WearPaths {
    // Phone -> Watch (action messages, equivalentes do sendMessage iOS)
    const val START_WORKOUT = "/runnin/start_workout"
    const val STOP_WORKOUT = "/runnin/stop_workout"
    const val PING = "/runnin/ping"

    // Phone -> Watch (state snapshots via DataClient, equivalente do
    // updateApplicationContext do iOS). PutDataMapRequest path.
    const val RUN_STATE = "/runnin/run_state"
    const val TODAY_SESSION = "/runnin/today_session"

    // Watch -> Phone (commands via MessageClient)
    const val START_RUN = "/runnin/start_run"
    const val PAUSE_RUN = "/runnin/pause_run"
    const val RESUME_RUN = "/runnin/resume_run"
    const val COMPLETE_RUN = "/runnin/complete_run"
    const val ACKNOWLEDGE_COMPLETE = "/runnin/acknowledge_complete"

    // Watch -> Phone (telemetria via DataClient, throttled)
    const val BPM_UPDATE = "/runnin/bpm_update"
    const val SPO2_UPDATE = "/runnin/spo2_update"
    const val STEPS_UPDATE = "/runnin/steps_update"
    const val WATCH_DIAG = "/runnin/watch_diag"
}

/**
 * Keys do payload de RUN_STATE (DataItem). Match exato com as keys que o
 * Watch iOS lê em `WatchRunState.update(from:)`:
 *  - status, elapsedS, distanceM, paceMinKm, bpm, caloriesKcal, elevationM
 *  - runType, accentColor, secondaryColor, textScale, splits, _attachedTodaySession
 *
 * O DataMap (do DataClient) aceita primitive types + asset + map + array de
 * primitives — mas NÃO Map<String,Any>. Pra splits e _attachedTodaySession
 * serializamos como JSON string e parseamos no Watch (decisão de simplicidade).
 */
object PayloadKeys {
    const val TYPE = "type"
    const val STATUS = "status"
    const val ELAPSED_S = "elapsedS"
    const val DISTANCE_M = "distanceM"
    const val PACE_MIN_KM = "paceMinKm"
    const val BPM = "bpm"
    const val CALORIES_KCAL = "caloriesKcal"
    const val ELEVATION_M = "elevationM"
    const val RUN_TYPE = "runType"
    const val ACCENT_COLOR = "accentColor"
    const val SECONDARY_COLOR = "secondaryColor"
    const val TEXT_SCALE = "textScale"
    const val SPLITS_JSON = "splitsJson"
    const val TODAY_SESSION_JSON = "todaySessionJson"
    const val REST_DAY = "rest_day"
    const val REQUEST_ID = "request_id"
    const val PLAN_SESSION_ID = "planSessionId"
    const val IS_PREMIUM = "isPremium"
    const val DISTANCE_KM = "distanceKm"
    const val IS_EXECUTED = "isExecuted"
    const val VALUE = "value"
    const val TS = "ts"
    const val KIND = "kind"
    const val STEPS = "steps"
    const val SPO2 = "spo2"
}
