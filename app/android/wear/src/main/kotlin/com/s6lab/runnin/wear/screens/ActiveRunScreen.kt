package com.s6lab.runnin.wear.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.wear.compose.material.Icon
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Pause
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.wear.compose.material.Text
import com.s6lab.runnin.wear.bridge.WearableMessenger
import com.s6lab.runnin.wear.components.RunninLogo
import com.s6lab.runnin.wear.components.SlideToConfirmButton
import com.s6lab.runnin.wear.models.WatchRunState
import com.s6lab.runnin.wear.models.WatchSplit
import com.s6lab.runnin.wear.models.WatchStatus
import com.s6lab.runnin.wear.theme.scaledFont
import com.s6lab.runnin.wear.workout.WorkoutController

/**
 * Corrida ativa no Watch. Espelha o RunState do phone via WearableMessenger
 * (1Hz). 3 páginas: stats | controles (slide pause/parar) | splits.
 *
 * Paralelo do `ActiveRunScreen` do Apple Watch (Screens/ActiveRunScreen.swift).
 */
@Composable
fun ActiveRunScreen() {
    val state = WatchRunState.shared
    val workout = WorkoutController.shared
    val pagerState = rememberPagerState(initialPage = 0, pageCount = { 3 })

    Box(Modifier.fillMaxSize()) {
        HorizontalPager(state = pagerState, modifier = Modifier.fillMaxSize()) { page ->
            when (page) {
                0 -> StatsPage()
                1 -> ControlsPage()
                2 -> SplitsPage()
            }
        }

        // Page indicator: 3 bolinhas no rodapé, ativa marca a página atual.
        // Paralelo do .tabViewStyle(.page(.always)) do iOS L34.
        Row(
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .padding(bottom = 4.dp),
            horizontalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            repeat(3) { i ->
                val active = pagerState.currentPage == i
                Box(
                    modifier = Modifier
                        .size(if (active) 6.dp else 4.dp)
                        .clip(CircleShape)
                        .background(
                            if (active) state.accentColor else Color.White.copy(alpha = 0.4f)
                        ),
                )
            }
        }

        // Overlay orfão — quando phone offline >25s
        if (state.isOrphaned) {
            OrphanOverlay(onStop = {
                state.resetToIdle { workout.stop() }
            })
        }
    }
}

@Composable
private fun StatsPage() {
    val state = WatchRunState.shared
    val workout = WorkoutController.shared
    val isPaused = state.status == WatchStatus.paused

    val displayedBpm = if (workout.lastHeartRate > 0) workout.lastHeartRate else state.bpm

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 6.dp, vertical = 4.dp),
        verticalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        Header()
        if (isPaused) PausedBanner()
        Column(
            modifier = Modifier.fillMaxWidth(),
            verticalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            BigStat(
                label = "TEMPO",
                value = state.formattedElapsed,
                size = 30f,
                valueColor = if (isPaused) Color.Yellow else Color.White,
            )
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                MediumStat(label = "DIST", value = state.formattedDistance, unit = "km",
                    valueColor = state.secondaryColor, modifier = Modifier.weight(1f))
                MediumStat(label = "PACE", value = state.formattedPace, unit = "/km",
                    valueColor = state.accentColor, modifier = Modifier.weight(1f))
            }
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                MediumStat(label = "BPM",
                    value = if (displayedBpm > 0) "$displayedBpm" else "—",
                    unit = null,
                    valueColor = state.secondaryColor,
                    modifier = Modifier.weight(1f))
                MediumStat(label = "CAL",
                    value = "${state.caloriesKcal.toInt()}",
                    unit = null,
                    valueColor = Color.White,
                    modifier = Modifier.weight(1f))
            }
            if (workout.lastSpo2 > 0) {
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    SmallStat(label = "SpO₂", value = "${workout.lastSpo2}%")
                    SmallStat(label = "ELEV", value = "+${state.elevationM.toInt()}m")
                }
            } else {
                SmallStat(label = "ELEV", value = "+${state.elevationM.toInt()}m")
            }
        }
        Spacer(Modifier.weight(1f))
    }
}

@Composable
private fun ControlsPage() {
    val state = WatchRunState.shared
    val workout = WorkoutController.shared
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 6.dp, vertical = 4.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Header()
        if (state.status == WatchStatus.paused) PausedBanner()
        Spacer(Modifier.weight(1f))
        Text(
            text = "CONTROLES",
            color = Color.White.copy(alpha = 0.5f),
            style = scaledFont(8f, FontWeight.Medium),
            modifier = Modifier.fillMaxWidth().padding(horizontal = 4.dp),
        )
        SlideToConfirmButton(
            label = if (state.status == WatchStatus.paused) "RETOMAR" else "PAUSAR",
            color = Color.Yellow,
            onAction = {
                if (state.status == WatchStatus.paused) {
                    WearableMessenger.sendCommand("resumeRun")
                } else {
                    WearableMessenger.sendCommand("pauseRun")
                }
            },
        )
        SlideToConfirmButton(
            label = "PARAR",
            color = Color.Red,
            onAction = {
                // PARAR no Watch = COMPLETE (salva + relatório), não ABANDON.
                WearableMessenger.sendCommand("completeRun")
            },
        )
        Spacer(Modifier.weight(1f))
    }
}

@Composable
private fun SplitsPage() {
    val state = WatchRunState.shared
    val scroll = rememberScrollState()
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 6.dp, vertical = 4.dp),
        verticalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        Header()
        Text(
            text = "SPLITS",
            color = Color.White.copy(alpha = 0.5f),
            style = scaledFont(8f, FontWeight.Medium),
        )
        if (state.splits.isEmpty()) {
            Spacer(Modifier.weight(1f))
            Column(
                modifier = Modifier.fillMaxWidth(),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                Text("—", color = Color.White.copy(alpha = 0.3f),
                    style = scaledFont(22f, FontWeight.Bold))
                Text("Termine o 1º km", color = Color.White.copy(alpha = 0.5f),
                    style = scaledFont(9f, FontWeight.Medium))
            }
            Spacer(Modifier.weight(1f))
        } else {
            Column(
                modifier = Modifier.verticalScroll(scroll),
                verticalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                state.splits.forEach { SplitRow(it) }
            }
        }
    }
}

@Composable
private fun SplitRow(split: WatchSplit) {
    val state = WatchRunState.shared
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(4.dp))
            .background(Color.White.copy(alpha = 0.06f))
            .padding(horizontal = 6.dp, vertical = 5.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Text("KM${split.km}", color = state.accentColor,
            style = scaledFont(11f, FontWeight.Black),
            modifier = Modifier.width(32.dp))
        Column(Modifier.weight(1f)) {
            Text(split.pace, color = Color.White, style = scaledFont(12f, FontWeight.Bold))
            Text(split.formattedDuration, color = Color.White.copy(alpha = 0.5f),
                style = scaledFont(8f, FontWeight.Medium))
        }
        if (split.bpm > 0) {
            Column(horizontalAlignment = Alignment.End) {
                Text("${split.bpm}", color = state.secondaryColor,
                    style = scaledFont(11f, FontWeight.Bold))
                Text("BPM", color = Color.White.copy(alpha = 0.45f),
                    style = scaledFont(7f, FontWeight.Medium))
            }
        }
    }
}

@Composable
private fun Header() {
    // Logo centralizada — display redondo corta top-left.
    // runType movido pra cá vai cortar no canto top-right; omitido (info já
    // foi apresentada no Briefing antes de iniciar).
    Box(
        modifier = Modifier.fillMaxWidth(),
        contentAlignment = Alignment.Center,
    ) {
        RunninLogo()
    }
}

@Composable
private fun PausedBanner() {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(4.dp))
            .background(Color.Yellow)
            .padding(horizontal = 8.dp, vertical = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(5.dp),
    ) {
        Icon(Icons.Default.Pause, contentDescription = null, tint = Color.Black,
            modifier = Modifier.size(10.dp))
        Text("PAUSADO", color = Color.Black, style = scaledFont(10f, FontWeight.Black))
    }
}

@Composable
private fun OrphanOverlay(onStop: () -> Unit) {
    Box(
        Modifier
            .fillMaxSize()
            .background(Color.Black.copy(alpha = 0.85f)),
        contentAlignment = Alignment.Center,
    ) {
        Column(
            modifier = Modifier.padding(horizontal = 12.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Text(
                text = "APP DO PHONE OFFLINE",
                color = Color(0xFFFF9500),
                style = scaledFont(11f, FontWeight.Black),
            )
            Text(
                text = "Sem dados há 25s. Encerrar e voltar?",
                color = Color.White.copy(alpha = 0.7f),
                style = scaledFont(10f, FontWeight.Medium),
            )
            Box(
                Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(6.dp))
                    .background(Color(0xFFFF9500))
                    .clickable(onClick = onStop)
                    .padding(vertical = 8.dp),
                contentAlignment = Alignment.Center,
            ) {
                Text("ENCERRAR", color = Color.Black,
                    style = scaledFont(12f, FontWeight.Black))
            }
        }
    }
}

@Composable
private fun BigStat(label: String, value: String, size: Float, valueColor: Color) {
    Column(verticalArrangement = Arrangement.spacedBy(0.dp)) {
        Text(label, color = Color.White.copy(alpha = 0.5f),
            style = scaledFont(8f, FontWeight.Medium))
        Text(value, color = valueColor, style = scaledFont(size, FontWeight.Bold), maxLines = 1)
    }
}

@Composable
private fun MediumStat(
    label: String, value: String, unit: String?, valueColor: Color,
    modifier: Modifier = Modifier,
) {
    Column(modifier = modifier) {
        Text(label, color = Color.White.copy(alpha = 0.5f),
            style = scaledFont(7f, FontWeight.Medium))
        Row(verticalAlignment = Alignment.Bottom, horizontalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(value, color = valueColor, style = scaledFont(18f, FontWeight.Bold), maxLines = 1)
            unit?.let {
                Text(it, color = Color.White.copy(alpha = 0.5f),
                    style = scaledFont(8f, FontWeight.Medium))
            }
        }
    }
}

@Composable
private fun SmallStat(label: String, value: String) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
        Text(label, color = Color.White.copy(alpha = 0.45f),
            style = scaledFont(7f, FontWeight.Medium))
        Text(value, color = Color.White.copy(alpha = 0.85f),
            style = scaledFont(11f, FontWeight.Bold), maxLines = 1)
    }
}
