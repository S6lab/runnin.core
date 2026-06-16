package com.s6lab.runnin.wear.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.snapshots.SnapshotStateObserver
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.dp
import androidx.wear.compose.material.Text
import com.s6lab.runnin.wear.models.WatchRunState
import com.s6lab.runnin.wear.theme.scaledFont

/**
 * Logo header reusada em todas as telas do Watch.
 * "RUNNIN" branco bold + ".AI" preto sobre quadrado accentColor.
 *
 * Paralelo do `RunninLogo` do Apple Watch (Components/RunninLogo.swift).
 */
@Composable
fun RunninLogo() {
    val state = WatchRunState.shared
    val accent: Color = state.accentColor
    Row {
        Text(
            text = "RUNNIN",
            color = Color.White,
            style = scaledFont(11f, FontWeight.Black),
        )
        Text(
            text = ".AI",
            color = Color.Black,
            style = scaledFont(9f, FontWeight.Bold),
            modifier = Modifier
                .clip(RoundedCornerShape(2.dp))
                .background(accent)
                .padding(horizontal = 3.dp, vertical = 1.dp),
        )
    }
}
