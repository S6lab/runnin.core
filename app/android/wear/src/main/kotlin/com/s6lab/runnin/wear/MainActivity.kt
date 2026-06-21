package com.s6lab.runnin.wear

import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager
import android.os.Bundle
import android.view.WindowManager
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import com.s6lab.runnin.wear.bridge.WearableMessenger
import com.s6lab.runnin.wear.models.LocalStep
import com.s6lab.runnin.wear.models.WatchRunState
import com.s6lab.runnin.wear.models.WatchStatus
import com.s6lab.runnin.wear.screens.ActiveRunScreen
import com.s6lab.runnin.wear.screens.BriefingScreen
import com.s6lab.runnin.wear.screens.PreRunScreen
import com.s6lab.runnin.wear.screens.RunCompletedScreen
import com.s6lab.runnin.wear.theme.RunninWearTheme
import com.s6lab.runnin.wear.workout.WorkoutController
import kotlinx.coroutines.flow.distinctUntilChanged

/**
 * Entry point do app Wear OS standalone. Paralelo do `RunninWatchApp` do
 * Apple Watch (RunninWatchApp.swift).
 *
 * Responsabilidade mínima: ligar Wearable Data Layer listeners, pedir
 * permissão BODY_SENSORS, e renderizar a `WearApp` que reflete a
 * `WatchRunState` + `WorkoutController`.
 */
class MainActivity : ComponentActivity() {

    private val permissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions()
    ) { _ ->
        // No-op: independente do resultado, segue. Coleta degrada gracefully
        // se BODY_SENSORS não autorizado (paralelo do iOS quando HK negado).
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Anexa singletons ao contexto da app — idempotente.
        WatchRunState.shared.attach(applicationContext)
        WearableMessenger.attach(applicationContext)
        WorkoutController.shared.attach(applicationContext)

        // Inicia watchdog que detecta phone offline (paralelo do
        // `startOrphanMonitor` chamado no init do RunninWatchApp iOS).
        WatchRunState.shared.startOrphanMonitor()

        // Pede permissões críticas pra BPM funcionar.
        requestSensorPermissions()

        setContent {
            RunninWearTheme {
                WearApp()
            }
        }
    }

    private fun requestSensorPermissions() {
        val needed = mutableListOf<String>()
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.BODY_SENSORS) !=
            PackageManager.PERMISSION_GRANTED) {
            needed.add(Manifest.permission.BODY_SENSORS)
        }
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.ACTIVITY_RECOGNITION) !=
            PackageManager.PERMISSION_GRANTED) {
            needed.add(Manifest.permission.ACTIVITY_RECOGNITION)
        }
        if (needed.isNotEmpty()) {
            permissionLauncher.launch(needed.toTypedArray())
        }
    }
}

/**
 * Roteador raiz do Watch app. Decide qual tela mostrar baseado em:
 *   - state.status (idle | active | paused | completed), vindo do phone
 *   - state.localStep (SelectingType | Briefing), navegação local durante idle
 *
 * Paralelo do `ContentView` do Apple Watch (ContentView.swift).
 */
@Composable
private fun WearApp() {
    val state = WatchRunState.shared
    val workout = WorkoutController.shared
    val status by snapshotFlow { state.status }.collectAsStateWithLifecycleSafe(initial = state.status)
    val step by snapshotFlow { state.localStep }.collectAsStateWithLifecycleSafe(initial = state.localStep)

    // Belt-and-suspenders TF 69 equivalente (ContentView.swift L34):
    // quando phone empurra status=active via DataClient, garante que
    // ExerciseSession está rodando.
    LaunchedEffect(Unit) {
        snapshotFlow { state.status }
            .distinctUntilChanged()
            .collect { newStatus ->
                if (newStatus == WatchStatus.active && !workout.isActive) {
                    workout.start()
                } else if (newStatus == WatchStatus.idle && workout.isActive) {
                    workout.stop()
                }
            }
    }

    // KEEP_SCREEN_ON enquanto a run está ativa/pausada. WorkoutForegroundService
    // mantém o PROCESSO vivo, mas Wear OS desliga a tela em ~5s sem interação
    // e ao tocar volta pro watch face em vez da Activity — usuário relata que
    // "app fica minimizando" durante a corrida. Flag aplicada via DisposableEffect
    // pra ligar só durante active/paused e desligar no completed/idle (preserva
    // bateria no resto do tempo). Paridade com `WKExtendedRuntimeSession` do
    // watchOS, que já mantém o display ligado durante a session.
    val view = LocalView.current
    val keepScreenOn = status == WatchStatus.active || status == WatchStatus.paused
    DisposableEffect(keepScreenOn) {
        val window = (view.context as? Activity)?.window
        if (keepScreenOn) {
            window?.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        } else {
            window?.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        }
        onDispose {
            window?.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        }
    }

    // Safe area pro display redondo do Galaxy Watch / Pixel Watch.
    // 14dp não foi suficiente em device real (logo cortou). 20dp dá cobertura
    // mínima sem matar área útil. CONTEÚDO TOP/BOTTOM precisa estar
    // HORIZONTALMENTE CENTRALIZADO além disso (cada screen já ajustada),
    // senão a quina top-left/top-right corta apesar do padding.
    val isRound = LocalConfiguration.current.isScreenRound
    val safePadding = if (isRound) 20.dp else 4.dp
    androidx.compose.foundation.layout.Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black)
            .padding(safePadding),
    ) {
        when (status) {
            WatchStatus.idle -> when (val s = step) {
                is LocalStep.SelectingType -> PreRunScreen()
                is LocalStep.Briefing -> BriefingScreen(s.selected)
            }
            WatchStatus.active, WatchStatus.paused -> ActiveRunScreen()
            WatchStatus.completed -> RunCompletedScreen()
        }
    }
}

/**
 * Helper local pra não depender do artifact `lifecycle-runtime-compose`
 * separadamente em todos os pontos. Coleta `snapshotFlow` cancelando no
 * dispose do Composable.
 */
@Composable
private fun <T> kotlinx.coroutines.flow.Flow<T>.collectAsStateWithLifecycleSafe(
    initial: T,
): androidx.compose.runtime.State<T> {
    val state = androidx.compose.runtime.remember { androidx.compose.runtime.mutableStateOf(initial) }
    LaunchedEffect(this) {
        collect { state.value = it }
    }
    return state
}
