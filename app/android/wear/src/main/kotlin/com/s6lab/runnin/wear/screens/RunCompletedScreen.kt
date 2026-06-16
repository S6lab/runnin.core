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
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.wear.compose.material.Text
import com.s6lab.runnin.wear.bridge.WearableMessenger
import com.s6lab.runnin.wear.components.RunninLogo
import com.s6lab.runnin.wear.models.LocalStep
import com.s6lab.runnin.wear.models.WatchRunState
import com.s6lab.runnin.wear.models.WatchSplit
import com.s6lab.runnin.wear.models.WatchStatus
import com.s6lab.runnin.wear.theme.scaledFont

/**
 * Mostrada após corrida concluída (status: completed). Espelha a ReportPage
 * do phone, adaptada pro Watch.
 *
 * Paralelo do `RunCompletedScreen` do Apple Watch (Screens/RunCompletedScreen.swift).
 */
@Composable
fun RunCompletedScreen() {
    val state = WatchRunState.shared
    val accent = state.accentColor
    val scroll = rememberScrollState()

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(scroll)
            .padding(horizontal = 6.dp, vertical = 6.dp),
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Row(Modifier.fillMaxWidth().padding(top = 2.dp)) {
            RunninLogo()
            Spacer(Modifier.weight(1f))
        }
        Text(
            text = "CORRIDA CONCLUÍDA",
            color = accent,
            style = scaledFont(9f, FontWeight.Black),
            modifier = Modifier.padding(top = 2.dp),
        )

        StatBlock(label = "DIST", value = state.formattedDistance, unit = "km",
            size = 26f, color = state.secondaryColor)
        StatBlock(label = "TEMPO", value = state.formattedElapsed, unit = null,
            size = 22f, color = Color.White)
        StatBlock(label = "PACE MED", value = state.formattedPace, unit = "/km",
            size = 22f, color = accent)

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            MiniStat(label = "BPM",
                value = if (state.bpm > 0) "${state.bpm}" else "—",
                color = state.secondaryColor,
                modifier = Modifier.weight(1f))
            MiniStat(label = "CAL", value = "${state.caloriesKcal.toInt()}",
                color = Color.White, modifier = Modifier.weight(1f))
            MiniStat(label = "ELEV", value = "+${state.elevationM.toInt()}m",
                color = Color.White.copy(alpha = 0.8f), modifier = Modifier.weight(1f))
        }

        if (state.splits.isNotEmpty()) {
            Text(
                text = "SPLITS",
                color = Color.White.copy(alpha = 0.5f),
                style = scaledFont(8f, FontWeight.Medium),
                modifier = Modifier.padding(top = 4.dp),
            )
            state.splits.forEach { CompletedSplitRow(it) }
        }

        // Botão OK
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(6.dp))
                .background(accent)
                .clickable {
                    WearableMessenger.sendCommand("acknowledgeComplete")
                    // Otimista: força localStep idle imediatamente.
                    state.localStep = LocalStep.SelectingType
                }
                .padding(vertical = 9.dp),
            contentAlignment = Alignment.Center,
        ) {
            Text("OK", color = Color.Black, style = scaledFont(13f, FontWeight.Black))
        }
    }
}

@Composable
private fun StatBlock(label: String, value: String, unit: String?, size: Float, color: Color) {
    Column {
        Text(label, color = Color.White.copy(alpha = 0.5f),
            style = scaledFont(7f, FontWeight.Medium))
        Row(verticalAlignment = Alignment.Bottom, horizontalArrangement = Arrangement.spacedBy(3.dp)) {
            Text(value, color = color, style = scaledFont(size, FontWeight.Bold), maxLines = 1)
            unit?.let {
                Text(it, color = Color.White.copy(alpha = 0.5f),
                    style = scaledFont(9f, FontWeight.Medium))
            }
        }
    }
}

@Composable
private fun MiniStat(label: String, value: String, color: Color, modifier: Modifier = Modifier) {
    Column(modifier = modifier) {
        Text(label, color = Color.White.copy(alpha = 0.45f),
            style = scaledFont(6f, FontWeight.Medium))
        Text(value, color = color, style = scaledFont(12f, FontWeight.Bold), maxLines = 1)
    }
}

@Composable
private fun CompletedSplitRow(split: WatchSplit) {
    val state = WatchRunState.shared
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(3.dp))
            .background(Color.White.copy(alpha = 0.05f))
            .padding(horizontal = 5.dp, vertical = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(5.dp),
    ) {
        Text("KM${split.km}", color = state.accentColor,
            style = scaledFont(10f, FontWeight.Black),
            modifier = Modifier.width(28.dp))
        Column(Modifier.weight(1f)) {
            Text(split.pace, color = Color.White, style = scaledFont(11f, FontWeight.Bold))
            Text(split.formattedDuration, color = Color.White.copy(alpha = 0.5f),
                style = scaledFont(7f, FontWeight.Medium))
        }
        if (split.bpm > 0) {
            Text("${split.bpm}", color = state.secondaryColor,
                style = scaledFont(10f, FontWeight.Bold))
        }
    }
}
