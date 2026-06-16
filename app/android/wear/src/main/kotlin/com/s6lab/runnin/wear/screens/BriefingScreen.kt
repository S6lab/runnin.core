package com.s6lab.runnin.wear.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.wear.compose.material.CircularProgressIndicator
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.wear.compose.material.Text
import com.s6lab.runnin.wear.bridge.PayloadKeys
import com.s6lab.runnin.wear.bridge.WearableMessenger
import com.s6lab.runnin.wear.components.RunninLogo
import com.s6lab.runnin.wear.models.LocalStep
import com.s6lab.runnin.wear.models.SelectedRunType
import com.s6lab.runnin.wear.models.WatchRunState
import com.s6lab.runnin.wear.models.WatchStatus
import com.s6lab.runnin.wear.theme.scaledFont
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.distinctUntilChanged

/**
 * Jornada 1, Passo 5/5 — BRIEFING + INICIAR. Espelha o Step 4 do prep_page
 * do phone. O sendMessage("startRun") só dispara AQUI.
 *
 * Paralelo do `BriefingScreen` do Apple Watch (Screens/BriefingScreen.swift).
 */
@Composable
fun BriefingScreen(selected: SelectedRunType) {
    val state = WatchRunState.shared
    val scroll = rememberScrollState()
    val accent = state.accentColor

    var startFailed by remember { mutableStateOf(false) }

    // Timeout 10s — se status=active não chegar do phone, libera botão pra
    // tentar de novo.
    LaunchedEffect(state.starting) {
        if (!state.starting) return@LaunchedEffect
        delay(10_000L)
        if (state.status == WatchStatus.idle && state.starting) {
            state.starting = false
            startFailed = true
        }
    }
    // Reseta startFailed quando status sai de idle.
    LaunchedEffect(Unit) {
        snapshotFlow { state.status }
            .distinctUntilChanged()
            .collect { newStatus ->
                if (newStatus != WatchStatus.idle) {
                    startFailed = false
                }
            }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(scroll)
            .padding(horizontal = 4.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Row(Modifier.fillMaxWidth().padding(top = 4.dp)) {
            RunninLogo()
            Spacer(Modifier.weight(1f))
        }

        Text(
            text = selected.type.uppercase(),
            color = Color.White,
            style = scaledFont(14f, FontWeight.Black),
        )

        val km = selected.distanceKm
        if (km != null) {
            Text(
                text = "ALVO · ${formattedKm(km)}",
                color = accent,
                style = scaledFont(9f, FontWeight.Medium),
            )
        } else {
            Text(
                text = "SEM ALVO DE DISTÂNCIA",
                color = Color.White.copy(alpha = 0.5f),
                style = scaledFont(9f, FontWeight.Medium),
            )
        }

        Text(
            text = briefingText(selected),
            color = Color.White.copy(alpha = 0.75f),
            style = scaledFont(11f, FontWeight.Medium),
            modifier = Modifier.padding(top = 4.dp),
        )

        if (startFailed) {
            Text(
                text = "Phone sem resposta. Seu pedido ficou salvo: abra o Runnin que a corrida inicia sozinha.",
                color = Color.Yellow,
                style = scaledFont(9f, FontWeight.Medium),
                modifier = Modifier.padding(top = 2.dp),
            )
        }

        Spacer(Modifier.size(6.dp))

        val buttonLabel = when {
            state.starting -> "INICIANDO…"
            startFailed -> "TENTAR NOVAMENTE"
            else -> "INICIAR"
        }

        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(6.dp))
                .background(accent)
                .clickable(enabled = !state.starting) {
                    handleStart(selected)
                }
                .padding(vertical = 10.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(6.dp, Alignment.CenterHorizontally),
        ) {
            if (state.starting) {
                CircularProgressIndicator(
                    indicatorColor = Color.Black,
                    strokeWidth = 2.dp,
                    modifier = Modifier.size(12.dp),
                )
            }
            Text(buttonLabel, color = Color.Black, style = scaledFont(13f, FontWeight.Black))
        }

        Text(
            text = "VOLTAR",
            color = Color.White.copy(alpha = 0.55f),
            style = scaledFont(10f, FontWeight.Medium),
            modifier = Modifier
                .fillMaxWidth()
                .clickable(enabled = !state.starting) {
                    state.localStep = LocalStep.SelectingType
                }
                .padding(vertical = 6.dp),
        )
    }
}

private fun handleStart(selected: SelectedRunType) {
    val state = WatchRunState.shared
    if (state.starting) return
    state.starting = true
    val extras = mutableMapOf<String, Any?>(
        "type" to selected.type,
        PayloadKeys.IS_PREMIUM to true,
    )
    selected.planSessionId?.let { extras[PayloadKeys.PLAN_SESSION_ID] = it }
    WearableMessenger.sendCommand("startRun", extras)
}

private fun briefingText(selected: SelectedRunType): String =
    if (selected.isFree) {
        "Corrida livre. Sem alarmes de pace — só telemetria de km e tempo."
    } else {
        "Bloco de ${selected.type}. Foco no pace alvo. Coach vai te acompanhar."
    }

private fun formattedKm(km: Double): String =
    if (km == km.toInt().toDouble()) "${km.toInt()}km"
    else "%.1fkm".format(km)
