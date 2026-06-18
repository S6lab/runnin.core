package com.s6lab.runnin.wear.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.wear.compose.material.Text
import com.s6lab.runnin.wear.components.RunninLogo
import com.s6lab.runnin.wear.models.LocalStep
import com.s6lab.runnin.wear.models.SelectedRunType
import com.s6lab.runnin.wear.models.WatchRunState
import com.s6lab.runnin.wear.theme.scaledFont

/**
 * Jornada 1, Passo 1/5 — TIPO de corrida. Espelha o Step 0 do prep_page do
 * phone (TypeStep).
 *
 * Paralelo do `PreRunScreen` do Apple Watch (Screens/PreRunScreen.swift).
 */
@Composable
fun PreRunScreen() {
    val state = WatchRunState.shared
    val scroll = rememberScrollState()
    val accent = state.accentColor

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(scroll)
            .padding(horizontal = 4.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        // Logo centralizada — em display redondo top-LEFT é cortado.
        androidx.compose.foundation.layout.Box(
            modifier = Modifier.fillMaxWidth().padding(top = 4.dp),
            contentAlignment = androidx.compose.ui.Alignment.Center,
        ) {
            RunninLogo()
        }

        Text(
            text = "ESCOLHA O TIPO",
            color = Color.White.copy(alpha = 0.5f),
            style = scaledFont(9f, FontWeight.Medium),
            modifier = Modifier.padding(top = 4.dp),
        )

        val today = state.todaySession
        if (today != null) {
            if (today.isExecuted) {
                CompletedSessionCard(typeLabel = today.type, distanceKm = today.distanceKm)
            } else {
                RunButton(
                    title = "SESSÃO DO DIA",
                    subtitle = "${today.type} · ${formattedKm(today.distanceKm)}",
                    accent = true,
                    accentColor = accent,
                    onClick = {
                        state.localStep = LocalStep.Briefing(
                            SelectedRunType(today.type, today.planSessionId, today.distanceKm)
                        )
                    },
                )
            }
        }

        RunButton(
            title = "CORRIDA LIVRE",
            subtitle = "Sem plano · sem alvo",
            // Quando a sessão do dia já foi feita, Free Run vira a opção
            // principal (accent) — espelha o default do phone.
            accent = today?.isExecuted == true,
            accentColor = accent,
            onClick = {
                state.localStep = LocalStep.Briefing(
                    SelectedRunType("Free Run", null, null)
                )
            },
        )
    }
}

@Composable
private fun RunButton(
    title: String,
    subtitle: String,
    accent: Boolean,
    accentColor: Color,
    onClick: () -> Unit,
) {
    val bg = if (accent) accentColor else Color.White.copy(alpha = 0.08f)
    val borderColor = if (accent) Color.Transparent else accentColor.copy(alpha = 0.3f)
    val titleColor = if (accent) Color.Black else Color.White
    val subtitleColor = if (accent) Color.Black.copy(alpha = 0.7f) else Color.White.copy(alpha = 0.5f)
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(6.dp))
            .background(bg)
            .border(1.dp, borderColor, RoundedCornerShape(6.dp))
            .clickable(onClick = onClick)
            .padding(horizontal = 10.dp, vertical = 8.dp),
    ) {
        Text(title, color = titleColor, style = scaledFont(12f, FontWeight.Black))
        Spacer(Modifier.size(4.dp))
        Text(subtitle, color = subtitleColor, style = scaledFont(9f, FontWeight.Medium))
    }
}

@Composable
private fun CompletedSessionCard(typeLabel: String, distanceKm: Double) {
    val green = Color(0xFF36D399)
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(6.dp))
            .background(green.copy(alpha = 0.08f))
            .border(1.dp, green.copy(alpha = 0.45f), RoundedCornerShape(6.dp))
            .padding(horizontal = 10.dp, vertical = 8.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text("✓", color = green, style = scaledFont(11f, FontWeight.Black))
            Spacer(Modifier.width(6.dp))
            Text("SESSÃO CONCLUÍDA", color = green, style = scaledFont(10f, FontWeight.Black))
        }
        Text(
            "$typeLabel · ${formattedKm(distanceKm)}",
            color = Color.White.copy(alpha = 0.55f),
            style = scaledFont(9f, FontWeight.Medium),
        )
    }
}

private fun formattedKm(km: Double): String =
    if (km == km.toInt().toDouble()) "${km.toInt()}km"
    else "%.1fkm".format(km)
