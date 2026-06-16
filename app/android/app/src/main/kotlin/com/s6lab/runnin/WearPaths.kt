package com.s6lab.runnin

/**
 * Paths Wearable Data Layer compartilhados entre phone e watch.
 * Cópia idêntica de `wear/src/main/kotlin/com/s6lab/runnin/wear/bridge/Protocol.kt`
 * — mantemos duplicado pra não ter de incluir o módulo :wear como dependência
 * do :app (criaria ciclo se :wear quisesse ler algo do :app no futuro).
 */
object WearPaths {
    const val START_WORKOUT = "/runnin/start_workout"
    const val STOP_WORKOUT = "/runnin/stop_workout"
    const val PING = "/runnin/ping"

    const val RUN_STATE = "/runnin/run_state"
    const val TODAY_SESSION = "/runnin/today_session"

    const val START_RUN = "/runnin/start_run"
    const val PAUSE_RUN = "/runnin/pause_run"
    const val RESUME_RUN = "/runnin/resume_run"
    const val COMPLETE_RUN = "/runnin/complete_run"
    const val ACKNOWLEDGE_COMPLETE = "/runnin/acknowledge_complete"

    const val BPM_UPDATE = "/runnin/bpm_update"
    const val SPO2_UPDATE = "/runnin/spo2_update"
    const val STEPS_UPDATE = "/runnin/steps_update"
    const val WATCH_DIAG = "/runnin/watch_diag"
}
