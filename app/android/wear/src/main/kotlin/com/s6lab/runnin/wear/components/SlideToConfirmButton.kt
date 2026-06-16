package com.s6lab.runnin.wear.components

import android.content.Context
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.wear.compose.material.Icon
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.dp
import androidx.wear.compose.material.Text
import com.s6lab.runnin.wear.theme.scaledFont
import kotlin.math.max

/**
 * Botão "deslizar pra confirmar" pra ações destrutivas (PAUSAR / PARAR).
 *
 * Paralelo do `SlideToConfirmButton` do Apple Watch (Components/SlideToConfirmButton.swift).
 */
@Composable
fun SlideToConfirmButton(
    label: String,
    color: Color,
    onAction: () -> Unit,
) {
    val ctx = LocalContext.current
    val density = LocalDensity.current
    val trackHeightDp = 36.dp
    val thumbWidthDp = 32.dp
    val thumbWidthPx = with(density) { thumbWidthDp.toPx() }

    var trackSize by remember { mutableStateOf(IntSize.Zero) }
    var dragX by remember { mutableStateOf(0f) }
    var crossedThreshold by remember { mutableStateOf(false) }

    val maxX = max(0f, trackSize.width.toFloat() - thumbWidthPx)
    val progress = if (maxX > 0f) (dragX / maxX).coerceIn(0f, 1f) else 0f
    val triggered = progress >= 0.6f

    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(trackHeightDp)
            .onSizeChanged { trackSize = it }
            .clip(RoundedCornerShape(8.dp))
            .background(Color.White.copy(alpha = 0.08f)),
    ) {
        // Fill indicator que cresce com o drag — desenhado com Canvas pra
        // largura dinâmica direta, sem precisar de hack de Modifier.
        Canvas(modifier = Modifier.fillMaxWidth().height(trackHeightDp)) {
            val fillWidth = max(thumbWidthPx, dragX + thumbWidthPx)
            drawRoundRect(
                color = color.copy(alpha = 0.45f),
                topLeft = Offset.Zero,
                size = Size(fillWidth, size.height),
                cornerRadius = CornerRadius(8.dp.toPx(), 8.dp.toPx()),
            )
        }

        // Label centrado
        Box(Modifier.fillMaxWidth().height(trackHeightDp), contentAlignment = Alignment.Center) {
            Text(
                text = if (triggered) "SOLTE" else label,
                color = Color.White,
                style = scaledFont(11f, FontWeight.SemiBold),
            )
        }

        // Thumb com drag handler
        Box(
            modifier = Modifier
                .offset { IntOffset(dragX.toInt(), 0) }
                .size(thumbWidthDp, trackHeightDp)
                .pointerInput(Unit) {
                    detectDragGestures(
                        onDragStart = {
                            // No-op; estado inicial controlado por dragX
                        },
                        onDrag = { change, drag ->
                            change.consume()
                            dragX = (dragX + drag.x).coerceIn(0f, maxX)
                            val newCrossed = (if (maxX > 0f) dragX / maxX else 0f) >= 0.6f
                            if (newCrossed && !crossedThreshold) {
                                crossedThreshold = true
                                playHaptic(ctx, light = true)
                            } else if (!newCrossed && crossedThreshold) {
                                crossedThreshold = false
                            }
                        },
                        onDragEnd = {
                            if (triggered) {
                                playHaptic(ctx, light = false)
                                onAction()
                            }
                            dragX = 0f
                            crossedThreshold = false
                        },
                        onDragCancel = {
                            dragX = 0f
                            crossedThreshold = false
                        },
                    )
                },
            contentAlignment = Alignment.Center,
        ) {
            Box(
                modifier = Modifier
                    .clip(RoundedCornerShape(6.dp))
                    .background(color)
                    .size(thumbWidthDp - 4.dp, trackHeightDp - 8.dp),
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    imageVector = Icons.Default.ChevronRight,
                    contentDescription = null,
                    tint = Color.Black,
                )
            }
        }
    }
}

private fun playHaptic(ctx: Context, light: Boolean) {
    try {
        val vibrator: Vibrator? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            (ctx.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager)?.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            ctx.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
        }
        val effect = VibrationEffect.createOneShot(
            if (light) 30L else 80L,
            VibrationEffect.DEFAULT_AMPLITUDE,
        )
        vibrator?.vibrate(effect)
    } catch (_: Throwable) { /* best-effort */ }
}
