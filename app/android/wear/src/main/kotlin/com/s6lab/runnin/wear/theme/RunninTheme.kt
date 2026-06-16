package com.s6lab.runnin.wear.theme

import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp
import androidx.wear.compose.material.Colors
import androidx.wear.compose.material.MaterialTheme
import com.s6lab.runnin.wear.models.WatchRunState

/**
 * Helper: devolve TextStyle monospace escalado por `textScale` da
 * `WatchRunState`. Paralelo do `scaledFont(size:weight:)` do Apple Watch
 * (WatchRunState.swift L305).
 */
fun scaledFont(size: Float, weight: FontWeight = FontWeight.Normal): TextStyle {
    val scale = WatchRunState.shared.textScale.toFloat().coerceIn(0.8f, 1.5f)
    return TextStyle(
        fontSize = (size * scale).sp,
        fontWeight = weight,
        fontFamily = FontFamily.Monospace,
    )
}

@Composable
fun RunninWearTheme(content: @Composable () -> Unit) {
    // Tema dark fixo — paridade com o Watch iOS (sempre fundo preto). Cada
    // Text na UI passa explicit color, então MaterialTheme aqui só carrega
    // defaults de tipografia/forma. Wear Material2 usa Colors (M2 API).
    MaterialTheme(
        colors = Colors(
            primary = Color.White,
            onPrimary = Color.Black,
            secondary = Color.White,
            onSecondary = Color.Black,
            background = Color.Black,
            onBackground = Color.White,
            surface = Color.Black,
            onSurface = Color.White,
            error = Color.Red,
            onError = Color.White,
        ),
        content = content,
    )
}
